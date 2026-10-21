import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/theme.dart' show statusLabels;
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../data/file_repository.dart';
import '../../providers/contract_provider.dart';
import '../../providers/file_provider.dart';

class ContractDetailModal extends StatefulWidget {
  final dynamic contract;
  final Future<void> Function(int, String) onAction;
  final VoidCallback onRefresh;
  final VoidCallback? onGoToPayments;
  final int? workspaceId;
  // Optional so this screen can be pumped in a widget test with a mocked
  // ApiClient instead of hitting the network. Defaults to the real
  // singleton — zero behavior change for its one existing call site
  // (onboarding/client_onboarding_screen.dart, itself still unseamed/deferred).
  final ApiClient? api;
  final ContractProvider? contractProvider;
  final FileProvider? fileProvider;

  const ContractDetailModal({
    super.key,
    required this.contract,
    required this.onAction,
    required this.onRefresh,
    this.onGoToPayments,
    this.workspaceId,
    this.api,
    this.contractProvider,
    this.fileProvider,
  });

  @override
  State<ContractDetailModal> createState() => _ContractDetailModalState();
}

class _ContractDetailModalState extends State<ContractDetailModal> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider(api: _api);
  late final FileProvider _fileProvider = widget.fileProvider ?? FileProvider(repository: FileRepository(api: _api));
  bool _uploading = false;
  List<dynamic> _uploadedFiles = [];
  bool _loadingFiles = false;
  Map<String, dynamic>? _fullContract;

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
    _loadFullContract();
  }

  Future<void> _loadFullContract({bool force = false}) async {
    final existingClauses = widget.contract['clauses'] as List<dynamic>?;
    final existingReqDocs = widget.contract['required_documents'] as List<dynamic>?;
    if (!force && ((existingClauses?.isNotEmpty == true) || (existingReqDocs?.isNotEmpty == true))) return;

    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    try {
      final list = await _contractProvider.fetchWorkspaceContractsRaw(wsId);
      final contractId = widget.contract['id'];
      for (final cc in list) {
        if (cc is Map && cc['id'] == contractId) {
          _fullContract = Map<String, dynamic>.from(cc);
          break;
        }
      }
      if (mounted) setState(() {});
    } catch (e, s) {
      AppLog.error('contract_detail_modal._loadFullContract', e, s);
    }
  }

  Future<void> _loadUploadedFiles() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    setState(() => _loadingFiles = true);
    try {
      final data = await _fileProvider.fetchWorkspaceFiles(wsId);
      final allFiles = safeList(data['files']);
      final contractId = widget.contract['id'];
      _uploadedFiles = allFiles.where((f) => f['contract_id'] == contractId).toList();
    } catch (e, s) {
      AppLog.error('contract_detail_modal._loadFiles', e, s);
    }
    if (mounted) setState(() => _loadingFiles = false);
  }

  Future<void> _uploadDocument(int contractId, int? definitionId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.single;
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;

    setState(() => _uploading = true);
    try {
      final fields = <String, dynamic>{'contract_id': contractId};
      if (definitionId != null) fields['contract_required_document_id'] = definitionId;
      if (kIsWeb) {
        await _fileProvider.uploadFile(wsId, fields, bytes: pf.bytes, filename: pf.name);
      } else {
        await _fileProvider.uploadFile(wsId, fields, file: File(pf.path!));
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const LxIcon('check', size: 18, color: Lx.ok), const SizedBox(width: 8), Flexible(child: Text(AppLocalizations.of(context)!.documentUploaded))])));
      widget.onRefresh();
      await Future.wait([
        _loadUploadedFiles(),
        _loadFullContract(force: true),
      ]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.documentUploadFailed(e.toString()))));
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = _fullContract ?? widget.contract;
    final status = c['status'] as String? ?? '';
    final clauses = c['clauses'] as List<dynamic>? ?? [];
    final requiredDocs = c['required_documents'] as List<dynamic>? ?? [];
    final needsAction = status == 'sent';
    final isCompanyApproved = status == 'company_approved';
    final currency = c['currency'] as String? ?? 'SAR';
    final amt = num.tryParse('${c['value'] ?? ''}');

    final hasMissingDocs = requiredDocs.isNotEmpty && requiredDocs.any((d) {
      if (d is! Map) return false;
      final dId = d['id'];
      final rawFiles = d['files'] as List<dynamic>?;
      final files = (rawFiles != null && rawFiles.isNotEmpty)
          ? rawFiles
          : _uploadedFiles.where((f) => f['contract_required_document_id'] == dId || f['document_definition_id'] == dId).toList();
      if (files.isNotEmpty) {
        return !files.any((f) => f is Map && f['status'] != 'rejected');
      }
      return d['status'] != 'approved' && d['status'] != 'pending';
    });

    final steps = [l10n.contractStepSent, l10n.contractStepClientApproved, l10n.contractStepCompanyApproved, l10n.contractStepActive];
    final statusMsg = switch (status) {
      'client_approved' => l10n.clientApprovedStatus,
      'edit_requested' => l10n.editRequestedStatus,
      'rejected' => l10n.rejectedStatus,
      'completed' => l10n.completedStatus,
      _ => '',
    };

    // Same layout as the staff contract sheet (contracts_tab
    // _showContractDetail): kind, serif title, amount, dates, labelled
    // steps, numbered clauses, then the client's own parts (documents to
    // upload, uploaded files, approve / edit), PDF last. Shown inside
    // showLuxeSheet, which draws the grab handle and scrolls.
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      LuxeKind(c['contract_type'] == 'additional' ? l10n.contractKindAdditional : l10n.contractKindMain),
      const SizedBox(height: 4),
      Text('${c['title'] ?? ''}', key: const ValueKey('contract-modal-title'), style: Lx.display(context, size: 22)),
      if (c['value'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: amt != null ? lxFormatMoney(amt) : '${c['value']}', style: Lx.display(context, size: 20)),
              TextSpan(text: ' $currency', style: Lx.text(context, size: 11, color: Lx.muted)),
            ])),
          ),
        ),
      if (c['start_date'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            c['end_date'] != null
                ? l10n.contractDateRange(_day(c['start_date']), _day(c['end_date']))
                : l10n.contractDateFrom(_day(c['start_date'])),
            style: Lx.text(context, size: 12.5, color: Lx.muted),
          ),
        ),
      if (c['paid'] != null || c['remaining'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (c['paid'] != null) '${l10n.paid}: ${c['paid']} $currency',
              if (c['remaining'] != null) '${l10n.remaining}: ${c['remaining']} $currency',
            ].join(' · '),
            style: Lx.text(context, size: 12.5, color: Lx.muted),
          ),
        ),
      LuxeLabeledSteps(labels: steps, current: _stepFor(status)),

      if (clauses.isNotEmpty) ...[
        const SizedBox(height: 22),
        LuxeKind(l10n.contractClausesLabel),
        const SizedBox(height: 4),
        for (var i = 0; i < clauses.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(border: i == clauses.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 20, child: Text('${i + 1}', style: Lx.text(context, size: 11, color: Lx.faint, height: 1.8))),
              const SizedBox(width: 10),
              Expanded(child: Text('${clauses[i]['content'] ?? ''}', style: Lx.text(context, size: 13, height: 1.6))),
            ]),
          ),
      ],

      // Required documents (only while the contract waits on the client)
      if (requiredDocs.isNotEmpty && needsAction) ...[
        const SizedBox(height: 18),
        LuxeKind(l10n.contractRequiredDocsLabel),
        const SizedBox(height: 4),
        for (var i = 0; i < requiredDocs.length; i++)
          Builder(builder: (context) {
            final doc = requiredDocs[i];
            final docStatus = doc['status'] as String? ?? 'pending';
            final dot = docStatus == 'approved' ? LxStatus.ok : docStatus == 'rejected' ? LxStatus.bad : LxStatus.wait;
            return Container(
              key: ValueKey('contract-modal-doc-$i'),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: i == requiredDocs.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
              child: Row(children: [
                const LxIcon('doc', size: 18, color: Lx.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${doc['name'] ?? ''}', style: Lx.text(context, size: 13.5)),
                    const SizedBox(height: 3),
                    Row(children: [
                      LuxeStatusDot(status: dot),
                      const SizedBox(width: 7),
                      Text(statusLabels(l10n)[docStatus] ?? docStatus, style: Lx.text(context, size: 12, color: Lx.ink2)),
                    ]),
                    if (doc['rejection_reason'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(l10n.rejectionReason(doc['rejection_reason'] as String), style: Lx.text(context, size: 11, color: Lx.danger)),
                      ),
                  ]),
                ),
                // subuser-review-plan.md م٦ — required-document uploads
                // map to can_upload_files, per the plan's action table.
                if (docStatus != 'approved' && _api.canDo('can_upload_files'))
                  LuxeButton(
                    key: ValueKey('contract-modal-upload-$i'),
                    label: _uploading ? l10n.uploading : l10n.uploadDocument,
                    lxIcon: 'up',
                    size: LuxeButtonSize.sm,
                    onPressed: _uploading ? null : () => _uploadDocument(c['id'], doc['id']),
                  ),
              ]),
            );
          }),
      ],

      // Files the client already uploaded against this contract
      if (_loadingFiles)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Lx.crimsonInk))),
        )
      else if (_uploadedFiles.isNotEmpty) ...[
        const SizedBox(height: 18),
        LuxeKind(l10n.uploadedFiles),
        const SizedBox(height: 4),
        for (final f in _uploadedFiles)
          Builder(builder: (context) {
            final fStatus = f['status'] as String? ?? '';
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Lx.line2)),
              child: Row(children: [
                const LxIcon('clip', size: 16, color: Lx.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _downloadFile(f['file_url'] as String? ?? ''),
                    child: Text('${f['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                LuxeStatusDot(status: fStatus == 'approved' ? LxStatus.ok : fStatus == 'rejected' ? LxStatus.bad : LxStatus.wait),
                const SizedBox(width: 6),
                Text(statusLabels(l10n)[fStatus] ?? fStatus, style: Lx.text(context, size: 11, color: Lx.muted)),
                if (fStatus != 'approved') ...[
                  const SizedBox(width: 6),
                  InkResponse(
                    key: ValueKey('contract-modal-file-delete-${f['id']}'),
                    onTap: () => _deleteFile(f),
                    radius: 16,
                    child: const Padding(padding: EdgeInsets.all(4), child: LxIcon('trash', size: 15, color: Lx.danger)),
                  ),
                ],
              ]),
            );
          }),
      ],

      // Approve / request edit
      // subuser-review-plan.md م٦ — a sub-user without
      // can_approve_contracts must not see the approve/edit-request
      // buttons at all, only find out about them via a 403.
      if (needsAction && _api.canDo('can_approve_contracts')) ...[
        const SizedBox(height: 22),
        if (hasMissingDocs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const LxIcon('lock', size: 14, color: Lx.faint),
              const SizedBox(width: 8),
              Flexible(child: Text(l10n.contractUploadRequiredFirst, textAlign: TextAlign.center, style: Lx.text(context, size: 11.5, color: Lx.faint))),
            ]),
          ),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: hasMissingDocs
                  ? null
                  : () async {
                      await widget.onAction(c['id'], 'approved');
                      if (context.mounted) Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Lx.crimson,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF2A2827),
                disabledForegroundColor: Lx.faint,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text(l10n.approve),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                await widget.onAction(c['id'], 'edit_requested');
                if (context.mounted) Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Lx.ink2,
                side: const BorderSide(color: Lx.line2),
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: Text(l10n.edit),
            ),
          ),
        ]),
      ] else if (needsAction) ...[
        const SizedBox(height: 18),
        Row(children: [
          const LxIcon('lock', size: 14, color: Lx.faint),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.subuserActionNeedsOwner, style: Lx.text(context, size: 12, color: Lx.faint))),
        ]),
      ],

      if (isCompanyApproved) ...[
        const SizedBox(height: 18),
        LuxeCard(
          key: const ValueKey('contract-modal-company-approved'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const LuxeStatusDot(status: LxStatus.ok),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.contractApprovedByCompany, style: Lx.text(context, size: 14, weight: FontWeight.w500))),
            ]),
            const SizedBox(height: 6),
            Text(l10n.goToPaymentHint, style: Lx.text(context, size: 12.5, color: Lx.muted, height: 1.5)),
            if (widget.onGoToPayments != null) ...[
              const SizedBox(height: 12),
              LuxeButton(
                label: l10n.goToPayment,
                lxIcon: 'wallet',
                kind: LuxeButtonKind.primary,
                onPressed: () {
                  Navigator.pop(context);
                  widget.onGoToPayments?.call();
                },
              ),
            ],
          ]),
        ),
      ],

      if (statusMsg.isNotEmpty) ...[
        const SizedBox(height: 18),
        Center(child: Text(statusMsg, textAlign: TextAlign.center, style: Lx.text(context, size: 13, color: Lx.muted))),
      ],

      if (c['pdf_url'] != null) ...[
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: LuxeButton(
            key: const ValueKey('contract-modal-pdf'),
            label: l10n.downloadContractPdf,
            lxIcon: 'down',
            size: LuxeButtonSize.lg,
            onPressed: () => _downloadPdf(c['pdf_url'] as String),
          ),
        ),
      ],
    ]);
  }

  static int _stepFor(String status) {
    switch (status) {
      case 'sent':
        return 1;
      case 'client_approved':
      case 'edit_requested':
        return 2;
      case 'company_approved':
        return 3;
      case 'completed':
      case 'archived':
        return 4;
      default:
        return 0;
    }
  }

  String _day(dynamic date) {
    final t = DateTime.tryParse(date?.toString() ?? '')?.toLocal();
    if (t == null) return '${date ?? ''}'.split('T').first;
    return DateFormat('d MMM y', Localizations.localeOf(context).toString()).format(t);
  }

  // Both methods below deliberately keep the try/catch free of any
  // BuildContext use and check `context.mounted` once, straight-line, right
  // after it — the analyzer's use_build_context_synchronously check doesn't
  // reliably associate a `mounted` guard placed *inside* a catch block with
  // the async gap in the try above it, and flags it as an "unrelated" guard
  // even though it is one. Doing the mounted check after the try/catch has
  // fully exited sidesteps that, with no behavior change.
  Future<void> _downloadFile(String fileUrl) async {
    final l10n = AppLocalizations.of(context)!;
    if (fileUrl.isEmpty) return;
    final url = _api.resolveFileUrl(fileUrl);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidFileUrl)));
      }
      return;
    }
    var launchFailed = false;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launchFailed = true;
    }
    if (launchFailed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fileOpenFailed)));
    }
  }

  Future<void> _downloadPdf(String pdfUrl) async {
    final l10n = AppLocalizations.of(context)!;
    final url = _api.resolveFileUrl(pdfUrl);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidFileUrl)));
      }
      return;
    }
    var launchFailed = false;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launchFailed = true;
    }
    if (launchFailed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fileOpenFailed)));
    }
  }

  Future<void> _deleteFile(dynamic file) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteFileTitle),
        content: Text(l10n.deleteFileConfirmation(file['name'] as String? ?? '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Lx.crimson, foregroundColor: Colors.white),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;

    try {
      await _fileProvider.deleteFile(wsId, file['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fileDeleted)));
      await _loadUploadedFiles();
      widget.onRefresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fileDeleteFailed(e.toString()))));
    }
  }
}
