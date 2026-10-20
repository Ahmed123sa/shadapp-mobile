// Extracted from contracts_page.dart (بند ٨: تقسيم الملفات فوق ٨٠٠ سطر) —
// this is the bottom sheet contracts_page.dart's _showDetailModal opens when
// a contract card is tapped. Byte-identical to the class that used to live
// inline in that file as a private `_ContractDetailModal`; only the class
// name changed (private -> public `ContractDetailSheet`) since Dart privacy
// is per-file and contracts_page.dart needs to construct it from outside.
//
// Not to be confused with contract_detail_modal.dart's `ContractDetailModal`
// — that is a separate, independently-built widget used only by
// onboarding/client_onboarding_screen.dart. The two look similar (both are
// contract detail sheets) but were never the same code, same as
// chat_page.dart/chat_tab.dart's near-duplicate bubbles documented in
// docs/state-layer-migration-plan.md, بند ٥ — this split does not merge them.
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/luxe/tokens.dart';
import '../../core/theme.dart';
import '../../data/file_repository.dart';
import '../../providers/file_provider.dart';

class ContractDetailSheet extends StatefulWidget {
  final dynamic contract;
  final String? clientType;
  final bool wsActive;
  final Future<void> Function(int, String) onAction;
  final VoidCallback onRefresh;   final VoidCallback? onGoToPayments;
  final ApiClient? api;
  final FileProvider? fileProvider;

  const ContractDetailSheet({
    super.key,
    required this.contract,
    this.clientType,
    this.wsActive = false,
    required this.onAction,
    required this.onRefresh,     required this.onGoToPayments,
    this.api,
    this.fileProvider,
  });

  @override
  State<ContractDetailSheet> createState() => _ContractDetailSheetState();
}

class _ContractDetailSheetState extends State<ContractDetailSheet> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final FileProvider _fileProvider = widget.fileProvider ?? FileProvider(repository: FileRepository(api: _api));
  bool _uploading = false;
  List<dynamic> _uploadedFiles = [];
  bool _loadingFiles = false;

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
  }

  Future<void> _loadUploadedFiles() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    setState(() => _loadingFiles = true);
    try {
      final data = await _fileProvider.fetchWorkspaceFiles(wsId);
      final allFiles = safeList(data['files']);
      final contractId = widget.contract['id'];
      _uploadedFiles = allFiles.where((f) => f['contract_id'] == contractId).toList();
    } catch (e, s) {
      AppLog.error('contracts_page._loadFiles', e, s);
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
    final wsId = _api.workspaceId;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.documentUploaded)])));
      widget.onRefresh();
      await _loadUploadedFiles();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.documentUploadFailed(e.toString()))));
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = widget.contract;
    final status = c['status'] as String? ?? '';
    final clauses = c['clauses'] as List<dynamic>? ?? [];
    final requiredDocs = c['required_documents'] as List<dynamic>? ?? [];
    final needsAction = status == 'sent';
    final isCompanyApproved = status == 'company_approved' && !widget.wsActive;

    final progress = c['progress'] is num ? (c['progress'] as num).toDouble() : 0.0;
    final stageIndex = _computeStageIndex(c);

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

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 16),
        child: ListView(
          controller: scrollController,
          children: [
            // Back row
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Row(children: [
                const Icon(Icons.arrow_forward_ios, size: 12, color: Lx.muted),
                const SizedBox(width: 6),
                Text(l10n.allContracts, style: const TextStyle(fontSize: 12, color: Lx.muted)),
              ]),
            ),
            const SizedBox(height: 14),

            // detail-card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Lx.sheet,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Lx.line2),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['title'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Lx.ink2, fontFamily: Lx.serif)),
                if (c['contract_type'] == 'additional')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Lx.ink2.withAlpha(50), Lx.ink2.withAlpha(25)]),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Lx.ink2.withAlpha(80)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add_circle_outline, size: 12, color: Lx.ink2),
                        const SizedBox(width: 4),
                        Text(l10n.additionalServiceContract, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Lx.ink2)),
                      ]),
                    ),
                  ),
                if (c['contract_type'] != 'additional')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Lx.surface.withAlpha(60),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Lx.ink2.withAlpha(80)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.description_outlined, size: 12, color: Lx.ink2),
                        const SizedBox(width: 4),
                        Text(l10n.mainContract, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Lx.ink2)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 4),
                Text('#${c['id'] ?? ''}', style: const TextStyle(fontSize: 11, color: Lx.muted)),
                const SizedBox(height: 12),
                Text('${c['value'] ?? 0} ${c['currency'] as String? ?? 'SAR'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Lx.ink, fontFamily: Lx.serif)),
                if (widget.clientType == 'business')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(l10n.contractValueExcludesVat, style: const TextStyle(fontSize: 11, color: Lx.muted)),
                  ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Lx.line2,
                    valueColor: const AlwaysStoppedAnimation(Lx.ok),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: List.generate(4, (i) {
                  final done = i < stageIndex;
                  final current = i == stageIndex;
                  return Expanded(
                    child: Container(
                      height: 5, margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: done ? Lx.ok : current ? Lx.crimsonInk : Lx.line2,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                })),
              ]),
            ),
            const SizedBox(height: 16),

            // Info rows
            Text(l10n.contractInfo, style: const TextStyle(fontSize: 12, color: Lx.muted)),
            const SizedBox(height: 8),
            if (c['start_date'] != null)
              _infoRow(l10n.startDate, (c['start_date'] as String).split('T')[0]),
            if (c['end_date'] != null)
              _infoRow(l10n.endDate, (c['end_date'] as String).split('T')[0]),
            if (c['value'] != null)
              _infoRow(l10n.contractValue, '${c['value']} ${c['currency'] as String? ?? 'SAR'}', gold: true),
            if (c['paid'] != null)
              _infoRow(l10n.paid, '${c['paid']} ${c['currency'] as String? ?? 'SAR'}', gold: true),
            if (c['remaining'] != null)
              _infoRow(l10n.remaining, '${c['remaining']} ${c['currency'] as String? ?? 'SAR'}'),
            const SizedBox(height: 16),

            // Clauses (only in modal)
            if (clauses.isNotEmpty) ...[
              Text(l10n.contractClauses, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Lx.ink)),
              const SizedBox(height: 8),
              ...clauses.map((cl) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Lx.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Lx.line2),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.circle, size: 6, color: Lx.faint),
                  const SizedBox(width: 8),
                  Expanded(child: Text(cl['content'] ?? '', style: const TextStyle(fontSize: 13, color: Lx.ink))),
                ]),
              )),
              const SizedBox(height: 16),
            ],

            // Required documents (only show when action is needed)
            if (requiredDocs.isNotEmpty && needsAction) ...[
              Text(l10n.requiredDocuments, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Lx.ink)),
              const SizedBox(height: 8),
              ...requiredDocs.map((doc) {
                final docStatus = doc['status'] as String? ?? 'pending';
                final docStatusColor = docStatus == 'approved'
                    ? Lx.ok
                    : docStatus == 'rejected'
                        ? Lx.danger
                        : Lx.wait;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Lx.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Lx.line2),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(doc['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Lx.ink))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: docStatusColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabels(AppLocalizations.of(context)!)[docStatus] ?? docStatus,
                          style: TextStyle(fontSize: 10, color: docStatusColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                    if (doc['rejection_reason'] != null) ...[
                      const SizedBox(height: 4),
                      Text(l10n.rejectionReason(doc['rejection_reason'] as String), style: const TextStyle(fontSize: 11, color: Lx.danger)),
                    ],
                    // subuser-review-plan.md م٦ — required-document uploads
                    // map to can_upload_files, per the plan's action table.
                    if (docStatus != 'approved' && _api.canDo('can_upload_files')) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _uploading ? null : () => _uploadDocument(c['id'], doc['id']),
                          icon: _uploading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file, size: 16),
                          label: Text(_uploading ? l10n.uploading : l10n.uploadDocument),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Lx.ink2,
                            side: const BorderSide(color: Lx.ink2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                    ],
                  ]),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Uploaded files
            if (_loadingFiles) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
            ] else if (_uploadedFiles.isNotEmpty) ...[
              Text(l10n.uploadedFiles, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Lx.ink)),
              const SizedBox(height: 8),
              ..._uploadedFiles.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Lx.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Lx.line2),
                ),
                child: Row(children: [
                  const Icon(Icons.attach_file, size: 16, color: Lx.ink2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _downloadFile(f['file_url'] as String? ?? ''),
                      child: Text(f['name'] ?? '', style: const TextStyle(fontSize: 12, color: Lx.ink2, decoration: TextDecoration.underline))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (f['status'] as String?) == 'approved'
                          ? Lx.ok.withAlpha(25)
                          : Lx.wait.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusLabels(AppLocalizations.of(context)!)[f['status'] as String? ?? ''] ?? f['status'] ?? '',
                      style: TextStyle(fontSize: 9, color: (f['status'] as String?) == 'approved' ? Lx.ok : Lx.wait),
                    ),
                  ),
                ]),
              )),
              const SizedBox(height: 16),
            ],

            // Action buttons
            // subuser-review-plan.md م٦ — a sub-user without
            // can_approve_contracts must not see the approve/edit-request
            // buttons at all, only find out about them via a 403.
            if (needsAction && _api.canDo('can_approve_contracts')) ...[
              Text(l10n.actions, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Lx.ink)),
              if (hasMissingDocs) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.contractUploadRequiredFirst,
                  style: const TextStyle(fontSize: 11, color: Lx.wait, fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasMissingDocs ? null : () async {
                      await widget.onAction(c['id'], 'approved');
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(l10n.approve),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Lx.crimson,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                      disabledBackgroundColor: Lx.line2,
                      disabledForegroundColor: Lx.faint,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.onAction(c['id'], 'edit_requested');
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(l10n.edit),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Lx.wait,
                      side: const BorderSide(color: Lx.wait),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ]),
            ] else if (needsAction) ...[
              Text(l10n.subuserActionNeedsOwner, style: const TextStyle(fontSize: 12, color: Lx.faint)),
            ],

            // Download PDF (shown whenever available)
            if (c['pdf_url'] != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _downloadPdf(c['pdf_url'] as String),
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(l10n.downloadContractPdf),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Lx.ink2,
                    side: const BorderSide(color: Lx.ink2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],

            if (isCompanyApproved) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Lx.ok.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Lx.ok.withAlpha(40)),
                ),
                child: Column(children: [
                  const Icon(Icons.check_circle, size: 40, color: Lx.ok),
                  const SizedBox(height: 8),
                  Text(l10n.contractApprovedByCompany, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Lx.ok)),
                  const SizedBox(height: 4),
                  Text(l10n.goToPaymentHint, style: const TextStyle(fontSize: 12, color: Lx.ok)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onGoToPayments?.call();
                    },
                    icon: const Icon(Icons.payment, size: 18),
                    label: Text(l10n.goToPayment),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Lx.crimson,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ]),
              ),
            ],

            // Status messages
            if (!needsAction && !isCompanyApproved && status != 'draft') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Lx.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Lx.line2),
                ),
                child: Column(children: [
                  Center(
                    child: Text(
                      status == 'client_approved' ? l10n.clientApprovedStatus :
                      status == 'edit_requested' ? l10n.editRequestedStatus :
                      status == 'rejected' ? l10n.rejectedStatus :
                      status == 'completed' ? l10n.completedStatus : '',
                      style: const TextStyle(fontSize: 13, color: Lx.muted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (status == 'edit_requested' && c['edit_reason'] != null && (c['edit_reason'] as String).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Lx.ink2.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Lx.ink2.withAlpha(40)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l10n.editReasonTitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Lx.ink2)),
                        const SizedBox(height: 4),
                        Text(c['edit_reason'] as String, style: const TextStyle(fontSize: 12, color: Lx.ink)),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static int _computeStageIndex(dynamic c) {
    final stageMap = <String, int>{
      'onboarding': 0, 'draft': 0, 'sent': 0,
      'client_approved': 1, 'edit_requested': 1,
      'company_approved': 2,
      'completed': 3,
      'archived': 3,
    };
    return stageMap[c['status'] as String? ?? ''] ?? 0;
  }

  Widget _infoRow(String label, String value, {bool gold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Lx.line2, width: 0.5)),
      ),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Lx.muted)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 12, color: gold ? Lx.ink2 : Lx.ink, fontWeight: gold ? FontWeight.w600 : FontWeight.w400)),
      ]),
    );
  }

  // See the matching comment in contract_detail_modal.dart's _downloadFile:
  // the mounted check has to happen after the try/catch has fully exited,
  // not inside the catch block, or the analyzer treats it as unrelated to
  // the async gap even though it correctly guards it.
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
}
