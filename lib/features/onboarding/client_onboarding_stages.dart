// Extracted from client_onboarding_screen.dart as part of بند ٨ (file splitting).
// Pure stage-screen widgets: the parent screen still owns all state (client,
// workspace, taxSettings) and passes it in, and still owns every side-effecting
// action (loading data, showing the contract modal, responding to a contract,
// opening the payment sheet) via callbacks — these functions only build UI.

import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/luxe/tokens.dart';
import '../../core/theme.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';

Widget _stageIcon(IconData icon, Color color) => Container(
      key: const ValueKey('stage-icon'),
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Icon(icon, size: 32, color: color),
    );

ButtonStyle _primaryStyle() => ElevatedButton.styleFrom(
      backgroundColor: Lx.crimson,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      disabledBackgroundColor: ShadColors.cardBorder,
      disabledForegroundColor: ShadColors.textDisabled,
    );

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
        _stageIcon(Icons.auto_fix_high, ShadColors.gold),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)!.onboarding_welcomeName(client?['contact_person'] ?? ''),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: Lx.serif),
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
            style: _primaryStyle(),
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
  /// Names of the stages still ahead ("What's next"). Empty hides the list.
  List<String> nextSteps = const [],
  /// Heading for [nextSteps]; the screen passes its localized string.
  String? nextStepsTitle,
}) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const SizedBox(height: 24),
      LuxeCard(
        key: const ValueKey('waiting-card'),
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          _stageIcon(icon, iconColor),
          const SizedBox(height: 20),
          Text(title, style: Lx.display(context, size: 20), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(subtitle, style: Lx.text(context, size: 13.5, color: Lx.ink2, height: 1.6), textAlign: TextAlign.center),
          const SizedBox(height: 22),
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ]),
      ),
      if (nextSteps.isNotEmpty) ...[
        LuxeSectionHeader(title: nextStepsTitle ?? ''),
        LuxeCard(
          key: const ValueKey('next-steps-card'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < nextSteps.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == nextSteps.length - 1 ? 0 : 10),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Lx.line2)),
                    child: Text('${i + 1}', style: Lx.text(context, size: 11, color: Lx.muted)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(nextSteps[i], style: Lx.text(context, size: 13, color: Lx.ink2))),
                ]),
              ),
          ]),
        ),
      ],
    ]),
  );
}

Widget buildContractReviewStage({
  required BuildContext context,
  required Map<String, dynamic>? workspace,
  required void Function(Map) onPreviewContract,
  required void Function(String) onRespond,
}) {
  final l10n = AppLocalizations.of(context)!;
  final ws = workspace;
  final contracts = ws != null ? safeList(ws['contracts']) : [];
  final sentContract = contracts.firstWhere(
    (c) => c is Map && c['status'] == 'sent',
    orElse: () => contracts.isNotEmpty ? contracts.first : null,
  ) as Map?;

  final requiredDocs = sentContract != null ? safeList(sentContract['required_documents']) : [];
  final hasMissingDocs = requiredDocs.isNotEmpty && requiredDocs.any((d) {
    if (d is! Map) return false;
    final files = d['files'] as List<dynamic>?;
    if (files != null && files.isNotEmpty) {
      return !files.any((f) => f is Map && f['status'] != 'rejected');
    }
    return d['status'] != 'approved' && d['status'] != 'pending';
  });

  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const SizedBox(height: 40),
        _stageIcon(Icons.description, Lx.ok),
        const SizedBox(height: 24),
        Text(
          l10n.onboarding_contractReceived,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: Lx.serif),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.onboarding_reviewContractPrompt,
          style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              if (sentContract != null) {
                onPreviewContract(sentContract);
              }
            },
            icon: const Icon(Icons.visibility, size: 20),
            label: Text(l10n.onboarding_previewContract),
            style: OutlinedButton.styleFrom(
              foregroundColor: ShadColors.gold,
              side: const BorderSide(color: ShadColors.gold),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (hasMissingDocs) ...[
          const SizedBox(height: 12),
          Text(
            l10n.contractUploadRequiredFirst,
            style: const TextStyle(fontSize: 12, color: ShadColors.warning, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: hasMissingDocs ? null : () => onRespond('approved'),
            icon: const Icon(Icons.thumb_up, size: 20),
            label: Text(l10n.onboarding_approve),
            style: _primaryStyle(),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => onRespond('edit_requested'),
          icon: const Icon(Icons.edit_note, size: 18),
          label: Text(l10n.onboarding_requestEdit),
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
  required void Function(double suggestedAmount, int? workspaceId, String currency) onSendPayment,
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
  Map<String, dynamic>? lastRejectedPayment;
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
      if (p is Map) {
        if (p['status'] == 'approved') {
          paidAmount += double.tryParse((p['amount'] ?? '0').toString()) ?? 0.0;
        } else if (p['status'] == 'rejected') {
          lastRejectedPayment = p.cast<String, dynamic>();
        }
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
        if (lastRejectedPayment != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: Lx.cardApGradient,
              borderRadius: BorderRadius.circular(Lx.rCard),
              border: Border.all(color: Lx.cardApBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Lx.crimsonInk, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.onboarding_paymentRejectedTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Lx.crimsonInk,
                        ),
                      ),
                    ),
                  ],
                ),
                // payments-fixes-2-plan.md ت٢ — rejection_reason (why it
                // was rejected) and notes (the manager's note from
                // requesting it) are different things; falling back to
                // notes whenever rejection_reason was empty mislabeled
                // that note as a rejection reason.
                if ((lastRejectedPayment['rejection_reason'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${AppLocalizations.of(context)!.onboarding_paymentRejectedReason}: ${lastRejectedPayment['rejection_reason']}',
                    style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context)!.onboarding_paymentRejectedRetry,
                  style: TextStyle(fontSize: 11, color: ShadColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _stageIcon(Icons.payment, Lx.wait),
        const SizedBox(height: 20),
        Text(
          AppLocalizations.of(context)!.onboarding_completePayment,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: Lx.serif),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.onboarding_confirmPaymentToActivate,
          style: TextStyle(fontSize: 13, color: ShadColors.textSecondary),
        ),
        const SizedBox(height: 24),

        // Progress card
        LuxeCard(
          key: const ValueKey('payment-progress-card'),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Text('${paidAmount.toStringAsFixed(2)} $currency', style: Lx.display(context, size: 28)),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.payments_remainingSummary(currency, remaining.toStringAsFixed(2), grandTotal.toStringAsFixed(2)), style: Lx.text(context, size: 11, color: Lx.muted)),
            if (taxAmount > 0) ...[
              const SizedBox(height: 4),
              Text(AppLocalizations.of(context)!.payments_taxSummary(taxAmount.toStringAsFixed(2), currency, taxPercentage, totalAmount.toStringAsFixed(2)), style: Lx.text(context, size: 10, color: Lx.muted)),
            ],
            const SizedBox(height: 14),
            LuxeProgressSplit(fraction: progress),
          ]),
        ),
        // Contract details
        if (startDate != null || endDate != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: Lx.cardGradient,
              borderRadius: BorderRadius.circular(Lx.rCard),
              border: Border.all(color: Lx.cardBorder),
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
            onPressed: () => onSendPayment(remaining > 0 ? remaining : grandTotal, ws?['id'], currency),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: Text(AppLocalizations.of(context)!.onboarding_sendPayment),
            style: _primaryStyle(),
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
      gradient: Lx.cardGradient,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Lx.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: valueColor, fontFamily: Lx.serif)),
    ]),
  );
}
