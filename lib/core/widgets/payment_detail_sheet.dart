import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../luxe/tokens.dart';
import '../theme.dart';
import 'luxe/luxe_widgets.dart';

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
    // payments-fixes-2-plan.md ت٢ — rejection_reason and notes are
    // different things; stop falling back to notes as the reason.
    final rejectionReason = payment['rejection_reason']?.toString();

    final statusInfo = _statusInfo(status, l10n);

    final amt = num.tryParse(amount);
    final dot = status == 'approved'
        ? LxStatus.ok
        : status == 'overdue' || status == 'rejected'
            ? LxStatus.bad
            : (status == 'scheduled' || status == 'pending')
                ? LxStatus.wait
                : LxStatus.off;

    return Builder(builder: (context) => Container(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 12, 22, 26),
      decoration: const BoxDecoration(
        color: Lx.sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet)),
        border: Border(top: BorderSide(color: Lx.line2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              key: const ValueKey('lx-sheet-handle'),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Lx.line2, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Text(installmentLabel ?? l10n.paymentDetail_title, style: Lx.display(context, size: 22)),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            LuxeStatusDot(status: dot),
            const SizedBox(width: 7),
            Text(statusInfo.$1, style: Lx.text(context, size: 12, color: Lx.ink2)),
          ]),
          const SizedBox(height: 14),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: amt != null ? lxFormatMoney(amt) : amount, style: Lx.display(context, size: 28)),
              TextSpan(text: ' $currency', style: Lx.text(context, size: 12, color: Lx.muted)),
            ])),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: Lx.line),
          if (dueDate != null && dueDate.isNotEmpty) _row(context, l10n.paymentDetail_dueDate, _formatDate(dueDate)),
          if (notes != null && notes.isNotEmpty) _row(context, l10n.paymentDetail_notes, notes),
          if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty)
            _row(context, l10n.paymentsRejectionReason, rejectionReason),
          if (showPayButton && status == 'scheduled') ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.payment, size: 16),
                label: Text(l10n.paymentDetail_payNow),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Lx.crimson,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: Lx.text(context, size: 14, weight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ],
      ),
    ));
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Lx.text(context, size: 12.5, color: Lx.muted)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, style: Lx.text(context, size: 12.5), textAlign: TextAlign.end)),
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
