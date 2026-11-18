// Where the client sends the money: the company's payment methods for HIS
// account type (wallet, InstaPay, bank account, cheque), picked as chips. Once
// one is picked its details show with a copy button per value, and — when the
// method carries a fee (wallets) — the fee and the total to transfer.
//
// When the company has configured no method, or the list cannot be loaded, the
// [fallback] (the old fixed method chips) is shown instead, so a workspace
// without configured methods keeps working exactly as before.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

import '../../core/app_log.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';

/// What the sheet reads back when it submits.
class PaymentMethodChoice {
  /// The picked method (a map from `/payment-methods`), or null.
  final ValueNotifier<Map<String, dynamic>?> selected = ValueNotifier(null);

  /// True once the company has methods for this client: then one must be picked.
  bool required = false;

  int? get methodId => selected.value?['id'] as int?;

  void dispose() => selected.dispose();
}

class PaymentMethodPicker extends StatefulWidget {
  final PaymentMethodChoice choice;
  final Future<List<Map<String, dynamic>>> Function(String currency) fetch;
  final String currency;
  final double? Function() amount;
  final Listenable? amountListenable;
  final Widget fallback;

  const PaymentMethodPicker({
    super.key,
    required this.choice,
    required this.fetch,
    required this.currency,
    required this.amount,
    required this.fallback,
    this.amountListenable,
  });

  @override
  State<PaymentMethodPicker> createState() => _PaymentMethodPickerState();
}

class _PaymentMethodPickerState extends State<PaymentMethodPicker> {
  List<Map<String, dynamic>>? _methods; // null = still loading
  String? _copiedKey;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PaymentMethodPicker old) {
    super.didUpdateWidget(old);
    if (old.currency != widget.currency) _load();
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> list;
    try {
      list = await widget.fetch(widget.currency);
    } catch (e, s) {
      AppLog.error('payment_method_picker._load', e, s);
      list = const [];
    }
    if (!mounted) return;
    final picked = widget.choice.selected.value;
    if (picked != null && !list.any((m) => m['id'] == picked['id'])) {
      widget.choice.selected.value = null;
    }
    widget.choice.required = list.isNotEmpty;
    setState(() => _methods = list);
  }

  String _kind(AppLocalizations l, String kind) => switch (kind) {
        'wallet' => l.payMethodKindWallet,
        'instapay' => l.payMethodKindInstapay,
        'bank_account' => l.payMethodKindBank,
        'cheque' => l.payMethodKindCheque,
        _ => kind,
      };

  String _field(AppLocalizations l, String key) => switch (key) {
        'phone' => l.payMethodFieldPhone,
        'account_name' => l.payMethodFieldAccountName,
        'account_number' => l.payMethodFieldAccountNumber,
        'bank_name' => l.payMethodFieldBankName,
        'iban' => l.payMethodFieldIban,
        'swift' => l.payMethodFieldSwift,
        _ => key,
      };

  // The order a client reads them in. `instructions` is text, not copyable data.
  static const _order = ['phone', 'account_number', 'bank_name', 'account_name', 'iban', 'swift'];

  Future<void> _copy(String key, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _copiedKey = key);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedKey = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final methods = _methods;
    if (methods == null) return const SizedBox(height: 32);
    if (methods.isEmpty) return widget.fallback;

    final l = AppLocalizations.of(context)!;
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: widget.choice.selected,
      builder: (_, picked, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in methods) _chip(context, m, picked?['id'] == m['id']),
        ]),
        if (picked != null) ...[
          const SizedBox(height: 12),
          _details(context, l, picked),
        ],
      ]),
    );
  }

  Widget _chip(BuildContext context, Map<String, dynamic> m, bool on) => Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          key: ValueKey('pay-method-id-${m['id']}'),
          onTap: () => widget.choice.selected.value = m,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: on ? const Color(0x33941414) : null,
              borderRadius: BorderRadius.circular(Lx.rPill),
              border: Border.all(color: on ? const Color(0x80941414) : Lx.line2),
            ),
            child: Text('${m['label']}', style: Lx.text(context, size: 12, color: on ? Lx.ink : Lx.ink2)),
          ),
        ),
      );

  Widget _details(BuildContext context, AppLocalizations l, Map<String, dynamic> m) {
    final details = Map<String, dynamic>.from((m['details'] as Map?) ?? const {});
    final fee = double.tryParse('${m['fee_percent'] ?? 0}') ?? 0;
    final instructions = '${details['instructions'] ?? ''}'.trim();

    return Container(
      key: const ValueKey('pay-method-details'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Lx.line2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${l.payMethodTransferTo} · ${_kind(l, '${m['kind']}')}', style: Lx.text(context, size: 11, color: Lx.muted)),
        const SizedBox(height: 4),
        for (final key in _order)
          if ('${details[key] ?? ''}'.trim().isNotEmpty) _row(context, l, key, '${details[key]}'.trim()),
        if (instructions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(instructions, style: Lx.text(context, size: 12, color: Lx.ink2)),
        ],
        if (fee > 0) _feeBlock(context, l, fee),
      ]),
    );
  }

  Widget _row(BuildContext context, AppLocalizations l, String key, String value) {
    final copied = _copiedKey == key;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_field(l, key), style: Lx.text(context, size: 10.5, color: Lx.faint)),
            // Numbers and IBANs read left to right even inside an Arabic layout.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SelectableText(value, style: Lx.text(context, size: 14)),
              ),
            ),
          ]),
        ),
        IconButton(
          key: ValueKey('pm-copy-$key'),
          tooltip: copied ? l.payMethodCopied : l.payMethodCopy,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: () => _copy(key, value),
          icon: copied
              ? const LxIcon('check', size: 16, color: Lx.ok)
              : const Icon(Icons.copy_outlined, size: 16, color: Lx.ink2),
        ),
      ]),
    );
  }

  Widget _feeBlock(BuildContext context, AppLocalizations l, double feePercent) {
    final listenable = widget.amountListenable;
    Widget build() {
      final amount = widget.amount();
      if (amount == null || amount <= 0) return const SizedBox.shrink();
      final fee = (amount * feePercent / 100 * 100).round() / 100;
      final percent = feePercent == feePercent.roundToDouble() ? feePercent.toStringAsFixed(0) : feePercent.toString();
      Widget line(String k, String v, {bool strong = false}) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(k, style: Lx.text(context, size: strong ? 13 : 12, color: strong ? Lx.ink : Lx.ink2))),
              const SizedBox(width: 12),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(v, style: Lx.text(context, size: strong ? 15 : 12.5, color: strong ? Lx.ink : Lx.ink2)),
              ),
            ]),
          );
      return Padding(
        key: const ValueKey('pay-method-fee'),
        padding: const EdgeInsets.only(top: 6),
        child: Column(children: [
          const Divider(height: 16, color: Lx.line2),
          line(l.payMethodFee(percent), '+ ${lxFormatMoney(fee)} ${widget.currency}'),
          line(l.payMethodTotalToTransfer, '${lxFormatMoney(amount + fee)} ${widget.currency}', strong: true),
        ]),
      );
    }

    return listenable == null ? build() : ListenableBuilder(listenable: listenable, builder: (_, __) => build());
  }
}
