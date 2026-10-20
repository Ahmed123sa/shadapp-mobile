import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/helpers/signature_required_dialog.dart';
import '../../core/helpers/required_documents_dialog.dart';
import '../../core/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/error_state.dart';
import '../../data/file_repository.dart';
import '../../providers/contract_provider.dart';
import '../../providers/file_provider.dart';
import 'contract_detail_sheet.dart';

class ContractsPage extends StatefulWidget {
  final VoidCallback? onGoToPayments;
  final ValueNotifier<int>? refreshNotifier;
  // Optional so this screen can be pumped in a widget test (e.g. embedded
  // inside client_dashboard_screen.dart's IndexedStack, which mounts every
  // tab eagerly) with a mocked ApiClient instead of hitting the network.
  // Defaults to the real singleton — zero behavior change for every existing
  // call site.
  final ApiClient? api;
  final ContractProvider? contractProvider;
  // Threaded through to ContractDetailSheet (contract_detail_sheet.dart),
  // which has its own file-upload domain.
  final FileProvider? fileProvider;
  const ContractsPage({super.key, this.onGoToPayments, this.refreshNotifier, this.api, this.contractProvider, this.fileProvider});


  @override
  State<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends State<ContractsPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider(api: _api);
  late final FileProvider _fileProvider = widget.fileProvider ?? FileProvider(repository: FileRepository(api: _api));
  List<dynamic> _contracts = [];
  String? _clientType;
  String? _workspaceStatus;
  bool _loading = true;
  String? _error;
  VoidCallback? _refreshListener;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.refreshNotifier != null) {
      _refreshListener = () { if (mounted) _load(); };
      widget.refreshNotifier!.addListener(_refreshListener!);
    }
  }

  Future<void> _load() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      // Two requests dispatched together (not sequentially) — matches the
      // original Future.wait's concurrency. Awaited separately rather than
      // via Future.wait itself because the provider methods now return
      // differently-typed futures (List vs Map), unlike the raw HTTP calls
      // this replaced, which both returned the same envelope shape.
      final contractsFuture = _contractProvider.fetchWorkspaceContractsRaw(wsId);
      final workspaceFuture = _contractProvider.fetchWorkspaceRaw(wsId).catchError((_) => <String, dynamic>{});
      _contracts = await contractsFuture;
      final wsData = await workspaceFuture;
      _clientType = wsData['client']?['client_type'] as String?;
      _workspaceStatus = (wsData['workspace']?['status'] ?? wsData['status']) as String?;
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _clientAction(int contractId, String action) async {
    final l10n = AppLocalizations.of(context)!;

    String? reason;

    if (action == 'approved') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.approveContractTitle),
          content: Text(l10n.approveContractConfirm),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
          ],
        ),
      );
      if (confirm != true) return;
    } else if (action == 'edit_requested') {
      reason = await _showReasonDialog();
      if (reason == null) return;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.contractActionDialog(action)),
          content: Text(l10n.areYouSure),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.contractActionDone(action))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      await _contractProvider.clientAction(contractId, action, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(l10n.contractActionDone(action))])));
        _load();
        widget.refreshNotifier?.value++;
      }
    } catch (e) {
      if (!mounted) return;
      if (await maybeShowSignatureRequiredDialog(context, e, isSubUser: _api.subUserId != null)) return;
      if (!mounted) return;
      if (await maybeShowRequiredDocumentsDialog(context, e)) return;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    }
  }

  Future<String?> _showReasonDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.contract_editReason),
        content: TextField(controller: controller, maxLines: 3, decoration: InputDecoration(hintText: l10n.editReasonHint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(l10n.confirm)),
        ],
      ),
    );
    return result;
  }

  @override
  void dispose() {
    if (_refreshListener != null && widget.refreshNotifier != null) {
      widget.refreshNotifier!.removeListener(_refreshListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) { return const LoadingState(); }
    if (_error != null) { return ErrorState(message: _error!, onRetry: _load); }
    if (_contracts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LuxePageTitle(l10n.contracts),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 5), child: LuxePulseDot(key: ValueKey('contracts-waiting-pulse'))),
            const SizedBox(width: 14),
            Expanded(child: Text(l10n.awaitingContracts, style: Lx.text(context, size: 13.5, color: Lx.muted))),
          ]),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        children: [
          LuxePageTitle(l10n.contracts),
          ..._contracts.map((c) => _contractCard(c)),
        ],
      ),
    );
  }

  /// Which contract-lifecycle step is "now" (steps before it are done).
  /// sent / edit requested → waiting on the client; completed/archived → all done.
  static int _lifecycleStep(String status) {
    switch (status) {
      case 'client_approved': return 2;
      case 'company_approved': return 3;
      case 'completed':
      case 'archived': return 4;
      default: return 1;
    }
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.tryParse(_api.resolveFileUrl(url));
    if (uri == null) return;
    var failed = false;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      failed = true;
    }
    if (failed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.fileOpenFailed)));
    }
  }

  Widget _contractCard(dynamic c) {
    final l10n = AppLocalizations.of(context)!;
    final status = c['status'] as String? ?? '';
    final needsAction = status == 'sent';
    final isApproved = status == 'company_approved' && _workspaceStatus != 'active';
    final isExtra = c['contract_type'] == 'additional';
    final date = c['start_date'] != null ? (c['start_date'] as String).split('T')[0] : null;
    final sub = [if (date != null) date, statusLabels(l10n)[status] ?? status].join(' · ');
    final currency = c['currency'] as String? ?? 'SAR';
    final value = double.tryParse('${c['value'] ?? 0}');
    final pdf = c['pdf_url'] as String?;
    final steps = [l10n.contractStepSent, l10n.contractStepYouApproved, l10n.contractStepCompanyApproved, l10n.contractStepActive];

    final requiredDocs = c['required_documents'] as List<dynamic>? ?? [];
    final hasMissingDocs = needsAction &&
        requiredDocs.isNotEmpty &&
        requiredDocs.any((d) {
          if (d is! Map) return false;
          final files = d['files'] as List<dynamic>?;
          if (files != null && files.isNotEmpty) {
            return !files.any((f) => f is Map && f['status'] != 'rejected');
          }
          return d['status'] != 'approved' && d['status'] != 'pending';
        });
    // subuser-review-plan.md م٦ — a sub-user without can_approve_contracts
    // must not see the approve/edit-request buttons at all, only find out
    // about them via a 403.
    final canApprove = _api.canDo('can_approve_contracts');

    return LuxeCard(
      key: ValueKey('contract-card-${c['id']}'),
      attention: needsAction,
      onTap: () => _showDetailModal(c),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LuxeKind(isExtra ? l10n.additionalContract : l10n.mainContract),
        const SizedBox(height: 4),
        Text(c['title'] ?? '', style: Lx.text(context, size: 16)),
        const SizedBox(height: 2),
        Text(sub, style: Lx.text(context, size: 12.5, color: Lx.muted)),
        const SizedBox(height: 10),
        LuxeAmount(value != null ? _fmtMoney(value) : '${c['value'] ?? 0}', currency),
        if (_clientType == 'business')
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(l10n.contractValueExcludesVat, style: Lx.text(context, size: 10, color: Lx.muted)),
          ),
        if (status == 'edit_requested' && c['edit_reason'] != null && (c['edit_reason'] as String).isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Lx.wait.withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: Text(l10n.editReasonLabel(c['edit_reason'] as String), style: Lx.text(context, size: 10.5, color: Lx.wait), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
        LuxeLabeledSteps(labels: steps, current: _lifecycleStep(status)),
        if (needsAction) ...[
          if (hasMissingDocs) ...[
            const SizedBox(height: 10),
            LuxeHint(l10n.contractUploadRequiredFirst),
          ],
          if (canApprove) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: () => _clientAction(c['id'], 'edit_requested'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Lx.ink2,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: Lx.line2),
                      textStyle: Lx.text(context, size: 12),
                    ),
                    child: Text(l10n.onboarding_requestEdit),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: hasMissingDocs ? null : () => _clientAction(c['id'], 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Lx.crimson,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF2A2827),
                      disabledForegroundColor: Lx.faint,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      shape: const StadiumBorder(),
                      textStyle: Lx.text(context, size: 12),
                    ),
                    child: Text(l10n.approve),
                  ),
                ),
              ),
            ]),
          ] else ...[
            const SizedBox(height: 14),
            Row(children: [
              LuxeButton(
                key: ValueKey('contract-preview-${c['id']}'),
                label: l10n.onboardingPreviewShort,
                lxIcon: 'eye',
                size: LuxeButtonSize.sm,
                onPressed: () => _showDetailModal(c),
              ),
            ]),
            const SizedBox(height: 12),
            LuxeHint(l10n.subuserActionNeedsOwner),
          ],
        ] else ...[
          const SizedBox(height: 14),
          Row(children: [
            LuxeButton(
              key: ValueKey('contract-preview-${c['id']}'),
              label: l10n.onboardingPreviewShort,
              lxIcon: 'eye',
              size: LuxeButtonSize.sm,
              onPressed: () => _showDetailModal(c),
            ),
            if (pdf != null) ...[
              const SizedBox(width: 8),
              LuxeButton(
                key: ValueKey('contract-pdf-${c['id']}'),
                label: l10n.contractDownloadPdfShort,
                lxIcon: 'down',
                size: LuxeButtonSize.sm,
                onPressed: () => _openPdf(pdf),
              ),
            ],
          ]),
        ],
        if (isApproved) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Lx.ok.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Lx.ok.withAlpha(70)),
            ),
            child: Column(children: [
              Row(children: [
                const LxIcon('check', size: 16, color: Lx.ok),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.contractApprovedByCompany, style: Lx.text(context, size: 11.5, color: Lx.ok))),
              ]),
              if (widget.onGoToPayments != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => widget.onGoToPayments?.call(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Lx.crimson,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      textStyle: Lx.text(context, size: 12),
                    ),
                    child: Text(l10n.goToPayment),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  static String _fmtMoney(double v) {
    final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
    final parts = s.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return parts.length > 1 ? '$whole.${parts[1]}' : whole;
  }

  void _showDetailModal(dynamic c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Lx.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet)),
        side: BorderSide(color: Lx.line2),
      ),
      builder: (_) => ContractDetailSheet(
        contract: c,
        clientType: _clientType,
        wsActive: _workspaceStatus == 'active',
        onAction: _clientAction,
        onRefresh: _load,
        onGoToPayments: widget.onGoToPayments,
        api: _api,
        fileProvider: _fileProvider,
      ),
    );
  }
}
