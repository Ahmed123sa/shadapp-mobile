import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
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
      // Kept as one flat list, but each item now remembers its group so the
      // card can show the mockup's status: company approval vs awaiting client.
      _contracts = [
        ..._mapItems(safeList(awaitingYou['contracts']), 'contract', awaitingYou: true),
        ..._mapItems(safeList(awaitingClient['contracts']), 'contract'),
      ];
      _payments = _mapItems(safeList(awaitingYou['payments']), 'payment', awaitingYou: true);
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
  List<Map<String, dynamic>> _mapItems(List<dynamic> raw, String type, {bool awaitingYou = false}) {
    return raw.whereType<Map>().map((i) {
      final item = Map<String, dynamic>.from(i);
      final client = item['client'] is Map ? Map<String, dynamic>.from(item['client'] as Map) : null;
      return <String, dynamic>{
        ...item,
        'company': client?['company_name'] ?? '',
        'client': client,
        'type': type,
        'awaiting_you': awaitingYou,
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
    final title = Lx.display(context, size: 28).copyWith(height: 1.2);
    return RefreshIndicator(
      onRefresh: _load,
      color: Lx.crimsonInk,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Lx.crimsonInk))
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 18),
              children: [
                // Mockup head('Inbox', 'Approvals'): `.ph` 6 0 14, eyebrow
                // 10.5 (.26em) faint, h1.h serif 28 + crimson ".".
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.approvalsEyebrow.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.73)),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: l10n.amNavApprovals),
                        TextSpan(text: '.', style: title.copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
                      ]),
                      key: const ValueKey('lx-page-title'),
                      style: title,
                    ),
                  ]),
                ),
                _buildPillsFilter(),
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

  /// Mockup `.chips` (gap 8, margin-bottom 14) / `.chip` (6 14, 12px muted,
  /// line-2 border) / `.chip.on` (#F0F0F0 fill, #111 text). No counts.
  Widget _buildPillsFilter() {
    final l10n = AppLocalizations.of(context)!;
    final filters = [l10n.all, l10n.saApprovalsContracts, l10n.saApprovalsPayments, l10n.approvals];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < filters.length; i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: GestureDetector(
                  key: ValueKey('approvals-chip-$i'),
                  onTap: () => setState(() => _filterIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _filterIndex == i ? const Color(0xFFF0F0F0) : null,
                      borderRadius: BorderRadius.circular(Lx.rPill),
                      border: Border.all(color: _filterIndex == i ? const Color(0xFFF0F0F0) : Lx.line2),
                    ),
                    child: Text(filters[i], style: Lx.text(context, size: 12, color: _filterIndex == i ? const Color(0xFF111111) : Lx.muted)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _age(String? iso) {
    final l10n = AppLocalizations.of(context)!;
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) return l10n.amAgeMin(diff.inMinutes < 1 ? 1 : diff.inMinutes);
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return diff.inHours < 6 ? l10n.amAgeHour(diff.inHours) : l10n.amAgeToday;
    }
    final y = now.subtract(const Duration(days: 1));
    if (t.year == y.year && t.month == y.month && t.day == y.day) return l10n.chatYesterday;
    return '${t.day}/${t.month}';
  }

  /// Mockup `apprCard`: `.card` (`.ap` when it waits on the company), kind,
  /// title 16 (margin 4 0 2), sub 12.5 "client · age", then status + Open.
  Widget _approvalCard(Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    final type = item['type'] as String?;
    final isContract = type == 'contract';
    final isApproval = type == 'approval';
    final awaitingYou = item['awaiting_you'] == true;
    final kind = isContract ? l10n.saApprovalsContractLabel : (isApproval ? l10n.saApprovalsApprovalLabel : l10n.saApprovalsPaymentLabel);
    final title = isContract || isApproval
        ? '${item['title'] ?? ''}'
        : '${l10n.amPaymentProof} · ${lxFormatMoney(double.tryParse(item['amount']?.toString() ?? '') ?? 0)} ${item['currency'] ?? ''}'.trim();
    final sub = [
      '${item['company'] ?? ''}',
      _age((item['updated_at'] ?? item['created_at'])?.toString()),
    ].where((e) => e.isNotEmpty).join(' · ');
    final status = !awaitingYou ? l10n.amStAwaitingClient : (isContract ? l10n.amStCompanyApproval : l10n.amStNeedsReview);
    void open() {
      final wsId = item['workspace_id'];
      if (wsId == null) return;
      final tab = isContract ? 2 : (isApproval ? 4 : 3);
      context.push('/am/workspace/$wsId?tab=$tab');
    }

    return LuxeCard(
      attention: awaitingYou,
      onTap: open,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LuxeKind(kind),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text(title, style: Lx.text(context, size: 16)),
        ),
        if (sub.isNotEmpty) Text(sub, style: Lx.text(context, size: 12.5, color: Lx.muted)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            LuxeStatusDot(status: awaitingYou ? LxStatus.bad : LxStatus.wait),
            const SizedBox(width: 7),
            Text(status, style: Lx.text(context, size: 12, color: Lx.ink2)),
          ]),
          LuxeButton(label: l10n.amOpen, size: LuxeButtonSize.sm, onPressed: open),
        ]),
      ]),
    );
  }
}
