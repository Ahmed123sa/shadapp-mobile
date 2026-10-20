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
import '../../core/theme.dart';
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

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Lx.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet)),
      side: BorderSide(color: Lx.line2),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24, 10, 24, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                key: const ValueKey('lx-sheet-handle'),
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: Lx.line2, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(children: [
              Text(AppLocalizations.of(ctx)!.onboarding_requestPaymentTitle, style: Lx.display(ctx, size: 20)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 16),
            // Amount + (read-only) currency, underline fields like the mockup's .f2
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('payment-amount'),
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: Lx.text(ctx, size: 15),
                  decoration: InputDecoration(
                    labelText: '${AppLocalizations.of(ctx)!.onboarding_amountField} *',
                    hintText: '0.00',
                    border: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.line2)),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.line2)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 90,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(ctx)!.onboarding_currencyField,
                    border: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.line2)),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.line2)),
                  ),
                  child: Text(currency, key: const ValueKey('payment-currency'), style: Lx.text(ctx, size: 15)),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Text(AppLocalizations.of(ctx)!.onboarding_paymentMethodField, style: Lx.text(ctx, size: 12, color: Lx.muted)),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: selectedMethod,
              builder: (_, val, __) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in methodLabels.entries)
                    InkWell(
                      key: ValueKey('pay-method-${e.key}'),
                      borderRadius: BorderRadius.circular(Lx.rPill),
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
            const SizedBox(height: 18),

            // Proof files: drop box + one pill per attached file
            Text(AppLocalizations.of(ctx)!.onboarding_proofField, style: Lx.text(ctx, size: 12, color: Lx.muted)),
            const SizedBox(height: 8),
            InkWell(
              key: const ValueKey('payment-attach'),
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await pickProofFromGallery(multiple: true);
                if (picked.isNotEmpty) {
                  setSheetState(() { proofFiles.addAll(picked); });
                }
              },
              child: SizedBox(
                width: double.infinity,
                child: LuxeDashedBox(
                  child: Column(children: [
                    const LxIcon('up', size: 18, color: Lx.muted),
                    const SizedBox(height: 6),
                    Text(AppLocalizations.of(ctx)!.onboarding_attachFile, style: Lx.text(ctx, size: 12.5, color: Lx.muted)),
                  ]),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('payment-camera'),
                onPressed: () async {
                  final picked = await pickProofFromCamera();
                  if (picked != null) {
                    setSheetState(() { proofFiles.add(picked); });
                  }
                },
                icon: const LxIcon('plus', size: 16, color: Lx.ink2),
                label: Text(AppLocalizations.of(ctx)!.onboarding_takePhoto),
                style: TextButton.styleFrom(foregroundColor: Lx.ink2),
              ),
            ),
            if (proofFiles.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
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
                        InkWell(
                          key: ValueKey('payment-proof-remove-$i'),
                          onTap: () => setSheetState(() { proofFiles.removeAt(i); }),
                          child: const Icon(Icons.close, size: 14, color: Lx.muted),
                        ),
                      ]),
                    ),
                ],
              ),
            ValueListenableBuilder<String?>(
              valueListenable: errorNotifier,
              builder: (_, err, __) => err == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: const ValueKey('payment-sheet-error'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ShadColors.crimson.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ShadColors.crimson.withAlpha(50)),
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
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: uploading ? null : () => _submitPaymentOnboarding(
                    ctx, setSheetState, uploadingNotifier, errorNotifier, workspaceId,
                    amountCtrl, currency, selectedMethod.value, proofFiles,
                    paymentProvider, loadClientData,
                  ),
                  child: uploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(AppLocalizations.of(ctx)!.onboarding_sendPayment),
                ),
              ),
            ),
          ]),
        ),
      ),
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
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(l10n.onboarding_paymentSent)])));
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
