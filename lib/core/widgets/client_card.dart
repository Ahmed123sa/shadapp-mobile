import 'package:flutter/material.dart';
import '../theme.dart';
import 'client_type_badge.dart';
import 'status_badge.dart';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: ShadColors.primaryLight,
                child: Text(companyName[0], style: TextStyle(color: ShadColors.textOnCrimson, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(companyName, style: ShadTypography.cardTitle)),
                      if (clientType != null) ...[
                        const SizedBox(width: 6),
                        ClientTypeBadge(clientType: clientType, compact: true),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(contactPerson, style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
                  ],
                ),
              ),
              if (workspaceStatus != null) ...[
                const SizedBox(width: 8),
                StatusBadge(status: workspaceStatus!, fontSize: 10),
              ],
              if (contractStatus != null) ...[
                const SizedBox(width: 4),
                StatusBadge(status: contractStatus!, fontSize: 10),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left, color: ShadColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}
