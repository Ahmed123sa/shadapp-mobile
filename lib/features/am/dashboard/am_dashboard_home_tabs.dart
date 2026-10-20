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

// ── Staff mockup `pHome` pieces ──

Widget _head(BuildContext context, ApiClient api) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final greet = now.hour < 12 ? l10n.amGreetMorning : now.hour < 18 ? l10n.amGreetAfternoon : l10n.amGreetEvening;
  final locale = Localizations.localeOf(context).toString();
  final isSA = api.role == 'super_admin';
  final name = isSA ? '' : (api.userName ?? '').trim().split(RegExp(r'\s+')).first;
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(DateFormat.yMMMMEEEEd(locale).format(now).toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.6)),
      const SizedBox(height: 4),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: name.isEmpty ? greet : '$greet, $name'),
          const TextSpan(text: '.', style: TextStyle(color: Lx.crimsonInk)),
        ]),
        style: Lx.display(context, size: 30),
      ),
      const SizedBox(height: 6),
      Text(isSA ? l10n.amHomeSubSa : l10n.amHomeSubAm, style: Lx.text(context, size: 13, color: Lx.muted)),
    ]),
  );
}

/// Mockup `.kpi`.
Widget _kpi(BuildContext context, String label, String value, String hint, {bool act = false}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: Lx.cardGradient,
      borderRadius: BorderRadius.circular(Lx.rCard),
      border: Border.all(color: act ? const Color(0x59941414) : Lx.line),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 1.6)),
      const SizedBox(height: 4),
      Text(value, style: Lx.display(context, size: 26)),
      const SizedBox(height: 2),
      Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 11.5, color: act ? Lx.crimsonInk : Lx.muted)),
    ]),
  );
}

Widget _kpiGrid(List<Widget> tiles) {
  final rows = <Widget>[];
  for (var i = 0; i < tiles.length; i += 2) {
    rows.add(Row(children: [
      Expanded(child: tiles[i]),
      const SizedBox(width: 10),
      Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
    ]));
    if (i + 2 < tiles.length) rows.add(const SizedBox(height: 10));
  }
  return Column(children: rows);
}

/// Mockup `.sh`: serif section title + "View all" link.
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

Widget _waitingList(BuildContext context, List<Map<String, dynamic>> pendingContracts, List<dynamic> pendingPayments, VoidCallback onOpen) {
  final l10n = AppLocalizations.of(context)!;
  Widget card({required String kind, required String title, required String sub}) => LuxeCard(
        attention: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LuxeKind(kind),
          const SizedBox(height: 4),
          Text(title, style: Lx.text(context, size: 16)),
          if (sub.isNotEmpty) Text(sub, style: Lx.text(context, size: 12.5, color: Lx.muted)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const LuxeStatusDot(status: LxStatus.bad),
              const SizedBox(width: 7),
              Text(l10n.amStatusPending, style: Lx.text(context, size: 12, color: Lx.ink2)),
            ]),
            LuxeButton(label: l10n.amOpen, size: LuxeButtonSize.sm, onPressed: onOpen),
          ]),
        ]),
      );

  if (pendingContracts.isEmpty && pendingPayments.isEmpty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text(l10n.amNoPendingApprovals, style: Lx.text(context, size: 12.5, color: Lx.faint))),
    );
  }
  return Column(children: [
    ...pendingContracts.take(2).map((c) => card(
          kind: l10n.amContractApproval,
          title: '${c['title'] ?? ''}',
          sub: '${c['company'] ?? ''} • ${double.tryParse(c['value']?.toString() ?? '') != null ? lxFormatMoney(double.parse(c['value'].toString())) : '0'} ${c['currency'] ?? ''}',
        )),
    ...pendingPayments.take(2).map((p) {
      final client = p['workspace']?['client'] as Map<String, dynamic>?;
      final amt = double.tryParse(p['amount']?.toString() ?? '') ?? 0;
      return card(
        kind: l10n.amPaymentApproval,
        title: '${client?['company_name'] ?? ''}',
        sub: '${lxFormatMoney(amt)} ${p['currency'] ?? ''}',
      );
    }),
  ]);
}

Widget _meetingsLink(BuildContext context, VoidCallback onTap) {
  final l10n = AppLocalizations.of(context)!;
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: SizedBox(
      width: double.infinity,
      child: LuxeButton(key: const ValueKey('home-meetings'), label: l10n.amStatMeetings, lxIcon: 'video', onPressed: onTap),
    ),
  );
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
}) {
  final l10n = AppLocalizations.of(context)!;
  return ListView(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
    children: [
      _head(context, api),
      _kpiGrid([
        _kpi(context, l10n.amStatTotalClients, '$clientsTotal', ''),
        _kpi(context, l10n.amStatActiveContracts, '$contractsActive', ''),
        // Money is off-limits for manager assistants.
        if (!api.isAssistant) _kpi(context, l10n.amStatPendingPayments, '$paymentsPending', ''),
        _kpi(context, l10n.amStatPendingApprovals, '$approvalsTotal', l10n.amKpiNeedAction, act: true),
      ]),
      _meetingsLink(context, onShowAllMeetings),
      _sectionHead(context, l10n.amWaitingOnYou, link: l10n.amViewAll, onLink: () => onSelectTab(1)),
      _waitingList(context, pendingContracts, pendingPayments, () => onSelectTab(1)),
      _sectionHead(context, l10n.amClients, link: l10n.amViewAll, onLink: () => onSelectTab(2)),
      if (allClients.isNotEmpty)
        LuxeCard(
          child: Column(children: [
            for (var i = 0; i < allClients.take(3).length; i++)
              _clientRow(context, allClients[i] as Map<String, dynamic>, onOpenClient, last: i == allClients.take(3).length - 1),
          ]),
        ),
      if (allClients.isEmpty) _buildEmptyState(context, api, load),
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
}) {
  final l10n = AppLocalizations.of(context)!;
  return ListView(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
    children: [
      _head(context, api),
      _kpiGrid([
        _kpi(context, l10n.amStatTotalClients, '$clientsTotal', ''),
        _kpi(context, l10n.amStatActiveContracts, '$contractsActive', ''),
        _kpi(context, l10n.amStatPendingPayments, '$paymentsPending', ''),
        _kpi(context, l10n.amStatPendingApprovals, '$approvalsTotal', l10n.amKpiNeedAction, act: true),
      ]),
      _meetingsLink(context, onShowAllMeetings),
      _sectionHead(context, l10n.amWaitingOnYou, link: l10n.amViewAll, onLink: () => onSelectTab(1)),
      _waitingList(context, pendingContracts, pendingPayments, () => onSelectTab(1)),
      _sectionHead(context, l10n.accountManagers_title, link: l10n.amViewAll, onLink: () => onSelectTab(3)),
      if (allManagers.isNotEmpty)
        LuxeCard(
          child: Column(children: [
            for (var i = 0; i < allManagers.take(3).length; i++)
              _managerRow(context, allManagers[i] as Map<String, dynamic>, onManagerTap, last: i == allManagers.take(3).length - 1),
          ]),
        ),
      if (allManagers.isEmpty) _buildEmptyState(context, api, load),
    ],
  );
}

/// Mockup `.doc` row: avatar + name/sub on one side, count/status on the other.
Widget _managerRow(BuildContext context, Map<String, dynamic> manager, void Function(Map<String, dynamic>) onTap, {bool last = false}) {
  final l10n = AppLocalizations.of(context)!;
  final name = manager['name'] as String? ?? '';
  final email = manager['email'] as String? ?? '';
  final clientCount = int.tryParse(manager['managed_clients_count']?.toString() ?? '') ?? 0;
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
            Text(email, style: Lx.text(context, size: 12, color: Lx.muted)),
          ]),
        ),
        Text('$clientCount', style: Lx.display(context, size: 15)),
        const SizedBox(width: 4),
        Text(l10n.amClients, style: Lx.text(context, size: 10, color: Lx.muted)),
      ]),
    ),
  );
}

Widget _clientRow(BuildContext context, Map<String, dynamic> client, void Function(Map<String, dynamic>) onTap, {bool last = false}) {
  final l10n = AppLocalizations.of(context)!;
  final ws = client['workspace'] as Map<String, dynamic>?;
  final wsActive = (ws?['status'] as String? ?? 'inactive') == 'active';
  final name = client['company_name'] as String? ?? '';
  final person = client['contact_person'] as String? ?? '';
  return InkWell(
    onTap: () => onTap(client),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: Lx.text(context, size: 13.5)),
            Text(person, style: Lx.text(context, size: 12, color: Lx.muted)),
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
