import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../luxe/tokens.dart';

/// Mockup `.tagr`: a small outlined pill (9.5px, muted, 1px line-2 border).
class ClientTypeBadge extends StatelessWidget {
  final String? clientType;
  final bool compact;

  const ClientTypeBadge({super.key, this.clientType, this.compact = false});

  bool get _isBusiness => clientType == 'business';

  @override
  Widget build(BuildContext context) {
    if (clientType == null || clientType!.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final label = _isBusiness ? l10n.clientTypeCompany : l10n.clientTypeIndividual;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lx.rPill),
        border: Border.all(color: Lx.line2),
      ),
      child: Text(label, style: Lx.text(context, size: 9.5, color: Lx.muted)),
    );
  }
}
