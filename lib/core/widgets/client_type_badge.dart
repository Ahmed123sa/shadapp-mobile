import 'package:flutter/material.dart';
import '../theme.dart';

class ClientTypeBadge extends StatelessWidget {
  final String? clientType;
  final bool compact;

  const ClientTypeBadge({super.key, this.clientType, this.compact = false});

  bool get _isBusiness => clientType == 'business';

  @override
  Widget build(BuildContext context) {
    if (clientType == null || clientType!.isEmpty) return const SizedBox.shrink();

    final label = _isBusiness ? 'شركة' : 'فردي';
    final bg = _isBusiness
        ? ShadColors.gold.withAlpha(38)
        : ShadColors.textDisabled.withAlpha(38);
    final fg = _isBusiness ? ShadColors.gold : ShadColors.textSecondary;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_isBusiness ? Icons.business : Icons.person, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
