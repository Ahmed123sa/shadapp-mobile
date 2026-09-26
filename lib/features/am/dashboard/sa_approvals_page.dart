import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../data/dashboard_stats_repository.dart';
import '../../../providers/dashboard_stats_provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class SaApprovalsPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with a mocked
  // provider instead of hitting the network.
  //
  // pending-approvals-plan.md ك5 — replaced the four separate
  // client/contract/payment/approval providers this screen used to drive its
  // own N+1 per-workspace fetch loop with. Everything now comes from one
  // GET /dashboard/pending-approvals call via this single provider.
  final DashboardStatsProvider? dashboardStatsProvider;
  const SaApprovalsPage({super.key, this.dashboardStatsProvider});

  @override
  State<SaApprovalsPage> createState() => _SaApprovalsPageState();
}

class _SaApprovalsPageState extends State<SaApprovalsPage> {
  late final DashboardStatsProvider _dashboardStatsProvider =
      widget.dashboardStatsProvider ?? DashboardStatsProvider(repository: DashboardStatsRepository());
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _payments = [];
  // 23 Sept 2026 — the "Approvals" badge on the AM dashboard counts pending
  // Approval records (client-facing approval requests raised from a
  // workspace's own Approvals tab) alongside pending contracts, but this
  // screen used to only list contracts+payments — so the badge could say 2
  // while this list showed 1. Now covered by the same endpoint call below.
  List<Map<String, dynamic>> _approvals = [];
  bool _loading = true;
  int _filterIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // pending-approvals-plan.md ك5 — one request to
  // GET /dashboard/pending-approvals (already scoped server-side to this
  // user, same DashboardScope the badge/stats endpoints use) instead of the
  // old loop: fetch every client, then that client's workspace's contracts,
  // one request per workspace, plus two more full-pagination loops for
  // payments and approvals. That old loop was N+1 and, since it paginated at
  // 30/request, could still silently miss older pending items on a large
  // book of clients. `limit: 200` (the endpoint's own max) is passed
  // explicitly so this screen keeps its previous "no real cap" behavior
  // rather than falling back to the endpoint's own default of 50.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _dashboardStatsProvider.fetchPendingApprovals(limit: 200);
      final awaitingYou = _asMap(response['awaiting_you']);
      final awaitingClient = _asMap(response['awaiting_client']);
      // Both groups render as identical "Approve Contract" cards — this
      // screen never visually distinguished a 'client_approved' contract
      // (awaiting_you) from a 'sent' one (awaiting_client) even before this
      // migration, see saApprovalsContractApprovalTitle below — so they're
      // merged back into one flat list here, same as the old loop produced.
      _contracts = [
        ..._mapItems(safeList(awaitingClient['contracts']), 'contract'),
        ..._mapItems(safeList(awaitingYou['contracts']), 'contract'),
      ];
      _payments = _mapItems(safeList(awaitingYou['payments']), 'payment');
      _approvals = _mapItems(safeList(awaitingClient['approvals']), 'approval');
    } catch (e, s) {
      AppLog.error('sa_approvals_page._load', e, s);
      _contracts = [];
      _payments = [];
      _approvals = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _asMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  // Normalizes one group of endpoint items (each already carrying id, title
  // or amount, value, currency, status, workspace_id, client) into the flat
  // shape _approvalCard expects: same fields plus a top-level 'company'
  // (read off the nested client) and a 'type' tag, matching the shape the
  // old per-source fetch methods used to build by hand.
  List<Map<String, dynamic>> _mapItems(List<dynamic> raw, String type) {
    return raw.whereType<Map>().map((i) {
      final item = Map<String, dynamic>.from(i);
      final client = item['client'] is Map ? Map<String, dynamic>.from(item['client'] as Map) : null;
      return <String, dynamic>{
        ...item,
        'company': client?['company_name'] ?? '',
        'client': client,
        'type': type,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredItems {
    switch (_filterIndex) {
      case 1: return _contracts;
      case 2: return _payments.cast<Map<String, dynamic>>();
      case 3: return _approvals;
      default: return [..._contracts, ..._payments.cast<Map<String, dynamic>>(), ..._approvals];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = _contracts.length + _payments.length + _approvals.length;
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Text(l10n.amStatPendingApprovals, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ShadColors.crimson.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                    child: Text('$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  ),
                ]),
                const SizedBox(height: 12),
                _buildPillsFilter(total),
                const SizedBox(height: 12),
                if (_filteredItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text(l10n.amNoPendingApprovals, style: const TextStyle(fontSize: 13, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
                  )
                else
                  ..._filteredItems.map((item) => _approvalCard(item)),
              ],
            ),
    );
  }

  Widget _buildPillsFilter(int total) {
    final l10n = AppLocalizations.of(context)!;
    final filters = [
      (l10n.all, total),
      (l10n.saApprovalsContracts, _contracts.length),
      (l10n.saApprovalsPayments, _payments.length),
      (l10n.approvals, _approvals.length),
    ];
    return Row(
      children: filters.asMap().entries.map((entry) {
        final i = entry.key;
        final (label, count) = entry.value;
        final active = _filterIndex == i;
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 6),
          child: GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? ShadColors.gold.withAlpha(25) : ShadColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? ShadColors.gold : ShadColors.cardBorder),
              ),
              child: Text('$label ($count)', style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? ShadColors.gold : ShadColors.textSecondary, fontFamily: 'Archivo')),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _approvalCard(Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    final type = item['type'] as String?;
    final isContract = type == 'contract';
    final isApproval = type == 'approval';
    // 23 Sept 2026 — a third item type (pending Approval records, previously
    // missing from this list entirely — see _fetchApprovals above) alongside
    // the existing contract/payment two-way split.
    final accentColor = isContract ? ShadColors.gold : (isApproval ? ShadColors.purple : ShadColors.sent);
    final typeLabel = isContract ? l10n.saApprovalsContractLabel : (isApproval ? l10n.saApprovalsApprovalLabel : l10n.saApprovalsPaymentLabel);
    final title = isContract
        ? l10n.saApprovalsContractApprovalTitle(item['title'].toString())
        : isApproval
            ? l10n.saApprovalsApprovalPendingTitle(item['title'].toString())
            : l10n.saApprovalsPaymentApprovalTitle(item['company']?.toString() ?? '');
    final subtitle = isContract
        ? '${item['company']} • ${double.tryParse(item['value']?.toString() ?? '')?.toStringAsFixed(0) ?? '0'} ${item['currency'] ?? ''}'
        : isApproval
            ? '${item['company'] ?? ''}'
            : '${item['currency'] ?? ''} ${(double.tryParse(item['amount']?.toString() ?? '') ?? 0).toStringAsFixed(0)}';

    return GestureDetector(
      onTap: () {
        final wsId = item['workspace_id'];
        if (wsId == null) return;
        final tab = isContract ? 2 : (isApproval ? 4 : 3);
        context.push('/am/workspace/$wsId?tab=$tab');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ShadColors.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 3,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo'))),
                  const SizedBox(width: 6),
                  ClientTypeBadge(clientType: (item['client'] as Map<String, dynamic>?)?['client_type'] as String?, compact: true),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(typeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: accentColor, fontFamily: 'Archivo')),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
