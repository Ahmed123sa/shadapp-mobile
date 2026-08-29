// Extracted from client_onboarding_screen.dart as part of بند ٨ (file splitting).
// Pure stage-screen widgets: the parent screen still owns all state (client,
// workspace, taxSettings) and passes it in, and still owns every side-effecting
// action (loading data, showing the contract modal, responding to a contract,
// opening the payment sheet) via callbacks — these functions only build UI.

import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

Widget buildSignatureStage({
  required BuildContext context,
  required Map<String, dynamic>? client,
  required Future<void> Function() onSign,
}) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: ShadColors.gold.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.auto_fix_high, size: 36, color: ShadColors.gold),
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)!.onboarding_welcomeName(client?['contact_person'] ?? ''),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context)!.onboarding_addSignaturePrompt,
          style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onSign,
            icon: const Icon(Icons.draw, size: 20),
            label: Text(AppLocalizations.of(context)!.onboarding_signNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: ShadColors.crimson,
              foregroundColor: ShadColors.textOnCrimson,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildWaitingStage({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 36, color: iconColor),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const SizedBox(
          width: 40, height: 40,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 32),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.headset_mic, size: 18),
          label: Text(AppLocalizations.of(context)!.onboarding_contactSupport),
          style: TextButton.styleFrom(foregroundColor: ShadColors.textSecondary),
        ),
      ]),
    ),
  );
}

Widget buildContractReviewStage({
  required BuildContext context,
  required Map<String, dynamic>? workspace,
  required void Function(Map) onPreviewContract,
  required void Function(String) onRespond,
}) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: ShadColors.approved.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.description, size: 36, color: ShadColors.approved),
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)!.onboarding_contractReceived,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context)!.onboarding_reviewContractPrompt,
          style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final ws = workspace;
              if (ws != null) {
                final contracts = safeList(ws['contracts']);
                if (contracts.isNotEmpty) {
                  final c = contracts.first as Map;
                  onPreviewContract(c);
                }
              }
            },
            icon: const Icon(Icons.visibility, size: 20),
            label: Text(AppLocalizations.of(context)!.onboarding_previewContract),
            style: OutlinedButton.styleFrom(
              foregroundColor: ShadColors.gold,
              side: const BorderSide(color: ShadColors.gold),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => onRespond('approved'),
            icon: const Icon(Icons.thumb_up, size: 20),
            label: Text(AppLocalizations.of(context)!.onboarding_approve),
            style: ElevatedButton.styleFrom(
              backgroundColor: ShadColors.crimson,
              foregroundColor: ShadColors.textOnCrimson,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => onRespond('edit_requested'),
          icon: const Icon(Icons.edit_note, size: 18),
          label: Text(AppLocalizations.of(context)!.onboarding_requestEdit),
          style: TextButton.styleFrom(foregroundColor: ShadColors.textSecondary),
        ),
      ],
    ),
  );
}

Widget buildPaymentStage({
  required BuildContext context,
  required Map<String, dynamic>? workspace,
  required Map<String, dynamic>? client,
  required Map<String, dynamic>? taxSettings,
  required void Function(double suggestedAmount, int? workspaceId) onSendPayment,
}) {
  final ws = workspace;
  double totalAmount = 0;
  double paidAmount = 0;
  double taxAmount = 0;
  double taxPercentage = 0;
  String currency = 'SAR';
  String? startDate;
  String? endDate;
  final isBusiness = (client?['client_type'] ?? '') == 'business';
  if (isBusiness && taxSettings != null) {
    taxPercentage = num.tryParse(taxSettings['corporate_tax_percentage']?['value']?.toString() ?? '')?.toDouble() ?? 0;
  }
  if (ws != null) {
    final contracts = safeList(ws['contracts']);
    for (final c in contracts) {
      if (c is Map) {
        final cv = double.tryParse((c['value'] ?? '0').toString()) ?? 0.0;
        totalAmount += cv;
        currency = (c['currency'] as String?) ?? currency;
        if (c['start_date'] != null) startDate = (c['start_date'] as String).split('T')[0];
        if (c['end_date'] != null) endDate = (c['end_date'] as String).split('T')[0];
      }
    }
    final payments = safeList(ws['payments']);
    for (final p in payments) {
      if (p is Map && p['status'] == 'approved') {
        paidAmount += double.tryParse((p['amount'] ?? '0').toString()) ?? 0.0;
      }
    }
  }
  if (isBusiness && taxPercentage > 0) {
    taxAmount = totalAmount * taxPercentage / 100;
  }
  final grandTotal = totalAmount + taxAmount;
  final remaining = grandTotal - paidAmount;
  final progress = grandTotal > 0 ? (paidAmount / grandTotal).clamp(0.0, 1.0) : 0.0;

  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: ShadColors.warning.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.payment, size: 36, color: ShadColors.warning),
        ),
        const SizedBox(height: 20),
        Text(
          AppLocalizations.of(context)!.onboarding_completePayment,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.onboarding_confirmPaymentToActivate,
          style: TextStyle(fontSize: 13, color: ShadColors.textSecondary),
        ),
        const SizedBox(height: 24),

        // Progress card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ShadColors.surfaceDarker,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ShadColors.cardBorder),
          ),
          child: Column(children: [
            Text('${paidAmount.toStringAsFixed(2)} $currency', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.payments_remainingSummary(currency, remaining.toStringAsFixed(2), grandTotal.toStringAsFixed(2)), style: TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
            if (taxAmount > 0) ...[
              const SizedBox(height: 4),
              Text(AppLocalizations.of(context)!.payments_taxSummary(taxAmount.toStringAsFixed(2), currency, taxPercentage, totalAmount.toStringAsFixed(2)), style: TextStyle(fontSize: 10, color: ShadColors.textDisabled)),
            ],
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: ShadColors.cardBorder,
                valueColor: const AlwaysStoppedAnimation(ShadColors.gold),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Contract details
        if (startDate != null || endDate != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ShadColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ShadColors.cardBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLocalizations.of(context)!.onboarding_contractDetails, style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
              const SizedBox(height: 10),
              if (startDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.calendar_today, size: 14, color: ShadColors.textDisabled),
                    const SizedBox(width: 8),
                    Text('${AppLocalizations.of(context)!.onboarding_startDate}: $startDate', style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary)),
                  ]),
                ),
              if (endDate != null)
                Row(children: [
                  Icon(Icons.calendar_today, size: 14, color: ShadColors.textDisabled),
                  const SizedBox(width: 8),
                  Text('${AppLocalizations.of(context)!.onboarding_endDate}: $endDate', style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary)),
                ]),
            ]),
          ),
        const SizedBox(height: 24),

        // Payment info cards
        Row(children: [
          Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_amount, totalAmount.toStringAsFixed(0), ShadColors.gold)),
          const SizedBox(width: 12),
          Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_currency, currency, ShadColors.textPrimary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (taxAmount > 0)
            Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_tax, taxAmount.toStringAsFixed(0), ShadColors.error)),
          if (taxAmount > 0) const SizedBox(width: 12),
          Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_total, grandTotal.toStringAsFixed(0), ShadColors.gold)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_paidAmount, paidAmount.toStringAsFixed(0), ShadColors.success)),
          const SizedBox(width: 12),
          Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_remainingAmount2, remaining.toStringAsFixed(0), ShadColors.warning)),
        ]),
        const SizedBox(height: 28),

        // CTA button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => onSendPayment(remaining > 0 ? remaining : grandTotal, ws?['id']),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: Text(AppLocalizations.of(context)!.onboarding_sendPayment),
            style: ElevatedButton.styleFrom(
              backgroundColor: ShadColors.crimson,
              foregroundColor: ShadColors.textOnCrimson,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _paymentInfoTile(String label, String value, Color valueColor) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: ShadColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ShadColors.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: valueColor, fontFamily: 'PlayfairDisplay')),
    ]),
  );
}
