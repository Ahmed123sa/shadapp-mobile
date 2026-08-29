import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_badge.dart';
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
      _clientType = (await workspaceFuture)['client']?['client_type'] as String?;
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
    } catch (_) {
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
    if (_loading) { return const LoadingState(); }
    if (_error != null) { return ErrorState(message: _error!, onRetry: _load); }
    if (_contracts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.awaitingContracts, style: const TextStyle(fontSize: 14, color: ShadColors.textSecondary)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._contracts.map((c) => _contractCard(c)),
        ],
      ),
    );
  }

  Widget _contractCard(dynamic c) {
    final l10n = AppLocalizations.of(context)!;
    final status = c['status'] as String? ?? '';
    final needsAction = status == 'sent';
    final isApproved = status == 'company_approved';

    return GestureDetector(
      onTap: () => _showDetailModal(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ShadColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(c['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.textPrimary))),
            if (c['contract_type'] == 'additional')
              Container(
                margin: const EdgeInsetsDirectional.only(start: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [ShadColors.gold.withAlpha(50), ShadColors.gold.withAlpha(25)]),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ShadColors.gold.withAlpha(80)),
                ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_circle_outline, size: 10, color: ShadColors.gold),
                    const SizedBox(width: 3),
                    Text(l10n.additionalContract, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ShadColors.gold)),
                  ]),
              ),
            if (c['contract_type'] != 'additional')
              Container(
                margin: const EdgeInsetsDirectional.only(start: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ShadColors.infoBg.withAlpha(60),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ShadColors.infoAccent.withAlpha(80)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.description_outlined, size: 10, color: ShadColors.infoAccent),
                  const SizedBox(width: 3),
                  Text(l10n.mainContract, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ShadColors.infoAccent)),
                ]),
              ),
            StatusBadge(status: status),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Text('${c['value'] ?? 0} ${c['currency'] as String? ?? 'SAR'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
          ]),
          if (_clientType == 'business')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l10n.contractValueExcludesVat, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
            ),
          if (c['start_date'] != null) ...[
            const SizedBox(height: 4),
            Text((c['start_date'] as String).split('T')[0], style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
          ],
          if (status == 'edit_requested' && c['edit_reason'] != null && (c['edit_reason'] as String).isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ShadColors.gold.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(l10n.editReasonLabel(c['edit_reason'] as String), style: const TextStyle(fontSize: 10, color: ShadColors.gold), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
          if (needsAction) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _clientAction(c['id'], 'approved'),
                    icon: const Icon(Icons.check, size: 14),
                    label: Text(l10n.approve, style: const TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShadColors.success,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () => _clientAction(c['id'], 'edit_requested'),
                    icon: const Icon(Icons.edit, size: 14),
                    label: Text(l10n.edit, style: const TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ShadColors.warning,
                      side: const BorderSide(color: ShadColors.warning),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
            ]),
          ],
          if (isApproved) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ShadColors.success.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ShadColors.success.withAlpha(40)),
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.check_circle, size: 16, color: ShadColors.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.contractApprovedByCompany, style: const TextStyle(fontSize: 11, color: ShadColors.success))),
                ]),
                if (widget.onGoToPayments != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onGoToPayments?.call(),
                      icon: const Icon(Icons.payment, size: 16),
                      label: Text(l10n.goToPayment, style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShadColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  void _showDetailModal(dynamic c) { showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) => ContractDetailSheet(contract: c, clientType: _clientType, onAction: _clientAction, onRefresh: _load, onGoToPayments: widget.onGoToPayments, api: _api, fileProvider: _fileProvider)); }
}
