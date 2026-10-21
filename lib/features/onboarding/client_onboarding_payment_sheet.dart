// Extracted from client_onboarding_screen.dart as part of بند ٨ (file splitting).
// The "request payment" bottom sheet + its submit handler. The outer function
// still builds methodLabels using the page's own `context` (matching the
// original, which computed them before calling showModalBottomSheet), while
// everything inside the sheet builder keeps using the sheet's own `ctx`.
//
// `currency` is no longer a free choice — it's the caller-supplied contract
// currency, shown read-only (plans/payment-currency-plan.md ح4); the backend
// enforces this regardless via PaymentController::resolveCurrency().

import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/helpers/proof_image_picker.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../providers/payment_provider.dart';

void showOnboardingPaymentSheet({
  required BuildContext context,
  required double suggestedAmount,
  required int? workspaceId,
  // The payment's currency is always the linked contract's — enforced
  // server-side by PaymentController::resolveCurrency() regardless of what
  // gets submitted (plans/payment-currency-plan.md). This used to be a free
  // 9-currency dropdown defaulting to SAR; it's now a fixed value passed in
  // by buildPaymentStage (derived from the workspace's contract), displayed
  // as read-only text rather than offered as a choice.
  required String currency,
  required PaymentProvider paymentProvider,
  required Future<void> Function() loadClientData,
}) {
  final methodLabels = {
    'bank_transfer': AppLocalizations.of(context)!.payments_methodBankTransfer,
    'swift': AppLocalizations.of(context)!.payments_methodSwift,
    'corporate_account': AppLocalizations.of(context)!.payments_methodCorporateAccount,
    'instapay': AppLocalizations.of(context)!.payments_methodInstapay,
    'vodafone_cash': AppLocalizations.of(context)!.payments_methodVodafoneCash,
    'mobile_wallet': AppLocalizations.of(context)!.payments_methodMobileWallet,
    'cheque': AppLocalizations.of(context)!.payments_methodCheque,
  };

  final amountCtrl = TextEditingController(text: suggestedAmount > 0 ? suggestedAmount.toStringAsFixed(0) : '');
  final selectedMethod = ValueNotifier<String>('bank_transfer');
  List<Map<String, dynamic>> proofFiles = [];
  final uploadingNotifier = ValueNotifier<bool>(false);
  final errorNotifier = ValueNotifier<String?>(null);

  // Mockup `paySheet`: grab, serif "Send a payment", amount + read-only
  // currency (.f2), method chips (.chip2), receipt drop box + one .thumb per
  // file, then the full-width primary button. Camera stays as an extra link.
  showLuxeSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final l10n = AppLocalizations.of(ctx)!;
        Widget label(String t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(t, style: Lx.text(ctx, size: 11, color: Lx.muted)),
            );
        const underline = UnderlineInputBorder(borderSide: BorderSide(color: Lx.line2));
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.onboardingSendPaymentTitle, style: Lx.display(ctx, size: 22)),
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                label(l10n.onboarding_amountField),
                TextField(
                  key: const ValueKey('payment-amount'),
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: Lx.display(ctx, size: 18),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: '0',
                    hintStyle: Lx.display(ctx, size: 18, color: Lx.faint),
                    contentPadding: const EdgeInsets.only(bottom: 8),
                    border: underline,
                    enabledBorder: underline,
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.muted)),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 90,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                label(l10n.onboarding_currencyField),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                  child: Text(currency, key: const ValueKey('payment-currency'), style: Lx.text(ctx, size: 15, color: Lx.ink2)),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          label(l10n.onboarding_paymentMethodField),
          ValueListenableBuilder<String>(
            valueListenable: selectedMethod,
            builder: (_, val, __) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in methodLabels.entries)
                  GestureDetector(
                    key: ValueKey('pay-method-${e.key}'),
                    onTap: () => selectedMethod.value = e.key,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        color: val == e.key ? const Color(0x33941414) : null,
                        borderRadius: BorderRadius.circular(Lx.rPill),
                        border: Border.all(color: val == e.key ? const Color(0x80941414) : Lx.line2),
                      ),
                      child: Text(e.value, style: Lx.text(ctx, size: 12, color: val == e.key ? Lx.ink : Lx.ink2)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          label(l10n.onboarding_proofField),
          GestureDetector(
            key: const ValueKey('payment-attach'),
            onTap: () async {
              final picked = await pickProofFromGallery(multiple: true);
              if (picked.isNotEmpty) setSheetState(() => proofFiles.addAll(picked));
            },
            child: SizedBox(
              width: double.infinity,
              child: LuxeDashedBox(
                child: Column(children: [
                  const LxIcon('up', size: 18, color: Lx.muted),
                  const SizedBox(height: 6),
                  Text(l10n.onboardingDropTitle, style: Lx.text(ctx, size: 12.5, color: Lx.ink2)),
                  const SizedBox(height: 4),
                  Text(l10n.onboardingDropHint, style: Lx.text(ctx, size: 11, color: Lx.faint)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (var i = 0; i < proofFiles.length; i++)
              Container(
                key: ValueKey('payment-proof-$i'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Lx.line2)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const LxIcon('doc', size: 14, color: Lx.ink2),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text('${proofFiles[i]['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(ctx, size: 12)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: ValueKey('payment-proof-remove-$i'),
                    onTap: () => setSheetState(() => proofFiles.removeAt(i)),
                    child: Text('×', style: Lx.text(ctx, size: 14, color: Lx.muted)),
                  ),
                ]),
              ),
            GestureDetector(
              key: const ValueKey('payment-camera'),
              onTap: () async {
                final picked = await pickProofFromCamera();
                if (picked != null) setSheetState(() => proofFiles.add(picked));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const LxIcon('plus', size: 14, color: Lx.muted),
                  const SizedBox(width: 6),
                  Text(l10n.onboarding_takePhoto, style: Lx.text(ctx, size: 12, color: Lx.muted)),
                ]),
              ),
            ),
          ]),
          ValueListenableBuilder<String?>(
            valueListenable: errorNotifier,
            builder: (_, err, __) => err == null
                ? const SizedBox.shrink()
                : Container(
                    key: const ValueKey('payment-sheet-error'),
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x1F941414),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x33941414)),
                    ),
                    child: Text(err, style: Lx.text(ctx, size: 12.5, color: Lx.danger)),
                  ),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<bool>(
            valueListenable: uploadingNotifier,
            builder: (_, uploading, __) => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Lx.crimson,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF2A2827),
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                onPressed: uploading ? null : () => _submitPaymentOnboarding(
                  ctx, setSheetState, uploadingNotifier, errorNotifier, workspaceId,
                  amountCtrl, currency, selectedMethod.value, proofFiles,
                  paymentProvider, loadClientData,
                ),
                child: uploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.onboarding_sendPayment),
              ),
            ),
          ),
        ]);
      },
    ),
  );
}

Future<void> _submitPaymentOnboarding(
  BuildContext ctx,
  void Function(void Function()) setSheetState,
  ValueNotifier<bool> uploadingNotifier,
  ValueNotifier<String?> errorNotifier,
  int? workspaceId,
  TextEditingController amountCtrl,
  String currency,
  String methodType,
  List<Map<String, dynamic>> proofFiles,
  PaymentProvider paymentProvider,
  Future<void> Function() loadClientData,
) async {
  // Captured once, before any `await`: looking it up again inside the catch
  // blocks below (after the request has actually gone out) is exactly the
  // `use_build_context_synchronously` pattern flutter analyze flags, since it
  // can't tell a caught exception means ctx is still safe to read from.
  final l10n = AppLocalizations.of(ctx)!;
  errorNotifier.value = null;
  final amount = double.tryParse(amountCtrl.text);
  if (amount == null || amount <= 0) {
    errorNotifier.value = l10n.onboarding_enterValidAmount;
    if (ctx.mounted) setSheetState(() {});
    return;
  }
  if (workspaceId == null) {
    errorNotifier.value = l10n.onboarding_workspaceUnavailable;
    if (ctx.mounted) setSheetState(() {});
    return;
  }
  uploadingNotifier.value = true;
  setSheetState(() {});
  try {
    final fields = <String, dynamic>{
      'amount': amount,
      'currency': currency,
      'method_type': methodType,
    };

    final nativeFiles = proofFiles.where((pf) => pf['file'] != null).map((pf) => pf['file'] as File).toList();
    final bytesFiles = proofFiles.where((pf) => pf['bytes'] != null).map((pf) => pf['bytes'] as Uint8List).toList();
    final bytesNames = proofFiles.where((pf) => pf['bytes'] != null).map((pf) => pf['name'] as String? ?? 'file.jpg').toList();

    await paymentProvider.createPayment(
      workspaceId,
      fields,
      files: nativeFiles.isNotEmpty ? nativeFiles : null,
      bytesFiles: bytesFiles.isNotEmpty ? bytesFiles : null,
      bytesNames: bytesFiles.isNotEmpty ? bytesNames : null,
    );

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Row(children: [const LxIcon('check', size: 18, color: Lx.ok), const SizedBox(width: 8), Flexible(child: Text(l10n.onboarding_paymentSent))])));
      Navigator.pop(ctx);
    }
    loadClientData();
  } on ValidationException catch (e) {
    AppLog.error('client_onboarding_payment_sheet._submitPaymentOnboarding', e);
    errorNotifier.value = e.message;
  } on ConnectionException catch (e) {
    AppLog.error('client_onboarding_payment_sheet._submitPaymentOnboarding', e);
    errorNotifier.value = l10n.connectionFailedMessage;
  } on ServerException catch (e) {
    AppLog.error('client_onboarding_payment_sheet._submitPaymentOnboarding', e);
    errorNotifier.value = e.message.isNotEmpty ? e.message : l10n.serverErrorMessage;
  } catch (e, s) {
    AppLog.error('client_onboarding_payment_sheet._submitPaymentOnboarding', e, s);
    errorNotifier.value = l10n.onboarding_paymentFailed;
  }
  uploadingNotifier.value = false;
  if (ctx.mounted) setSheetState(() {});
}
