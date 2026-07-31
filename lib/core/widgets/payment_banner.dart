import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../theme.dart';

class PaymentBanner extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback? onTap;
  final bool showPayButton;

  const PaymentBanner({
    super.key,
    required this.payment,
    this.onTap,
    this.showPayButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final amount = payment['amount']?.toString() ?? '0';
    final currency = payment['currency']?.toString() ?? 'SAR';
    final dueDate = payment['due_date']?.toString();
    final installmentLabel = payment['installment_label']?.toString();
    final status = payment['status']?.toString() ?? 'scheduled';
    final isDirectRequest = dueDate == null || dueDate.isEmpty;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String title;
    String? subtitle;

    if (isDirectRequest) {
      bgColor = const Color(0x14D4AF37);
      borderColor = ShadColors.gold;
      textColor = ShadColors.gold;
      icon = Icons.request_quote;
      title = l10n.paymentRequestTitle(amount, currency);
    } else if (status == 'overdue') {
      bgColor = const Color(0x14C62828);
      borderColor = ShadColors.crimson;
      textColor = ShadColors.crimson;
      icon = Icons.warning_amber;
      title = l10n.overduePaymentTitle(amount, currency);
      subtitle = installmentLabel ?? _formatDate(dueDate, l10n);
    } else if (status == 'scheduled') {
      bgColor = const Color(0x14D4AF37);
      borderColor = ShadColors.gold;
      textColor = ShadColors.gold;
      icon = Icons.schedule_send;
      title = l10n.scheduledPaymentTitle(amount, currency);
      subtitle = installmentLabel ?? _formatDate(dueDate, l10n);
    } else if (status == 'pending') {
      bgColor = const Color(0x14FF9800);
      borderColor = Colors.orange;
      textColor = Colors.orange;
      icon = Icons.hourglass_empty;
      title = l10n.pendingPaymentTitle(amount, currency);
      subtitle = installmentLabel;
    } else {
      bgColor = const Color(0x144CAF50);
      borderColor = ShadColors.success;
      textColor = ShadColors.success;
      icon = Icons.check_circle;
      title = l10n.paidPaymentTitle(amount, currency);
      subtitle = installmentLabel;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor.withAlpha(120), width: 0.5),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(subtitle, style: TextStyle(fontSize: 10, color: textColor.withAlpha(180))),
            ],
          )),
          if (!isDirectRequest && !showPayButton)
            Icon(Icons.chevron_left, size: 16, color: textColor.withAlpha(120)),
        ]),
      ),
    );
  }

  String _formatDate(String dateStr, AppLocalizations l10n) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = dt.difference(DateTime(now.year, now.month, now.day));
      if (diff.inDays == 0) return l10n.today;
      if (diff.inDays == 1) return l10n.tomorrow;
      if (diff.inDays < 0) return l10n.daysLate(-diff.inDays);
      return l10n.inDays(diff.inDays);
    } catch (_) {
      return dateStr;
    }
  }
}
