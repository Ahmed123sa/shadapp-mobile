import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../luxe/tokens.dart';
import '../theme.dart';
import 'client_type_badge.dart';
import 'luxe/luxe_widgets.dart';

/// Staff client row in the Luxe look (mockup `pClients` card).
class ClientCard extends StatelessWidget {
  final String companyName;
  final String contactPerson;
  final String? workspaceStatus;
  final String? contractStatus;
  final String? clientType;
  final VoidCallback? onTap;

  const ClientCard({
    super.key,
    required this.companyName,
    required this.contactPerson,
    this.workspaceStatus,
    this.contractStatus,
    this.clientType,
    this.onTap,
  });

  LxStatus _dot(String status) => (status == 'active' || status == 'approved' || status == 'completed' || status == 'company_approved')
      ? LxStatus.ok
      : (status == 'rejected' || status == 'cancelled' || status == 'overdue')
          ? LxStatus.bad
          : LxStatus.wait;

  Widget _status(BuildContext context, String status) {
    final label = statusLabels(AppLocalizations.of(context)!)[status] ?? status;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      LuxeStatusDot(status: _dot(status)),
      const SizedBox(width: 7),
      Text(label, style: Lx.text(context, size: 12, color: Lx.ink2)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return LuxeCard(
      onTap: onTap,
      child: Row(children: [
        LuxeAvatar(initial: companyName.isEmpty ? '?' : companyName[0]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(companyName, style: Lx.text(context, size: 16))),
              if (clientType != null) ...[
                const SizedBox(width: 6),
                ClientTypeBadge(clientType: clientType, compact: true),
              ],
            ]),
            const SizedBox(height: 2),
            Text(contactPerson, style: Lx.text(context, size: 12.5, color: Lx.muted)),
            if (workspaceStatus != null || contractStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 16, runSpacing: 4, children: [
                  if (workspaceStatus != null) _status(context, workspaceStatus!),
                  if (contractStatus != null) _status(context, contractStatus!),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
