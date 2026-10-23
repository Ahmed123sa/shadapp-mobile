import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../luxe/tokens.dart';

/// Minimum length of a payment rejection reason (matches the backend rule).
const int kMinRejectReasonLength = 5;

/// Asks for the reason a payment is rejected. The reason is mandatory: the
/// confirm button stays disabled until it has at least
/// [kMinRejectReasonLength] characters. Returns the trimmed reason, or null
/// when the reviewer cancelled.
Future<String?> showRejectReasonDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final ok = controller.text.trim().length >= kMinRejectReasonLength;
        return AlertDialog(
          title: Text(l10n.paymentsRejectPayment),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.paymentsRejectConfirmMsg),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('reject-reason-field'),
                controller: controller,
                maxLines: 2,
                autofocus: true,
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(
                  labelText: l10n.paymentsRejectionReasonOptional,
                  hintText: l10n.paymentsRejectionReasonHint,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(
              key: const ValueKey('reject-reason-confirm'),
              onPressed: ok ? () => Navigator.pop(ctx, controller.text.trim()) : null,
              style: ElevatedButton.styleFrom(backgroundColor: Lx.danger),
              child: Text(l10n.reject),
            ),
          ],
        );
      },
    ),
  );
}
