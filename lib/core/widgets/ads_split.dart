import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../luxe/tokens.dart';

/// Ads contracts: the agency's management fee is a share of the contract value
/// (inside it, never on top). The server sends the split already computed, so
/// this only shows it; the value, the tax and the total are not touched.
bool contractHasAds(Map? c) {
  if (c == null) return false;
  return c['ads_percentage'] != null && c['ads_amount'] != null && c['ads_budget'] != null;
}

String _pct(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// The two lines under a contract value: the fee, then the budget.
class AdsSplit extends StatelessWidget {
  const AdsSplit({super.key, required this.contract, required this.currency, this.size = 11.5});

  final Map contract;
  final String currency;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!contractHasAds(contract)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    num n(Object? v) => num.tryParse('${v ?? 0}') ?? 0;

    Widget line(String label, num amount) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text(label, style: Lx.text(context, size: size, color: Lx.muted))),
            const SizedBox(width: 8),
            Text('${lxFormatMoney(amount)} $currency', textDirection: TextDirection.ltr, style: Lx.text(context, size: size, color: Lx.muted)),
          ]),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        key: const ValueKey('ads-split'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(l10n.adsFee(_pct(n(contract['ads_percentage']))), n(contract['ads_amount'])),
          line(l10n.adsBudget, n(contract['ads_budget'])),
        ],
      ),
    );
  }
}

/// Small label for a contract card, so an ads contract stands out in a list.
class AdsBadge extends StatelessWidget {
  const AdsBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const ValueKey('ads-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lx.rCard),
        border: Border.all(color: Lx.line2),
      ),
      child: Text(l10n.adsBadge, style: Lx.text(context, size: 10, color: Lx.muted)),
    );
  }
}
