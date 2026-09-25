// Extracted from client_onboarding_screen.dart as part of بند ٨ (file splitting).
// The "request payment" bottom sheet + its submit handler, preserved byte-for-byte
// behaviorally: the outer function still builds methodLabels/currencyLabels using
// the page's own `context` (matching the original, which computed them before
// calling showModalBottomSheet), while everything inside the sheet builder keeps
// using the sheet's own `ctx`.

import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/helpers/proof_image_picker.dart';
import '../../core/theme.dart';
import '../../providers/payment_provider.dart';

void showOnboardingPaymentSheet({
  required BuildContext context,
  required double suggestedAmount,
  required int? workspaceId,
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
  };

  const currencies = ['SAR', 'USD', 'EUR', 'AED', 'EGP', 'KWD', 'QAR', 'BHD', 'OMR'];
  final currencyLabels = {
    'SAR': AppLocalizations.of(context)!.currency_sar, 'USD': AppLocalizations.of(context)!.currency_usd, 'EUR': AppLocalizations.of(context)!.currency_eur,
    'AED': AppLocalizations.of(context)!.currency_aed, 'EGP': AppLocalizations.of(context)!.currency_egp, 'KWD': AppLocalizations.of(context)!.currency_kwd,
    'QAR': AppLocalizations.of(context)!.currency_qar, 'BHD': AppLocalizations.of(context)!.currency_bhd, 'OMR': AppLocalizations.of(context)!.currency_omr,
  };

  final amountCtrl = TextEditingController(text: suggestedAmount > 0 ? suggestedAmount.toStringAsFixed(0) : '');
  final selectedCurrency = ValueNotifier<String>('SAR');
  final selectedMethod = ValueNotifier<String>('bank_transfer');
  List<Map<String, dynamic>> proofFiles = [];
  final uploadingNotifier = ValueNotifier<bool>(false);
  final errorNotifier = ValueNotifier<String?>(null);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(AppLocalizations.of(ctx)!.onboarding_requestPaymentTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: selectedCurrency,
              builder: (_, cur, __) => TextField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: '${AppLocalizations.of(ctx)!.onboarding_amountField} *', hintText: '0.00', prefixText: '$cur '),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: selectedCurrency,
              builder: (_, cur, __) => DropdownButtonFormField<String>(
                initialValue: cur,
                decoration: InputDecoration(labelText: AppLocalizations.of(ctx)!.onboarding_currencyField),
                items: currencies.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('$c — ${currencyLabels[c] ?? ''}'),
                )).toList(),
                onChanged: (v) { if (v != null) selectedCurrency.value = v; },
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: selectedMethod,
              builder: (_, val, __) => DropdownButtonFormField<String>(
                initialValue: val,
                decoration: InputDecoration(labelText: AppLocalizations.of(ctx)!.onboarding_paymentMethodField),
                items: methodLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) { if (v != null) selectedMethod.value = v; },
              ),
            ),
            const SizedBox(height: 16),

            // Proof files section
            Text(AppLocalizations.of(ctx)!.onboarding_proofField, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textSecondary)),
            const SizedBox(height: 8),

            if (proofFiles.isNotEmpty) ...[
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: proofFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final pf = proofFiles[i];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: ShadColors.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ShadColors.cardBorder),
                          ),
                          child: pf['bytes'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(pf['bytes'] as Uint8List, fit: BoxFit.cover, width: 80, height: 80),
                                )
                              : Center(
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.insert_drive_file, size: 24, color: ShadColors.textSecondary),
                                    const SizedBox(height: 4),
                                    Text(pf['name'] ?? '', style: const TextStyle(fontSize: 9, color: ShadColors.textDisabled), overflow: TextOverflow.ellipsis, maxLines: 2, textAlign: TextAlign.center),
                                  ]),
                                ),
                        ),
                        Positioned(
                          right: -6, top: -6,
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() { proofFiles.removeAt(i); });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: ShadColors.error, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await pickProofFromGallery(multiple: true);
                    if (picked.isNotEmpty) {
                      setSheetState(() { proofFiles.addAll(picked); });
                    }
                  },
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(AppLocalizations.of(ctx)!.onboarding_attachFile),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await pickProofFromCamera();
                  if (picked != null) {
                    setSheetState(() { proofFiles.add(picked); });
                  }
                },
                icon: const Icon(Icons.camera_alt, size: 18),
                label: Text(AppLocalizations.of(ctx)!.onboarding_takePhoto),
              ),
            ]),
            if (proofFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(AppLocalizations.of(ctx)!.onboarding_filesAttached(proofFiles.length), style: TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
              ),
            ValueListenableBuilder<String?>(
              valueListenable: errorNotifier,
              builder: (_, err, __) => err == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(err, style: const TextStyle(color: ShadColors.error, fontSize: 13)),
                    ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: uploadingNotifier,
              builder: (_, uploading, __) => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: uploading ? null : () => _submitPaymentOnboarding(
                    ctx, setSheetState, uploadingNotifier, errorNotifier, workspaceId,
                    amountCtrl, selectedCurrency.value, selectedMethod.value, proofFiles,
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
