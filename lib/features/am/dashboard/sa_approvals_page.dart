import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
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
      color: Lx.crimsonInk,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Lx.crimsonInk))
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
              children: [
                // Mockup `.ph`: eyebrow + serif h1 (+ the total count).
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
                  child: Row(children: [
                    Expanded(child: LuxePageTitle(l10n.amStatPendingApprovals)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: const Color(0x59941414))),
                      child: Text('$total', style: Lx.display(context, size: 14, color: Lx.crimsonInk)),
                    ),
                  ]),
                ),
                _buildPillsFilter(total),
                const SizedBox(height: 14),
                if (_filteredItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text(l10n.amNoPendingApprovals, style: Lx.text(context, size: 13.5, color: Lx.faint))),
                  )
                else
                  ..._filteredItems.map((item) => _approvalCard(item)),
              ],
            ),
    );
  }

  /// Mockup `.chips` / `.chip.on`.
  Widget _buildPillsFilter(int total) {
    final l10n = AppLocalizations.of(context)!;
    final filters = [
      (l10n.all, total),
      (l10n.saApprovalsContracts, _contracts.length),
      (l10n.saApprovalsPayments, _payments.length),
      (l10n.approvals, _approvals.length),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.asMap().entries.map((entry) {
          final i = entry.key;
          final (label, count) = entry.value;
          final active = _filterIndex == i;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              key: ValueKey('approvals-chip-$i'),
              onTap: () => setState(() => _filterIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFF0F0F0) : null,
                  borderRadius: BorderRadius.circular(Lx.rPill),
                  border: Border.all(color: active ? const Color(0xFFF0F0F0) : Lx.line2),
                ),
                child: Text('$label ($count)', style: Lx.text(context, size: 12, color: active ? const Color(0xFF111111) : Lx.muted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Mockup `apprCard`.
  Widget _approvalCard(Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    final type = item['type'] as String?;
    final isContract = type == 'contract';
    final isApproval = type == 'approval';
    // 23 Sept 2026 — a third item type (pending Approval records, previously
    // missing from this list entirely — see _fetchApprovals above) alongside
    // the existing contract/payment two-way split.
    final typeLabel = isContract ? l10n.saApprovalsContractLabel : (isApproval ? l10n.saApprovalsApprovalLabel : l10n.saApprovalsPaymentLabel);
    final title = isContract
        ? l10n.saApprovalsContractApprovalTitle(item['title'].toString())
        : isApproval
            ? l10n.saApprovalsApprovalPendingTitle(item['title'].toString())
            : l10n.saApprovalsPaymentApprovalTitle(item['company']?.toString() ?? '');
    final subtitle = isContract
        ? '${item['company']} • ${double.tryParse(item['value']?.toString() ?? '') != null ? lxFormatMoney(double.parse(item['value'].toString())) : '0'} ${item['currency'] ?? ''}'
        : isApproval
            ? '${item['company'] ?? ''}'
            : '${lxFormatMoney(double.tryParse(item['amount']?.toString() ?? '') ?? 0)} ${item['currency'] ?? ''}';
    void open() {
      final wsId = item['workspace_id'];
      if (wsId == null) return;
      final tab = isContract ? 2 : (isApproval ? 4 : 3);
      context.push('/am/workspace/$wsId?tab=$tab');
    }

    return LuxeCard(
      attention: !isApproval,
      onTap: open,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LuxeKind(typeLabel),
        const SizedBox(height: 4),
        Text(title, style: Lx.text(context, size: 16)),
        const SizedBox(height: 2),
        Text(subtitle, style: Lx.text(context, size: 12.5, color: Lx.muted)),
        const SizedBox(height: 4),
        ClientTypeBadge(clientType: (item['client'] as Map<String, dynamic>?)?['client_type'] as String?, compact: true),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            LuxeStatusDot(status: isApproval ? LxStatus.wait : LxStatus.bad),
            const SizedBox(width: 7),
            Text(l10n.amStatusPending, style: Lx.text(context, size: 12, color: Lx.ink2)),
          ]),
          LuxeButton(label: l10n.amOpen, size: LuxeButtonSize.sm, onPressed: open),
        ]),
      ]),
    );
  }
}
