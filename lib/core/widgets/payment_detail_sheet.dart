import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../theme.dart';

class PaymentDetailSheet extends StatelessWidget {
  final Map<String, dynamic> payment;
  final bool showPayButton;
  final VoidCallback? onPay;

  const PaymentDetailSheet({
    super.key,
    required this.payment,
    this.showPayButton = false,
    this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final amount = payment['amount']?.toString() ?? '0';
    final currency = payment['currency']?.toString() ?? 'SAR';
    final installmentLabel = payment['installment_label']?.toString();
    final dueDate = payment['due_date']?.toString();
    final status = payment['status']?.toString() ?? 'scheduled';
    final notes = payment['notes']?.toString();

    final statusInfo = _statusInfo(status, l10n);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: ShadColors.gold.withAlpha(60), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: ShadColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: ShadColors.gold.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ShadColors.gold.withAlpha(40), width: 0.5),
              ),
              child: Icon(statusInfo.$2, size: 18, color: ShadColors.gold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(installmentLabel ?? l10n.paymentDetail_title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
                  Text(statusInfo.$1,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusInfo.$3)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _row(l10n.paymentDetail_amount, '$amount $currency'),
          if (dueDate != null && dueDate.isNotEmpty) _row(l10n.paymentDetail_dueDate, _formatDate(dueDate)),
          if (notes != null && notes.isNotEmpty) _row(l10n.paymentDetail_notes, notes),
          if (showPayButton && status == 'scheduled') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.payment, size: 16),
                label: Text(l10n.paymentDetail_payNow),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShadColors.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.textPrimary), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  (String, IconData, Color) _statusInfo(String status, AppLocalizations l10n) {
    switch (status) {
      case 'scheduled':
        return (l10n.awaitingPayment, Icons.schedule, ShadColors.gold);
      case 'pending':
        return (l10n.paymentDetail_statusUnderReview, Icons.hourglass_empty, Colors.orange);
      case 'approved':
        return (l10n.paymentDetail_statusPaid, Icons.check_circle, ShadColors.success);
      case 'overdue':
        return (l10n.paymentDetail_statusOverdue, Icons.warning_amber, ShadColors.crimson);
      default:
        return (status, Icons.help_outline, Colors.grey);
    }
  }
}
