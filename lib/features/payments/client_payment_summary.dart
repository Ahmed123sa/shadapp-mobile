import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

import '../../core/luxe/tokens.dart';
import '../../core/widgets/ads_split.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';

/// What the client owes, once per currency (never added across currencies).
/// The lines (value, fee, conversion, tax) add up to the total; a line that is
/// zero is left out. Per-contract detail sits behind a toggle so fifty
/// contracts do not push the payments out of view, and contracts that were
/// closed are listed apart, with their payments, as history.
class ClientPaymentSummary extends StatefulWidget {
  const ClientPaymentSummary({
    super.key,
    required this.blocks,
    this.closedContracts = const [],
    this.closedPayments = const [],
  });

  /// One map per currency: currency, contracts_total, company_fee_total,
  /// conversion_total, tax_amount, grand_total, paid, remaining, contracts.
  final List<Map<String, dynamic>> blocks;
  final List<Map<String, dynamic>> closedContracts;
  final List<dynamic> closedPayments;

  static const firstCount = 5;

  @override
  State<ClientPaymentSummary> createState() => _ClientPaymentSummaryState();
}

class _ClientPaymentSummaryState extends State<ClientPaymentSummary> {
  bool _detailsOpen = false;
  bool _showAll = false;
  bool _closedOpen = false;
  final Set<int> _openRows = {};

  num _n(Object? v) => num.tryParse('${v ?? 0}') ?? 0;
  String _money(num v, String cur) => '${lxFormatMoney(v)} $cur';

  String _date(Object? raw) {
    final d = DateTime.tryParse('${raw ?? ''}')?.toLocal();
    return d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _line(BuildContext context, String label, String value, {bool bold = false, Key? key}) {
    final style = Lx.text(context,
        size: 12.5,
        color: bold ? Lx.ink : Lx.muted,
        weight: bold ? FontWeight.w600 : FontWeight.w400);
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(label, style: style)),
        const SizedBox(width: 8),
        Text(value, textDirection: TextDirection.ltr, style: style),
      ]),
    );
  }

  Widget _tile(BuildContext context, String label, num value, String cur, {bool highlight = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration:
              BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Lx.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 1.4)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: lxFormatMoney(value),
                      style: Lx.display(context, size: 16, color: highlight ? Lx.ok : Lx.ink)),
                  TextSpan(text: ' $cur', style: Lx.text(context, size: 9.5, color: Lx.muted)),
                ])),
              ),
            ),
          ]),
        ),
      );

  String _taxLabel(AppLocalizations l10n, Map<String, dynamic> b) {
    final cs = (b['contracts'] is List) ? (b['contracts'] as List).whereType<Map>() : const <Map>[];
    final pcts = cs.where((c) => _n(c['tax_amount']) > 0).map((c) => _n(c['tax_percentage'])).toSet();
    if (pcts.length != 1) return l10n.payTaxLine;
    final p = pcts.first;
    return l10n.payTaxLinePct(p == p.roundToDouble() ? '${p.toInt()}' : p.toStringAsFixed(2));
  }

  Widget _block(BuildContext context, AppLocalizations l10n, Map<String, dynamic> b, bool multi) {
    final cur = '${b['currency'] ?? 'SAR'}';
    final grand = _n(b['grand_total']);
    final paid = _n(b['paid']);
    final remaining = _n(b['remaining']);
    final progress = grand > 0 ? (paid / grand).clamp(0.0, 1.0).toDouble() : 0.0;
    final pct = (progress * 100).round();
    return Padding(
      key: ValueKey('payments-block-$cur'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (multi)
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(cur, style: Lx.text(context, size: 12, weight: FontWeight.w600))),
        Row(key: ValueKey('payments-summary-$cur'), children: [
          _tile(context, l10n.payTotalDue, grand, cur),
          const SizedBox(width: 8),
          _tile(context, l10n.onboarding_paidAmount, paid, cur, highlight: true),
          const SizedBox(width: 8),
          _tile(context, l10n.onboarding_remainingAmount2, remaining, cur),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${l10n.onboarding_paidAmount} $pct%', style: Lx.text(context, size: 11.5, color: Lx.muted)),
          Text('${l10n.onboarding_remainingAmount2} ${100 - pct}%',
              style: Lx.text(context, size: 11.5, color: Lx.muted)),
        ]),
        const SizedBox(height: 6),
        LuxeProgressSplit(fraction: progress),
        if (grand > 0 && paid >= grand)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(key: const ValueKey('payments-paid-in-full'), children: [
              const LuxeStatusDot(status: LxStatus.ok),
              const SizedBox(width: 7),
              Text(l10n.payments_paidInFull, style: Lx.text(context, size: 12, color: Lx.ok)),
            ]),
          ),
        const SizedBox(height: 12),
        Container(
          key: ValueKey('payments-lines-$cur'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Lx.surface,
            borderRadius: BorderRadius.circular(Lx.rCard),
            border: Border.all(color: Lx.line2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _line(context, l10n.payContractsValue, _money(_n(b['contracts_total']), cur)),
            if (_n(b['company_fee_total']) > 0)
              _line(context, l10n.payFeeLine, _money(_n(b['company_fee_total']), cur)),
            if (_n(b['conversion_total']) > 0)
              _line(context, l10n.payConversionLine, _money(_n(b['conversion_total']), cur)),
            if (_n(b['tax_amount']) > 0) _line(context, _taxLabel(l10n, b), _money(_n(b['tax_amount']), cur)),
            _line(context, l10n.payTotalDue, _money(grand, cur), bold: true),
          ]),
        ),
      ]),
    );
  }

  Widget _contractDetail(BuildContext context, AppLocalizations l10n, Map c) {
    final cur = '${c['currency'] ?? 'SAR'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _line(context, l10n.payDetailValue, _money(_n(c['value']), cur)),
        if (contractHasAds(c)) AdsSplit(contract: c, currency: cur),
        if (_n(c['tax_amount']) > 0)
          _line(
              context,
              l10n.payTaxLinePct(_n(c['tax_percentage']) == _n(c['tax_percentage']).roundToDouble()
                  ? '${_n(c['tax_percentage']).toInt()}'
                  : _n(c['tax_percentage']).toStringAsFixed(2)),
              _money(_n(c['tax_amount']), cur)),
        _line(context, l10n.payTotalDue, _money(_n(c['total_due'] ?? c['total']), cur), bold: true),
      ]),
    );
  }

  Widget _toggle(BuildContext context, String label, bool open, VoidCallback onTap, {Key? key}) =>
      InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(child: Text(label, style: Lx.text(context, size: 13.5, color: Lx.ink2))),
            Icon(open ? Icons.expand_less : Icons.expand_more, size: 20, color: Lx.muted),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final multi = widget.blocks.length > 1;
    final contracts = <Map>[
      for (final b in widget.blocks)
        for (final c in (b['contracts'] is List ? (b['contracts'] as List).whereType<Map>() : const <Map>[]))
          {...c, 'currency': c['currency'] ?? b['currency']},
    ];
    final shown = _showAll ? contracts : contracts.take(ClientPaymentSummary.firstCount).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final b in widget.blocks) _block(context, l10n, b, multi),
      if (contracts.isNotEmpty) ...[
        _toggle(context, l10n.payDetailsToggle(contracts.length), _detailsOpen,
            () => setState(() => _detailsOpen = !_detailsOpen),
            key: const ValueKey('payments-details-toggle')),
        if (_detailsOpen) ...[
          for (final c in shown)
            Column(key: ValueKey('payments-detail-${c['id']}'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Divider(height: 1),
              InkWell(
                key: ValueKey('payments-detail-row-${c['id']}'),
                onTap: () => setState(() {
                  final id = (c['id'] as num).toInt();
                  _openRows.contains(id) ? _openRows.remove(id) : _openRows.add(id);
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text('${c['title'] ?? ''}', style: Lx.text(context, size: 13.5))),
                    const SizedBox(width: 8),
                    Text(_money(_n(c['total_due'] ?? c['total']), '${c['currency']}'),
                        textDirection: TextDirection.ltr, style: Lx.text(context, size: 13)),
                  ]),
                ),
              ),
              if (_openRows.contains((c['id'] as num).toInt())) _contractDetail(context, l10n, c),
            ]),
          if (contracts.length > ClientPaymentSummary.firstCount)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('payments-show-all'),
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(_showAll ? l10n.payShowLess : l10n.payShowAll(contracts.length)),
              ),
            ),
        ],
      ],
      if (widget.closedContracts.isNotEmpty) ...[
        _toggle(context, l10n.payClosedToggle(widget.closedContracts.length), _closedOpen,
            () => setState(() => _closedOpen = !_closedOpen),
            key: const ValueKey('payments-closed-toggle')),
        if (_closedOpen)
          for (final c in widget.closedContracts)
            Padding(
              key: ValueKey('payments-closed-${c['id']}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                      child: Text('${c['title'] ?? ''}',
                          style: Lx.text(context, size: 13.5, weight: FontWeight.w600))),
                  Text(l10n.closedOn(_date(c['closed_at'])), style: Lx.text(context, size: 12, color: Lx.muted)),
                ]),
                ...() {
                  final own = widget.closedPayments
                      .whereType<Map>()
                      .where((p) => p['contract_id'] == c['id'])
                      .toList();
                  if (own.isEmpty) {
                    return [
                      Text(l10n.payClosedNoPayments, style: Lx.text(context, size: 12, color: Lx.muted))
                    ];
                  }
                  return [
                    for (final p in own)
                      _line(context, _date(p['created_at']),
                          _money(_n(p['amount']), '${p['currency'] ?? c['currency'] ?? 'SAR'}')),
                  ];
                }(),
              ]),
            ),
      ],
    ]);
  }
}
