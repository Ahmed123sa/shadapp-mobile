// Extracted from am_dashboard_page.dart as part of بند ٨ (file splitting).
// The two home-tab bodies (AM's client-centric tab and SA's manager-centric
// tab) plus their shared display helpers. These are pure UI: the parent page
// still owns every list of data and every side-effecting action (tab
// switching, opening a client, opening the meetings sheet, creating a
// client), passed in as params/callbacks.
//
// buildAmHomeTab and buildHomeTab are NOT merged into one parameterized
// function even though they're structurally similar — they have a real
// difference (buildAmHomeTab's reports card is gated on `isSA`, which is
// always false at its only call site, while buildHomeTab's reports card is
// unconditional) that must be preserved exactly, not "cleaned up". Same
// precedent as the chat bubble dedup work: near-duplicates that differ in a
// real way stay separate.
//
// 24 Sept 2026 (server-side-stats-plan.md, Stage 3) — the four summary-card
// numbers (clientsTotal/contractsActive/paymentsPending/approvalsTotal) are
// now passed in from GET /dashboard/stats instead of computed here from
// allClients/allManagers/allContracts/pendingContracts/pendingPayments. The
// unused `allContracts` param was dropped entirely; allClients/allManagers/
// pendingContracts/pendingPayments are kept only for the "latest N" preview
// sections below the cards (recent pending approvals, recent
// clients/managers) — previews are fine staying capped at whatever page the
// parent fetched, same as the web dashboard's "recent activity"
// (server-side-stats-plan.md, W11).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../models/app_notification.dart';

// ── Staff mockup `pHome` (design/mobile/staff-mobile-mockup.html) ──
// Order: head → 4 KPIs → "Waiting on you" (3 cards) → managers (SA) /
// my clients (AM) → recent activity. Values copied from the mockup CSS.

/// Mockup `head(date, greeting, sub)`: `.ph` padding 6 0 14, eyebrow 10.5
/// (.26em), h1.h serif 28 + crimson ".", lead 13 muted.
Widget _head(BuildContext context, ApiClient api) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final greet = now.hour < 12 ? l10n.amGreetMorning : now.hour < 18 ? l10n.amGreetAfternoon : l10n.amGreetEvening;
  final locale = Localizations.localeOf(context).toString();
  final isSA = api.role == 'super_admin';
  final name = (api.userName ?? '').trim().split(RegExp(r'\s+')).first;
  final date = '${DateFormat.EEEE(locale).format(now)} · ${DateFormat('d MMMM y', locale).format(now)}';
  final h1 = Lx.display(context, size: 28).copyWith(height: 1.2);
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(date.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.73)),
      const SizedBox(height: 6),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: name.isEmpty ? greet : '$greet, $name'),
          TextSpan(text: '.', style: h1.copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
        ]),
        key: const ValueKey('home-title'),
        style: h1,
      ),
      const SizedBox(height: 8),
      Text(isSA ? l10n.amHomeSubSa : l10n.amHomeSubAm, style: Lx.text(context, size: 13, color: Lx.muted)),
    ]),
  );
}

/// Mockup `.kpi`: border line r16, padding 14, card gradient; `.l` 10px
/// (.16em) faint; `.v` serif 26 (+ 11px currency); `.h` 11.5 muted, crimson
/// on the "act" tile whose border is crimson .35.
Widget _kpi(BuildContext context, String label, String value, String hint, {String unit = '', bool act = false}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: Lx.cardGradient,
      borderRadius: BorderRadius.circular(Lx.rCard),
      border: Border.all(color: act ? const Color(0x59941414) : Lx.line),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 1.6)),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: value),
            if (unit.isNotEmpty) TextSpan(text: ' $unit', style: Lx.text(context, size: 11, color: Lx.muted)),
          ]),
          style: Lx.display(context, size: 26),
        ),
      ),
      if (hint.isNotEmpty)
        Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 11.5, color: act ? Lx.crimsonInk : Lx.muted)),
    ]),
  );
}

/// Mockup `.kg`: 2 columns, gap 10, equal-height rows, margin-bottom 6.
Widget _kpiGrid(List<Widget> tiles) {
  final rows = <Widget>[];
  for (var i = 0; i < tiles.length; i += 2) {
    rows.add(IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: tiles[i]),
        const SizedBox(width: 10),
        Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
      ]),
    ));
    if (i + 2 < tiles.length) rows.add(const SizedBox(height: 10));
  }
  return Padding(padding: const EdgeInsets.only(bottom: 6), child: Column(children: rows));
}

/// Mockup `.sh`: margin 20 0 10, serif 19, "View all" `.lnk` (12.5 ink-2,
/// underline line-2).
Widget _sectionHead(BuildContext context, String title, {String? link, VoidCallback? onLink}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: Lx.display(context, size: 19)),
      if (link != null)
        GestureDetector(
          onTap: onLink,
          child: Container(
            padding: const EdgeInsets.only(bottom: 1),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
            child: Text(link, style: Lx.text(context, size: 12.5, color: Lx.ink2)),
          ),
        ),
    ]),
  );
}

String _age(BuildContext context, String? iso) {
  final l10n = AppLocalizations.of(context)!;
  final t = DateTime.tryParse(iso ?? '')?.toLocal();
  if (t == null) return '';
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 60) return l10n.amAgeMin(diff.inMinutes < 1 ? 1 : diff.inMinutes);
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  if (sameDay) return diff.inHours < 6 ? l10n.amAgeHour(diff.inHours) : l10n.amAgeToday;
  final y = now.subtract(const Duration(days: 1));
  if (t.year == y.year && t.month == y.month && t.day == y.day) return l10n.chatYesterday;
  return DateFormat('d MMM', Localizations.localeOf(context).toString()).format(t);
}

/// Mockup `apprCard`: `.card` (`.ap` when it needs the company), kind,
/// title 16, sub "client · manager · age", then status + "Open".
Widget _apprCard(BuildContext context, {required String kind, required String title, required String sub, required String status, required LxStatus dot, required bool ap, required VoidCallback onOpen}) {
  final l10n = AppLocalizations.of(context)!;
  return LuxeCard(
    attention: ap,
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
          LuxeStatusDot(status: dot),
          const SizedBox(width: 7),
          Text(status, style: Lx.text(context, size: 12, color: Lx.ink2)),
        ]),
        LuxeButton(label: l10n.amOpen, size: LuxeButtonSize.sm, onPressed: onOpen),
      ]),
    ]),
  );
}

Widget _waitingList(BuildContext context, List<Map<String, dynamic>> pendingContracts, List<dynamic> pendingPayments, VoidCallback onOpen, {required bool showManager}) {
  final l10n = AppLocalizations.of(context)!;
  String join(List<String?> parts) => parts.where((p) => p != null && p.isNotEmpty).join(' · ');

  final cards = <Widget>[
    // A payment proof always waits on the company: "Needs your review".
    ...pendingPayments.map((p) {
      final ws = p['workspace'] as Map<String, dynamic>?;
      final client = ws?['client'] as Map<String, dynamic>?;
      final amt = double.tryParse(p['amount']?.toString() ?? '') ?? 0;
      final mgr = ws?['account_manager'];
      final String? mgrName = mgr is Map ? mgr['name']?.toString() : null;
      return _apprCard(
        context,
        kind: l10n.calendarPayment,
        title: '${l10n.amPaymentProof} · ${lxFormatMoney(amt)} ${p['currency'] ?? ''}'.trim(),
        sub: join([client?['company_name'] as String?, showManager ? mgrName : null, _age(context, p['created_at']?.toString())]),
        status: l10n.amStNeedsReview,
        dot: LxStatus.bad,
        ap: true,
        onOpen: onOpen,
      );
    }),
    // client_approved → waits on the company; sent → waits on the client.
    ...pendingContracts.map((c) {
      final company = c['status'] == 'client_approved';
      final String? mgrName = c['manager']?.toString();
      return _apprCard(
        context,
        kind: l10n.calendarContract,
        title: '${c['title'] ?? ''}',
        sub: join([c['company'] as String?, showManager ? mgrName : null, _age(context, c['created_at']?.toString())]),
        status: company ? l10n.amStCompanyApproval : l10n.amStAwaitingClient,
        dot: company ? LxStatus.bad : LxStatus.wait,
        ap: company,
        onOpen: onOpen,
      );
    }),
  ];

  if (cards.isEmpty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text(l10n.amNoPendingApprovals, style: Lx.text(context, size: 12.5, color: Lx.faint))),
    );
  }
  return Column(children: cards.take(3).toList());
}

/// Mockup "Recent activity": `.doc` rows — dot, title / sub, time.
Widget _activity(BuildContext context, List<AppNotification> items) {
  final l10n = AppLocalizations.of(context)!;
  if (items.isEmpty) return const SizedBox.shrink();
  LxStatus dotFor(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('approved') || t.contains('paid') || t.contains('completed')) return LxStatus.ok;
    if (t.contains('reject') || t.contains('request') || t.contains('pending') || t.contains('submitted')) return LxStatus.bad;
    return LxStatus.wait;
  }

  String timeOf(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) return DateFormat('HH:mm').format(t);
    final y = now.subtract(const Duration(days: 1));
    if (t.year == y.year && t.month == y.month && t.day == y.day) return l10n.chatYesterday;
    return DateFormat('d MMM', Localizations.localeOf(context).toString()).format(t);
  }

  final shown = items.take(4).toList();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionHead(context, l10n.amRecentActivity),
    LuxeCard(
      child: Column(children: [
        for (var i = 0; i < shown.length; i++)
          Container(
            key: ValueKey('home-activity-$i'),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: i == shown.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 7), child: LuxeStatusDot(status: dotFor(shown[i].type))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(shown[i].title.isNotEmpty ? shown[i].title : shown[i].message, style: Lx.text(context, size: 13.5)),
                  if (shown[i].title.isNotEmpty && shown[i].message.isNotEmpty)
                    Text(shown[i].message, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                ]),
              ),
              const SizedBox(width: 10),
              Text(timeOf(shown[i].createdAt), style: Lx.text(context, size: 12.5, color: Lx.muted)),
            ]),
          ),
      ]),
    ),
  ]);
}

/// Largest currency in revenue_this_month → (formatted amount, code).
(String, String) _revenue(Map<String, dynamic>? revenue) {
  if (revenue == null || revenue.isEmpty) return ('0', '');
  String? best;
  double bestV = -1;
  revenue.forEach((k, v) {
    final d = double.tryParse(v.toString()) ?? 0;
    if (d > bestV) {
      bestV = d;
      best = k;
    }
  });
  return (lxFormatMoney(bestV < 0 ? 0 : bestV), best ?? '');
}

Widget buildAmHomeTab({
  required BuildContext context,
  required List<dynamic> allClients,
  required List<Map<String, dynamic>> pendingContracts,
  required List<dynamic> pendingPayments,
  required bool isSA,
  required ApiClient api,
  required void Function(int) onSelectTab,
  required VoidCallback onShowAllMeetings,
  required void Function(Map<String, dynamic>) onOpenClient,
  required Future<void> Function() load,
  required int clientsTotal,
  required int contractsActive,
  required int paymentsPending,
  required int approvalsTotal,
  int contractsAwaiting = 0,
  int unreadMessages = 0,
  List<AppNotification> recentActivity = const [],
}) {
  final l10n = AppLocalizations.of(context)!;
  final shownClients = allClients.take(3).toList();
  return ListView(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 18),
    children: [
      _head(context, api),
      // Mockup kAM: My clients · Active contracts · Pending approvals · Unread messages.
      _kpiGrid([
        _kpi(context, l10n.staffMyClientsTitle, '$clientsTotal', ''),
        _kpi(context, l10n.amStatActiveContracts, '$contractsActive', contractsAwaiting > 0 ? l10n.amKpiAwaitingApproval(contractsAwaiting) : ''),
        _kpi(context, l10n.amStatPendingApprovals, '$approvalsTotal', l10n.amKpiNeedAction, act: true),
        _kpi(context, l10n.amKpiUnreadMessages, '$unreadMessages', ''),
      ]),
      _sectionHead(context, l10n.amWaitingOnYou, link: l10n.amViewAll, onLink: () => onSelectTab(1)),
      _waitingList(context, pendingContracts, api.isAssistant ? const [] : pendingPayments, () => onSelectTab(1), showManager: false),
      _sectionHead(context, l10n.staffMyClientsTitle, link: l10n.amViewAll, onLink: () => onSelectTab(2)),
      if (shownClients.isNotEmpty)
        LuxeCard(
          child: Column(children: [
            for (var i = 0; i < shownClients.length; i++)
              _clientRow(context, shownClients[i] as Map<String, dynamic>, onOpenClient, last: i == shownClients.length - 1),
          ]),
        ),
      if (allClients.isEmpty) _buildEmptyState(context, api, load),
      _activity(context, recentActivity),
    ],
  );
}

Widget buildHomeTab({
  required BuildContext context,
  required List<dynamic> allManagers,
  required List<Map<String, dynamic>> pendingContracts,
  required List<dynamic> pendingPayments,
  required ApiClient api,
  required void Function(int) onSelectTab,
  required VoidCallback onShowAllMeetings,
  required void Function(Map<String, dynamic>) onManagerTap,
  required Future<void> Function() load,
  required int clientsTotal,
  required int contractsActive,
  required int paymentsPending,
  required int approvalsTotal,
  Map<String, dynamic>? revenueThisMonth,
  List<AppNotification> recentActivity = const [],
}) {
  final l10n = AppLocalizations.of(context)!;
  final (revValue, revUnit) = _revenue(revenueThisMonth);
  final month = DateFormat.MMM(Localizations.localeOf(context).toString()).format(DateTime.now());
  final shownManagers = allManagers.take(3).toList();
  return ListView(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 18),
    children: [
      _head(context, api),
      // Mockup kSA: Clients · Active contracts · Revenue · <month> · Pending approvals.
      _kpiGrid([
        _kpi(context, l10n.amClients, '$clientsTotal', ''),
        _kpi(context, l10n.amStatActiveContracts, '$contractsActive', allManagers.isNotEmpty ? l10n.amKpiAcrossManagers(allManagers.length) : ''),
        _kpi(context, '${l10n.amKpiRevenue} · $month', revValue, '', unit: revUnit),
        _kpi(context, l10n.amStatPendingApprovals, '$approvalsTotal', l10n.amKpiNeedAction, act: true),
      ]),
      _sectionHead(context, l10n.amWaitingOnYou, link: l10n.amViewAll, onLink: () => onSelectTab(1)),
      _waitingList(context, pendingContracts, pendingPayments, () => onSelectTab(1), showManager: true),
      _sectionHead(context, l10n.accountManagers_title, link: l10n.amViewAll, onLink: () => onSelectTab(3)),
      if (shownManagers.isNotEmpty)
        LuxeCard(
          child: Column(children: [
            for (var i = 0; i < shownManagers.length; i++)
              _managerRow(context, shownManagers[i] as Map<String, dynamic>, onManagerTap, last: i == shownManagers.length - 1),
          ]),
        ),
      if (allManagers.isEmpty) _buildEmptyState(context, api, load),
      _activity(context, recentActivity),
    ],
  );
}

/// Mockup managers card row: avatar sm (28) + name / "N clients", and the
/// manager's revenue in serif 15 + 10px currency when the API sends it.
Widget _managerRow(BuildContext context, Map<String, dynamic> manager, void Function(Map<String, dynamic>) onTap, {bool last = false}) {
  final l10n = AppLocalizations.of(context)!;
  final name = manager['name'] as String? ?? '';
  final clientCount = int.tryParse(manager['managed_clients_count']?.toString() ?? '') ?? 0;
  final revenue = double.tryParse(manager['revenue']?.toString() ?? '');
  final currency = manager['currency'] as String? ?? '';
  return InkWell(
    onTap: () => onTap(manager),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
      child: Row(children: [
        LuxeAvatar(initial: name.isNotEmpty ? name[0].toUpperCase() : '?', size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: Lx.text(context, size: 13.5)),
            Text(l10n.amClientsCount(clientCount), style: Lx.text(context, size: 12.5, color: Lx.muted)),
          ]),
        ),
        if (revenue != null)
          Text.rich(TextSpan(children: [
            TextSpan(text: lxFormatMoney(revenue), style: Lx.display(context, size: 15)),
            if (currency.isNotEmpty) TextSpan(text: ' $currency', style: Lx.text(context, size: 10, color: Lx.muted)),
          ])),
      ]),
    ),
  );
}

/// Mockup my-clients row: name / industry, workspace status on the other side.
Widget _clientRow(BuildContext context, Map<String, dynamic> client, void Function(Map<String, dynamic>) onTap, {bool last = false}) {
  final l10n = AppLocalizations.of(context)!;
  final ws = client['workspace'] as Map<String, dynamic>?;
  final wsActive = (ws?['status'] as String? ?? 'inactive') == 'active';
  final name = client['company_name'] as String? ?? '';
  final industry = (client['industry'] as String?)?.trim() ?? '';
  final sub = industry.isNotEmpty ? industry : (client['contact_person'] as String? ?? '');
  return InkWell(
    onTap: () => onTap(client),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: Lx.text(context, size: 13.5)),
            if (sub.isNotEmpty) Text(sub, style: Lx.text(context, size: 12.5, color: Lx.muted)),
          ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          LuxeStatusDot(status: wsActive ? LxStatus.ok : LxStatus.off),
          const SizedBox(width: 7),
          Text(wsActive ? l10n.amStatusActive : l10n.amStatusInactive, style: Lx.text(context, size: 12, color: Lx.ink2)),
        ]),
      ]),
    ),
  );
}

Widget _buildEmptyState(BuildContext context, ApiClient api, Future<void> Function() load) {
  final loc2 = AppLocalizations.of(context)!;
  final isSA = api.role == 'super_admin';
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      const LxIcon('users', size: 44, color: Lx.faint),
      const SizedBox(height: 16),
      Text(loc2.noClients, style: Lx.display(context, size: 20)),
      const SizedBox(height: 8),
      Text(loc2.noClientsSubtitle, style: Lx.text(context, size: 13.5, color: Lx.muted)),
      const SizedBox(height: 24),
      if (!isSA && !api.isAssistant)
        LuxeButton(
          label: loc2.createClient,
          lxIcon: 'plus',
          kind: LuxeButtonKind.primary,
          onPressed: () async {
            final created = await context.push<bool>('/am/clients/create');
            if (created == true) load();
          },
        ),
    ]),
  );
}
