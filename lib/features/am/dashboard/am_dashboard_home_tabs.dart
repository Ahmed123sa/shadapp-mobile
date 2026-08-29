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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/client_type_badge.dart';

Widget buildAmHomeTab({
  required BuildContext context,
  required List<dynamic> allClients,
  required List<dynamic> allContracts,
  required List<Map<String, dynamic>> pendingContracts,
  required List<dynamic> pendingPayments,
  required bool isSA,
  required ApiClient api,
  required void Function(int) onSelectTab,
  required VoidCallback onShowAllMeetings,
  required void Function(Map<String, dynamic>) onOpenClient,
  required Future<void> Function() load,
}) {
  final l10n = AppLocalizations.of(context)!;
  final totalClients = allClients.length;
  final activeContracts = allContracts.where((c) => c['status'] == 'company_approved' || c['status'] == 'completed').length;
  final totalPending = pendingContracts.length + pendingPayments.length;
  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(children: [
        Expanded(child: _homeStatCard(l10n.amStatTotalClients, '$totalClients', Icons.people, ShadColors.sent)),
        const SizedBox(width: 8),
        Expanded(child: _homeStatCard(l10n.amStatActiveContracts, '$activeContracts', Icons.description, ShadColors.gold)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _homeStatCard(l10n.amStatPendingPayments, '${pendingPayments.length}', Icons.payments, ShadColors.warning)),
        const SizedBox(width: 8),
        Expanded(child: _homeStatCard(l10n.amStatPendingApprovals, '$totalPending', Icons.pending_actions, ShadColors.crimson)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        if (isSA)
          Expanded(child: _homeStatCard(l10n.amStatReports, '', Icons.bar_chart, ShadColors.gold, onTap: () => context.push('/am/reports'))),
        if (isSA) const SizedBox(width: 8),
        Expanded(child: _homeStatCard(l10n.amStatMeetings, '', Icons.videocam, ShadColors.sent, onTap: onShowAllMeetings)),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Text(l10n.amRecentApprovals, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        const Spacer(),
        GestureDetector(
          onTap: () => onSelectTab(1),
          child: Text(l10n.amViewAll, style: const TextStyle(fontSize: 11, color: ShadColors.gold, fontFamily: 'Archivo')),
        ),
      ]),
      const SizedBox(height: 8),
      if (pendingContracts.isEmpty && pendingPayments.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text(l10n.amNoPendingApprovals, style: const TextStyle(fontSize: 12, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
        )
      else ...[
        if (pendingContracts.isNotEmpty)
          ...pendingContracts.take(2).map((c) => _approvalItem(
            title: '${l10n.amContractApproval} — ${c['title'] ?? ''}',
            subtitle: '${c['company'] ?? ''} • ${double.tryParse(c['value']?.toString() ?? '')?.toStringAsFixed(0) ?? '0'} ${c['currency'] ?? ''}',
            isContract: true,
          )),
        if (pendingPayments.isNotEmpty)
          ...pendingPayments.take(2).map((p) {
            final client = p['workspace']?['client'] as Map<String, dynamic>?;
            return _approvalItem(
              title: '${l10n.amPaymentApproval} — ${client?['company_name'] ?? ''}',
              subtitle: '${p['currency'] ?? ''} ${(double.tryParse(p['amount']?.toString() ?? '') ?? 0).toStringAsFixed(0)}',
              isContract: false,
            );
          }),
      ],
      const SizedBox(height: 20),
      Row(children: [
        Text(l10n.amClients, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        const Spacer(),
        GestureDetector(
          onTap: () => onSelectTab(2),
          child: Text(l10n.amViewAll, style: const TextStyle(fontSize: 11, color: ShadColors.gold, fontFamily: 'Archivo')),
        ),
      ]),
      const SizedBox(height: 8),
      if (allClients.isNotEmpty)
        ...allClients.take(3).map((c) => _clientCard(context, api, c, onOpenClient)),
      if (allClients.isEmpty)
        _buildEmptyState(context, api, load),
    ],
  );
}

Widget buildHomeTab({
  required BuildContext context,
  required List<dynamic> allManagers,
  required List<dynamic> allContracts,
  required List<Map<String, dynamic>> pendingContracts,
  required List<dynamic> pendingPayments,
  required ApiClient api,
  required void Function(int) onSelectTab,
  required VoidCallback onShowAllMeetings,
  required void Function(Map<String, dynamic>) onManagerTap,
  required Future<void> Function() load,
}) {
  final l10n = AppLocalizations.of(context)!;
  final totalClients = allManagers.fold<int>(0, (sum, m) => sum + ((m['managed_clients_count'] as int? ?? 0)));
  final activeContracts = allContracts.where((c) => c['status'] == 'company_approved' || c['status'] == 'completed').length;
  final totalPending = pendingContracts.length + pendingPayments.length;
  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      // Stats Grid 3x2
      Row(children: [
        Expanded(child: _homeStatCard(l10n.amStatTotalClients, '$totalClients', Icons.people, ShadColors.sent)),
        const SizedBox(width: 8),
        Expanded(child: _homeStatCard(l10n.amStatActiveContracts, '$activeContracts', Icons.description, ShadColors.gold)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _homeStatCard(l10n.amStatPendingPayments, '${pendingPayments.length}', Icons.payments, ShadColors.warning)),
        const SizedBox(width: 8),
        Expanded(child: _homeStatCard(l10n.amStatPendingApprovals, '$totalPending', Icons.pending_actions, ShadColors.crimson)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _homeStatCard(l10n.amStatReports, '', Icons.bar_chart, ShadColors.gold, onTap: () => context.push('/am/reports'))),
        const SizedBox(width: 8),
        Expanded(child: _homeStatCard(l10n.amStatMeetings, '', Icons.videocam, ShadColors.sent, onTap: onShowAllMeetings)),
      ]),
      const SizedBox(height: 20),
      // Latest Pending Approvals
      Row(children: [
        Text(l10n.amRecentApprovals, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        const Spacer(),
        GestureDetector(
          onTap: () => onSelectTab(1),
          child: Text(l10n.amViewAll, style: const TextStyle(fontSize: 11, color: ShadColors.gold, fontFamily: 'Archivo')),
        ),
      ]),
      const SizedBox(height: 8),
      if (pendingContracts.isEmpty && pendingPayments.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text(l10n.amNoPendingApprovals, style: const TextStyle(fontSize: 12, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
        )
      else ...[
        if (pendingContracts.isNotEmpty)
          ...pendingContracts.take(2).map((c) => _approvalItem(
            title: '${l10n.amContractApproval} — ${c['title'] ?? ''}',
            subtitle: '${c['company'] ?? ''} • ${double.tryParse(c['value']?.toString() ?? '')?.toStringAsFixed(0) ?? '0'} ${c['currency'] ?? ''}',
            isContract: true,
          )),
        if (pendingPayments.isNotEmpty)
          ...pendingPayments.take(2).map((p) {
            final client = p['workspace']?['client'] as Map<String, dynamic>?;
            return _approvalItem(
              title: '${l10n.amPaymentApproval} — ${client?['company_name'] ?? ''}',
              subtitle: '${p['currency'] ?? ''} ${(double.tryParse(p['amount']?.toString() ?? '') ?? 0).toStringAsFixed(0)}',
              isContract: false,
            );
          }),
      ],
      const SizedBox(height: 20),
      // Team Section
      Row(children: [
        Text(l10n.amNavTeam, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        const Spacer(),
        GestureDetector(
          onTap: () => onSelectTab(3),
          child: Text(l10n.amViewAll, style: const TextStyle(fontSize: 11, color: ShadColors.gold, fontFamily: 'Archivo')),
        ),
      ]),
      const SizedBox(height: 8),
      if (allManagers.isNotEmpty)
        ...allManagers.take(3).map((m) => _managerCard(context, api, m, onManagerTap)),
      if (allManagers.isEmpty)
        _buildEmptyState(context, api, load),
    ],
  );
}

Widget _homeStatCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ShadColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ShadColors.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: color),
        const Spacer(),
        if (value.isNotEmpty) Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: color, fontFamily: 'PlayfairDisplay')),
      ]),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
    ]),
  ),
  );
}

Widget _approvalItem({required String title, required String subtitle, required bool isContract}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: ShadColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ShadColors.cardBorder),
    ),
    child: Row(children: [
      Container(width: 3, height: 48, decoration: BoxDecoration(color: isContract ? ShadColors.gold : ShadColors.sent, borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)))),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
          ]),
        ),
      ),
    ]),
  );
}

Widget _managerCard(BuildContext context, ApiClient api, Map<String, dynamic> manager, void Function(Map<String, dynamic>) onTap) {
  final name = manager['name'] as String? ?? '';
  final email = manager['email'] as String? ?? '';
  final clientCount = int.tryParse(manager['managed_clients_count']?.toString() ?? '') ?? 0;
  final avatarUrl = manager['avatar_url'] as String?;
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: ShadColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ShadColors.cardBorder),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onTap(manager),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: ShadColors.cardBorder,
            backgroundImage: avatarUrl != null ? NetworkImage(api.resolveFileUrl(avatarUrl)) : null,
            child: avatarUrl == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 18, color: ShadColors.textSecondary)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
              const SizedBox(height: 2),
              Text(email, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ShadColors.sent.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$clientCount', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.sent, fontFamily: 'PlayfairDisplay')),
          ),
        ]),
      ),
    ),
  );
}

Widget _clientCard(BuildContext context, ApiClient api, Map<String, dynamic> client, void Function(Map<String, dynamic>) onTap) {
  final l10n = AppLocalizations.of(context)!;
  final ws = client['workspace'] as Map<String, dynamic>?;
  final wsStatus = ws?['status'] as String? ?? 'inactive';
  final wsActive = wsStatus == 'active';
  final name = client['company_name'] as String? ?? '';
  final person = client['contact_person'] as String? ?? '';
  final paymentStatus = client['payment_status'] as String?;
  final signedAt = client['signed_at'] as String?;

  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: ShadColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ShadColors.cardBorder),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onTap(client),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: ShadColors.crimson,
              backgroundImage: (client['avatar_url'] as String?)?.isNotEmpty == true
                  ? NetworkImage(api.resolveFileUrl(client['avatar_url']))
                  : null,
              child: (client['avatar_url'] as String?)?.isNotEmpty != true
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: ShadColors.gold, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Archivo'))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo'))),
                  const SizedBox(width: 6),
                  ClientTypeBadge(clientType: client['client_type'] as String?, compact: true),
                ]),
                const SizedBox(height: 2),
                Text(person, style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (wsActive ? ShadColors.success : ShadColors.textDisabled).withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                wsActive ? l10n.amStatusActive : l10n.amStatusInactive,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3,
                  color: wsActive ? ShadColors.success : ShadColors.textDisabled,
                  fontFamily: 'Archivo',
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _statusChip(Icons.description_outlined, signedAt != null ? l10n.amStatusContracted : l10n.amStatusNotContracted, signedAt != null ? ShadColors.success : ShadColors.textDisabled),
              _statusChip(Icons.payment, paymentStatus == 'approved' ? l10n.amStatusPaid : paymentStatus == 'pending' ? l10n.amStatusPending : '—',
                paymentStatus == 'approved' ? ShadColors.success : paymentStatus == 'pending' ? ShadColors.warning : ShadColors.textDisabled),
              _statusChip(wsActive ? Icons.check_circle : Icons.schedule, wsActive ? l10n.amStatusActive : l10n.amStatusPending,
                wsActive ? ShadColors.success : ShadColors.textDisabled),
            ],
          ),
        ]),
      ),
    ),
  );
}

Widget _statusChip(IconData icon, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500, fontFamily: 'Archivo')),
    ]),
  );
}

Widget _buildEmptyState(BuildContext context, ApiClient api, Future<void> Function() load) {
  final loc2 = AppLocalizations.of(context)!;
  final isSA = api.role == 'super_admin';
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(children: [
      const Icon(Icons.people_outline, size: 56, color: ShadColors.textDisabled),
      const SizedBox(height: 16),
      Text(loc2.noClients, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
      const SizedBox(height: 8),
      Text(loc2.noClientsSubtitle, style: TextStyle(fontSize: 14, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
      const SizedBox(height: 24),
      if (!isSA)
        ElevatedButton.icon(
          onPressed: () async { final created = await context.push<bool>('/am/clients/create'); if (created == true) load(); },
          icon: const Icon(Icons.person_add, size: 18),
          label: Text(loc2.createClient),
        ),
    ]),
  );
}
