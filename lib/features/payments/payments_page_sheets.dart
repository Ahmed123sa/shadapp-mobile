// Extracted from payments_page.dart (بند ٨: تقسيم الملفات فوق ٨٠٠ سطر) —
// these are the two "request/pay" bottom sheets the page opens
// (_showRequestPaymentSheet+_submitPaymentDashboard and
// _submitScheduledPayment+_submitScheduledPaymentProof). Byte-identical
// logic to what used to live inline in payments_page.dart; only the
// instance-field reads (_availableMethods, _grandTotal, _payments, _api,
// _paymentProvider, _load) became explicit parameters, since a top-level
// function can't reach a State's private fields.
//
// Two BuildContexts matter here and the original code deliberately mixes
// them per-line (not a mistake to "clean up" — preserved exactly):
// `pageContext` is payments_page.dart's own State.context (used to open the
// sheet and for most AppLocalizations lookups inside it), while `ctx` is the
// sheet's own builder context (used for Navigator.pop/ScaffoldMessenger/
// mounted-checks and a few AppLocalizations lookups). Where a value could
// change while the sheet is open — payments_page.dart auto-refreshes every
// 30s via a Timer — the caller passes a live accessor closure
// (`List<String> Function() getAvailableMethods` etc.) rather than a
// snapshotted value, same principle as chatOnMessageReceived/Updated in
// chat_shared.dart (see docs/state-layer-migration-plan.md, بند ٥).
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

// ── Luxe sheet pieces (mockup `paySheet`), shared by both sheets ──

Widget _label(BuildContext ctx, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: Lx.text(ctx, size: 11, color: Lx.muted)),
    );

/// Mockup `.chips2`: one pill per method, the picked one crimson-tinted.
Widget _methodChips(BuildContext ctx, Map<String, String> labels, ValueNotifier<String> selected) =>
    ValueListenableBuilder<String>(
      valueListenable: selected,
      builder: (_, val, __) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in labels.entries)
          GestureDetector(
            key: ValueKey('pay-method-${e.key}'),
            onTap: () => selected.value = e.key,
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
      ]),
    );

/// Receipt picker: dashed "add files" box + camera, then one `.thumb` pill
/// per picked file with a × to drop it.
List<Widget> _proofPicker(
  BuildContext ctx,
  String addLabel,
  List<Map<String, dynamic>> proofFiles,
  void Function(void Function()) setSheetState,
) =>
    [
      Row(children: [
        Expanded(
          child: GestureDetector(
            key: const ValueKey('payment-attach'),
            onTap: () async {
              final picked = await pickProofFromGallery();
              if (picked.isNotEmpty) setSheetState(() => proofFiles.addAll(picked));
            },
            child: LuxeDashedBox(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const LxIcon('up', size: 16, color: Lx.muted),
                const SizedBox(width: 8),
                Flexible(child: Text(addLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(ctx, size: 12.5, color: Lx.ink2))),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkResponse(
          key: const ValueKey('payment-camera'),
          onTap: () async {
            final picked = await pickProofFromCamera();
            if (picked != null) setSheetState(() => proofFiles.add(picked));
          },
          radius: 24,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Lx.line2)),
            child: const Icon(Icons.photo_camera_outlined, size: 18, color: Lx.ink2),
          ),
        ),
      ]),
      if (proofFiles.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
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
          ]),
        ),
    ];

/// Red line inside the sheet (a SnackBar would hide behind it).
Widget _errorBox(BuildContext ctx, ValueNotifier<String?> errorNotifier) => ValueListenableBuilder<String?>(
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
    );

Widget _sendButton(String label, ValueNotifier<bool> uploadingNotifier, VoidCallback onSend) => ValueListenableBuilder<bool>(
      valueListenable: uploadingNotifier,
      builder: (_, uploading, __) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: uploading ? null : onSend,
          style: ElevatedButton.styleFrom(
            backgroundColor: Lx.crimson,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF2A2827),
            minimumSize: const Size.fromHeight(48),
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          child: uploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label),
        ),
      ),
    );

const _underline = UnderlineInputBorder(borderSide: BorderSide(color: Lx.line2));

void showRequestPaymentSheet({
  required BuildContext pageContext,
  required List<String> Function() getAvailableMethods,
  required double Function() getGrandTotal,
  required List<dynamic> Function() getPayments,
  required List<Map<String, dynamic>> Function() getPayableContracts,
  String Function()? getContractCurrency,
  required PaymentProvider paymentProvider,
  required ApiClient api,
  required Future<void> Function() load,
}) {
  final l10n = AppLocalizations.of(pageContext)!;
  final methodLabels = <String, String>{
    'bank_transfer': l10n.payments_methodBankTransfer,
    'swift': l10n.payments_methodSwift,
    'corporate_account': l10n.payments_methodCorporateAccount,
    'instapay': l10n.payments_methodInstapay,
    'vodafone_cash': l10n.payments_methodVodafoneCash,
    'mobile_wallet': l10n.payments_methodMobileWallet,
    'cheque': l10n.payments_methodCheque,
  };

  final contractCur = getContractCurrency?.call() ?? 'SAR';
  // The payment's currency is always the linked contract's — enforced
  // server-side by PaymentController::resolveCurrency() regardless of what
  // gets submitted (plans/payment-currency-plan.md). This used to be a free
  // dropdown locked to a single [contractCur] item that never updated when
  // the contract picker below was switched (م5) — currencyFor() now derives
  // the right value from whichever contract is actually selected, so the
  // display and the submitted currency both follow it.
  final payableContracts = getPayableContracts();
  String currencyFor(int? contractId) {
    if (contractId != null) {
      final match = payableContracts.firstWhere((c) => c['id'] == contractId, orElse: () => <String, dynamic>{});
      final cur = match['currency'] as String?;
      if (cur != null) return cur;
    }
    return contractCur;
  }

  final available = getAvailableMethods().isNotEmpty ? getAvailableMethods() : methodLabels.keys.toList();
  final amountCtrl = TextEditingController();
  final selectedMethod = ValueNotifier<String>(available.first);
  // Only let the user pick a contract when there is more than one payable
  // contract; 0/1 keeps the legacy auto-link behaviour byte-identical and the
  // payload stays contract_id-free so the backend falls back to the latest
  // contract. The id is only read off this notifier after an explicit pick.
  final selectedContract = ValueNotifier<int?>(null);
  List<Map<String, dynamic>> proofFiles = [];
  final uploadingNotifier = ValueNotifier<bool>(false);
  // Shown as a red line inside the sheet on failure — never a SnackBar, since
  // a SnackBar renders behind this still-open sheet and goes unnoticed.
  // payment-proof-upload-plan.md, Stage 4 (ح1).
  final errorNotifier = ValueNotifier<String?>(null);

  // Auto-suggest grand total
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final grandTotal = getGrandTotal();
    if (grandTotal > 0 && getPayments().where((p) => p['status'] == 'pending').isEmpty) {
      amountCtrl.text = grandTotal.toString();
    }
  });

  // Mockup `paySheet`: serif title, amount + read-only currency (.f2), the
  // contract picker only when more than one contract can be paid, method
  // chips, receipt picker, full-width primary button.
  showLuxeSheet<void>(
    pageContext,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final pl10n = AppLocalizations.of(pageContext)!;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pl10n.payments_requestPayment, style: Lx.display(ctx, size: 22)),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label(ctx, '${pl10n.payments_amount} *'),
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
                    border: _underline,
                    enabledBorder: _underline,
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.muted)),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 90,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label(ctx, pl10n.payments_currency),
                ValueListenableBuilder<int?>(
                  valueListenable: selectedContract,
                  builder: (_, contractId, __) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                    child: Text(currencyFor(contractId), key: const ValueKey('payment-currency'), style: Lx.text(ctx, size: 15, color: Lx.ink2)),
                  ),
                ),
              ]),
            ),
          ]),
          if (payableContracts.length > 1) ...[
            const SizedBox(height: 16),
            _label(ctx, pl10n.payments_selectContract),
            ValueListenableBuilder<int?>(
              valueListenable: selectedContract,
              builder: (_, val, __) => DropdownButtonFormField<int>(
                initialValue: val,
                isExpanded: true,
                dropdownColor: Lx.sheet,
                style: Lx.text(ctx, size: 13.5),
                icon: const LxIcon('down', size: 14, color: Lx.muted),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.only(bottom: 8),
                  border: _underline,
                  enabledBorder: _underline,
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Lx.muted)),
                ),
                items: payableContracts.map((c) => DropdownMenuItem(
                  value: c['id'] as int?,
                  child: Text('${c['title']} (${c['value']} ${c['currency']})', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  selectedContract.value = v;
                  final selected = payableContracts.firstWhere((c) => c['id'] == v, orElse: () => <String, dynamic>{});
                  final suggested = selected['value']?.toString();
                  if (suggested != null && amountCtrl.text.trim().isEmpty) {
                    amountCtrl.text = suggested;
                    setSheetState(() {});
                  }
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          _label(ctx, pl10n.payments_paymentMethod),
          _methodChips(ctx, methodLabels, selectedMethod),
          const SizedBox(height: 16),
          _label(ctx, pl10n.payments_attachProof),
          ..._proofPicker(ctx, pl10n.onboardingDropTitle, proofFiles, setSheetState),
          _errorBox(ctx, errorNotifier),
          const SizedBox(height: 18),
          _sendButton(pl10n.payments_sendPayment, uploadingNotifier, () => _submitPaymentDashboard(
            ctx, setSheetState, uploadingNotifier, errorNotifier,
            amountCtrl, currencyFor(selectedContract.value), selectedMethod.value, selectedContract.value, proofFiles,
            paymentProvider, api, load,
          )),
        ]);
      },
    ),
  );
}

Future<void> _submitPaymentDashboard(
  BuildContext ctx,
  void Function(void Function()) setSheetState,
  ValueNotifier<bool> uploadingNotifier,
  ValueNotifier<String?> errorNotifier,
  TextEditingController amountCtrl,
  String currency,
  String methodType,
  int? contractId,
  List<Map<String, dynamic>> proofFiles,
  PaymentProvider paymentProvider,
  ApiClient api,
  Future<void> Function() load,
) async {
  // Captured once, before any `await`: looking it up again inside the catch
  // blocks below (after the request has actually gone out) is exactly the
  // `use_build_context_synchronously` pattern flutter analyze flags, since it
  // can't tell a caught exception means ctx is still safe to read from.
  final l10n = AppLocalizations.of(ctx)!;
  errorNotifier.value = null;
  final amount = double.tryParse(amountCtrl.text);
  if (amount == null || amount <= 0) {
    errorNotifier.value = l10n.payments_enterValidAmount;
    if (ctx.mounted) setSheetState(() {});
    return;
  }
  final wsId = api.workspaceId;
  if (wsId == null) {
    errorNotifier.value = l10n.payments_workspaceUnavailable;
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
      if (contractId != null) 'contract_id': contractId,
    };

    final nativeFiles = proofFiles.where((pf) => pf['file'] != null).map((pf) => pf['file'] as File).toList();
    final bytesFiles = proofFiles.where((pf) => pf['bytes'] != null).map((pf) => pf['bytes'] as Uint8List).toList();
    final bytesNames = proofFiles.where((pf) => pf['bytes'] != null).map((pf) => pf['name'] as String? ?? 'file.jpg').toList();

    await paymentProvider.createPayment(
      wsId,
      fields,
      files: nativeFiles.isNotEmpty ? nativeFiles : null,
      bytesFiles: bytesFiles.isNotEmpty ? bytesFiles : null,
      bytesNames: bytesFiles.isNotEmpty ? bytesNames : null,
    );

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Row(children: [const LxIcon('check', size: 18, color: Lx.ok), const SizedBox(width: 8), Flexible(child: Text(l10n.payments_requestSent))])));
      Navigator.pop(ctx);
    }
    await load();
  } on ValidationException catch (e) {
    AppLog.error('payments_page_sheets._submitPaymentDashboard', e);
    errorNotifier.value = e.message;
  } on ConnectionException catch (e) {
    AppLog.error('payments_page_sheets._submitPaymentDashboard', e);
    errorNotifier.value = l10n.connectionFailedMessage;
  } on ServerException catch (e) {
    AppLog.error('payments_page_sheets._submitPaymentDashboard', e);
    errorNotifier.value = e.message.isNotEmpty ? e.message : l10n.serverErrorMessage;
  } catch (e, s) {
    AppLog.error('payments_page_sheets._submitPaymentDashboard', e, s);
    errorNotifier.value = l10n.payments_sendFailed;
  }
  uploadingNotifier.value = false;
  if (ctx.mounted) setSheetState(() {});
}

void showScheduledPaymentSheet({
  required BuildContext pageContext,
  required dynamic payment,
  required List<String> Function() getAvailableMethods,
  required PaymentProvider paymentProvider,
  required ApiClient api,
  required Future<void> Function() load,
}) {
  final p = payment;
  final l10n = AppLocalizations.of(pageContext)!;
  final methodLabels = <String, String>{
    'bank_transfer': l10n.payments_methodBankTransfer,
    'swift': l10n.payments_methodSwift,
    'corporate_account': l10n.payments_methodCorporateAccount,
    'instapay': l10n.payments_methodInstapay,
    'vodafone_cash': l10n.payments_methodVodafoneCash,
    'mobile_wallet': l10n.payments_methodMobileWallet,
    'cheque': l10n.payments_methodCheque,
  };

  final available = getAvailableMethods().isNotEmpty ? getAvailableMethods() : methodLabels.keys.toList();
  final selectedMethod = ValueNotifier<String>(available.first);
  List<Map<String, dynamic>> proofFiles = [];
  final uploadingNotifier = ValueNotifier<bool>(false);
  final errorNotifier = ValueNotifier<String?>(null);
  final paymentId = p['id'];
  final amount = p['amount']?.toString() ?? '0';
  final currency = p['currency']?.toString() ?? 'SAR';
  final label = p['installment_label']?.toString() ?? l10n.payments_scheduledPayment;

  final amt = num.tryParse(amount);
  // Same Luxe sheet: what you are paying (label + amount), then method,
  // receipt and the send button.
  showLuxeSheet<void>(
    pageContext,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final cl10n = AppLocalizations.of(ctx)!;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.payments_payScheduled(label), style: Lx.display(ctx, size: 22)),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: amt != null ? lxFormatMoney(amt) : amount, style: Lx.display(ctx, size: 26)),
                TextSpan(text: ' $currency', style: Lx.text(ctx, size: 11, color: Lx.muted)),
              ]),
              key: const ValueKey('scheduled-amount'),
            ),
          ),
          const SizedBox(height: 18),
          _label(ctx, l10n.payments_paymentMethodLabel),
          _methodChips(ctx, methodLabels, selectedMethod),
          const SizedBox(height: 16),
          _label(ctx, cl10n.payments_attachProofLabel),
          ..._proofPicker(ctx, cl10n.onboardingDropTitle, proofFiles, setSheetState),
          _errorBox(ctx, errorNotifier),
          const SizedBox(height: 18),
          _sendButton(cl10n.payments_sendProof, uploadingNotifier, () => _submitScheduledPaymentProof(
            ctx, setSheetState, uploadingNotifier, errorNotifier, paymentId, selectedMethod.value, proofFiles,
            paymentProvider, api, load,
          )),
        ]);
      },
    ),
  );
}

Future<void> _submitScheduledPaymentProof(
  BuildContext ctx,
  void Function(void Function()) setSheetState,
  ValueNotifier<bool> uploadingNotifier,
  ValueNotifier<String?> errorNotifier,
  dynamic paymentId,
  String methodType,
  List<Map<String, dynamic>> proofFiles,
  PaymentProvider paymentProvider,
  ApiClient api,
  Future<void> Function() load,
) async {
  final l10n = AppLocalizations.of(ctx)!;
  errorNotifier.value = null;
  if (proofFiles.isEmpty) {
    errorNotifier.value = l10n.payments_requireProof;
    if (ctx.mounted) setSheetState(() {});
    return;
  }
  final wsId = api.workspaceId;
  if (wsId == null) {
    errorNotifier.value = l10n.payments_workspaceUnavailableMsg;
    if (ctx.mounted) setSheetState(() {});
    return;
  }
  uploadingNotifier.value = true;
  setSheetState(() {});
  try {
    final nativeFiles = proofFiles.where((pf) => pf['file'] != null).map((pf) => pf['file'] as File).toList();
    final bytesFiles = proofFiles.where((pf) => pf['bytes'] != null).map((pf) => pf['bytes'] as Uint8List).toList();
    final bytesNames = proofFiles.where((pf) => pf['bytes'] != null).map((pf) => pf['name'] as String? ?? 'file.jpg').toList();

    await paymentProvider.uploadPaymentProof(
      wsId,
      paymentId,
      methodType,
      files: nativeFiles.isNotEmpty ? nativeFiles : null,
      bytesFiles: bytesFiles.isNotEmpty ? bytesFiles : null,
      bytesNames: bytesFiles.isNotEmpty ? bytesNames : null,
    );

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Row(children: [const LxIcon('check', size: 18, color: Lx.ok), const SizedBox(width: 8), Flexible(child: Text(l10n.payments_proofSent))])));
      Navigator.pop(ctx);
    }
    await load();
  } on ValidationException catch (e) {
    AppLog.error('payments_page_sheets._submitScheduledPaymentProof', e);
    errorNotifier.value = e.message;
  } on ConnectionException catch (e) {
    AppLog.error('payments_page_sheets._submitScheduledPaymentProof', e);
    errorNotifier.value = l10n.connectionFailedMessage;
  } on ServerException catch (e) {
    AppLog.error('payments_page_sheets._submitScheduledPaymentProof', e);
    errorNotifier.value = e.message.isNotEmpty ? e.message : l10n.serverErrorMessage;
  } catch (e, s) {
    AppLog.error('payments_page_sheets._submitScheduledPaymentProof', e, s);
    errorNotifier.value = l10n.payments_proofSendFailed;
  }
  uploadingNotifier.value = false;
  if (ctx.mounted) setSheetState(() {});
}
