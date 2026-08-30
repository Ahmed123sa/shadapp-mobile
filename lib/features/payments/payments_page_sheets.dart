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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../providers/payment_provider.dart';

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
  };

  final contractCur = getContractCurrency?.call() ?? 'SAR';
  final currencies = [contractCur];
  final currencyLabels = <String, String>{
    'SAR': l10n.currency_sar, 'USD': l10n.currency_usd, 'EUR': l10n.currency_eur,
    'AED': l10n.currency_aed, 'EGP': l10n.currency_egp, 'KWD': l10n.currency_kwd,
    'QAR': l10n.currency_qar, 'BHD': l10n.currency_bhd, 'OMR': l10n.currency_omr,
  };

  final available = getAvailableMethods().isNotEmpty ? getAvailableMethods() : methodLabels.keys.toList();
  final amountCtrl = TextEditingController();
  final selectedMethod = ValueNotifier<String>(available.first);
  final selectedCurrency = ValueNotifier<String>(contractCur);
  // Only let the user pick a contract when there is more than one payable
  // contract; 0/1 keeps the legacy auto-link behaviour byte-identical and the
  // payload stays contract_id-free so the backend falls back to the latest
  // contract. The id is only read off this notifier after an explicit pick.
  final payableContracts = getPayableContracts();
  final selectedContract = ValueNotifier<int?>(null);
  List<Map<String, dynamic>> proofFiles = [];
  final uploadingNotifier = ValueNotifier<bool>(false);

  // Auto-suggest grand total
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final grandTotal = getGrandTotal();
    if (grandTotal > 0 && getPayments().where((p) => p['status'] == 'pending').isEmpty) {
      amountCtrl.text = grandTotal.toString();
    }
  });

  showModalBottomSheet(
    context: pageContext,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(AppLocalizations.of(pageContext)!.payments_requestPayment, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 16),
          ValueListenableBuilder<String>(
            valueListenable: selectedCurrency,
            builder: (_, cur, __) => TextField(
              controller: amountCtrl,
              decoration: InputDecoration(labelText: '${AppLocalizations.of(pageContext)!.payments_amount} *', hintText: '0.00', prefixText: '$cur '),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: selectedCurrency,
            builder: (_, cur, __) => DropdownButtonFormField<String>(
              initialValue: cur,
              decoration: InputDecoration(labelText: AppLocalizations.of(pageContext)!.payments_currency),
              items: currencies.map((c) => DropdownMenuItem(
                value: c,
                child: Text('$c — ${currencyLabels[c] ?? ''}'),
              )).toList(),
              onChanged: (v) { if (v != null) selectedCurrency.value = v; },
            ),
          ),
          const SizedBox(height: 12),
          if (payableContracts.length > 1) ...[
            ValueListenableBuilder<int?>(
              valueListenable: selectedContract,
              builder: (_, val, __) => DropdownButtonFormField<int>(
                initialValue: val,
                decoration: InputDecoration(labelText: AppLocalizations.of(pageContext)!.payments_selectContract),
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
            const SizedBox(height: 12),
          ],
          ValueListenableBuilder<String>(
            valueListenable: selectedMethod,
            builder: (_, val, __) => DropdownButtonFormField<String>(
              initialValue: val,
              decoration: InputDecoration(labelText: AppLocalizations.of(pageContext)!.payments_paymentMethod),
              items: methodLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) { if (v != null) selectedMethod.value = v; },
            ),
          ),
          const SizedBox(height: 12),
          if (proofFiles.isNotEmpty) ...[
            SizedBox(
              height: 100,
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
                  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: kIsWeb);
                  if (r != null && r.files.isNotEmpty) {
                    setSheetState(() {
                      final f = r.files.first;
                      if (kIsWeb) {
                        proofFiles.add({'bytes': f.bytes, 'name': f.name});
                      } else {
                        proofFiles.add({'file': File(f.path!), 'name': f.name});
                      }
                    });
                  }
                },
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(AppLocalizations.of(pageContext)!.payments_attachProof),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final r = await ImagePicker().pickImage(source: ImageSource.camera);
                if (r != null) {
                  setSheetState(() {
                    if (kIsWeb) {
                      r.readAsBytes().then((bytes) {
                        setSheetState(() { proofFiles.add({'bytes': bytes, 'name': r.name}); });
                      });
                    } else {
                      proofFiles.add({'file': File(r.path), 'name': r.name});
                    }
                  });
                }
              },
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Icon(Icons.camera_alt, size: 18),
            ),
          ]),
          const SizedBox(height: 20),
          ValueListenableBuilder<bool>(
            valueListenable: uploadingNotifier,
            builder: (_, uploading, __) => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: uploading ? null : () => _submitPaymentDashboard(
                  ctx, setSheetState, uploadingNotifier,
                  amountCtrl, selectedCurrency.value, selectedMethod.value, selectedContract.value, proofFiles,
                  paymentProvider, api, load,
                ),
                child: uploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppLocalizations.of(pageContext)!.payments_sendPayment),
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}

Future<void> _submitPaymentDashboard(
  BuildContext ctx,
  void Function(void Function()) setSheetState,
  ValueNotifier<bool> uploadingNotifier,
  TextEditingController amountCtrl,
  String currency,
  String methodType,
  int? contractId,
  List<Map<String, dynamic>> proofFiles,
  PaymentProvider paymentProvider,
  ApiClient api,
  Future<void> Function() load,
) async {
  final amount = double.tryParse(amountCtrl.text);
  if (amount == null || amount <= 0) {
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.payments_enterValidAmount)));
    return;
  }
  final wsId = api.workspaceId;
  if (wsId == null) {
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.payments_workspaceUnavailable)));
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
      final l10n = AppLocalizations.of(ctx)!;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(l10n.payments_requestSent)])));
      Navigator.pop(ctx);
    }
    await load();
  } catch (_) {
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.payments_sendFailed)));
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
  };

  final available = getAvailableMethods().isNotEmpty ? getAvailableMethods() : methodLabels.keys.toList();
  final selectedMethod = ValueNotifier<String>(available.first);
  List<Map<String, dynamic>> proofFiles = [];
  final uploadingNotifier = ValueNotifier<bool>(false);
  final paymentId = p['id'];
  final amount = p['amount']?.toString() ?? '0';
  final currency = p['currency']?.toString() ?? 'SAR';
  final label = p['installment_label']?.toString() ?? l10n.payments_scheduledPayment;

  showModalBottomSheet(
    context: pageContext,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.payment, size: 20, color: ShadColors.gold),
            const SizedBox(width: 8),
            Text(l10n.payments_payScheduled(label), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'NotoSansArabic')),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ShadColors.gold.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: ShadColors.gold.withAlpha(40))),
            child: Row(children: [
              const Icon(Icons.attach_money, size: 16, color: ShadColors.gold),
              const SizedBox(width: 8),
              Text('$amount $currency', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
            ]),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: selectedMethod,
            builder: (_, val, __) => DropdownButtonFormField<String>(
              initialValue: val,
              decoration: InputDecoration(labelText: AppLocalizations.of(pageContext)!.payments_paymentMethodLabel),
              items: methodLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) { if (v != null) selectedMethod.value = v; },
            ),
          ),
          const SizedBox(height: 12),
          if (proofFiles.isNotEmpty) ...[
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: proofFiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final pf = proofFiles[i];
                  return Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(color: ShadColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: ShadColors.cardBorder)),
                      child: pf['bytes'] != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(pf['bytes'] as Uint8List, fit: BoxFit.cover, width: 70, height: 70))
                          : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.insert_drive_file, size: 20, color: ShadColors.textSecondary),
                              const SizedBox(height: 2),
                              Text(pf['name'] ?? '', style: const TextStyle(fontSize: 8, color: ShadColors.textDisabled), overflow: TextOverflow.ellipsis, maxLines: 2, textAlign: TextAlign.center),
                            ])),
                    ),
                    Positioned(right: -4, top: -4, child: GestureDetector(
                      onTap: () => setSheetState(() => proofFiles.removeAt(i)),
                      child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: ShadColors.error, shape: BoxShape.circle), child: const Icon(Icons.close, size: 10, color: Colors.white)),
                    )),
                  ]);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: kIsWeb);
                  if (r != null && r.files.isNotEmpty) {
                    setSheetState(() {
                      final f = r.files.first;
                      if (kIsWeb) {
                        proofFiles.add({'bytes': f.bytes, 'name': f.name});
                      } else {
                        proofFiles.add({'file': File(f.path!), 'name': f.name});
                      }
                    });
                  }
                },
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(AppLocalizations.of(ctx)!.payments_attachProofLabel),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final r = await ImagePicker().pickImage(source: ImageSource.camera);
                if (r != null) {
                  setSheetState(() {
                    if (kIsWeb) {
                      r.readAsBytes().then((bytes) => setSheetState(() => proofFiles.add({'bytes': bytes, 'name': r.name})));
                    } else {
                      proofFiles.add({'file': File(r.path), 'name': r.name});
                    }
                  });
                }
              },
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Icon(Icons.camera_alt, size: 18),
            ),
          ]),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: uploadingNotifier,
            builder: (_, uploading, __) => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: uploading ? null : () => _submitScheduledPaymentProof(
                  ctx, setSheetState, uploadingNotifier, paymentId, selectedMethod.value, proofFiles,
                  paymentProvider, api, load,
                ),
                child: uploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppLocalizations.of(ctx)!.payments_sendProof),
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}

Future<void> _submitScheduledPaymentProof(
  BuildContext ctx,
  void Function(void Function()) setSheetState,
  ValueNotifier<bool> uploadingNotifier,
  dynamic paymentId,
  String methodType,
  List<Map<String, dynamic>> proofFiles,
  PaymentProvider paymentProvider,
  ApiClient api,
  Future<void> Function() load,
) async {
  final l10n = AppLocalizations.of(ctx)!;
  if (proofFiles.isEmpty) {
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(l10n.payments_requireProof)));
    return;
  }
  final wsId = api.workspaceId;
  if (wsId == null) {
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(l10n.payments_workspaceUnavailableMsg)));
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
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(l10n.payments_proofSent)])));
      Navigator.pop(ctx);
    }
    await load();
  } catch (_) {
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(l10n.payments_proofSendFailed)));
  }
  uploadingNotifier.value = false;
  if (ctx.mounted) setSheetState(() {});
}
