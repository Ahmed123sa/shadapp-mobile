import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../luxe/tokens.dart';

/// Ads contracts: the contract value is the ad budget, and the agency's
/// management fee is a share of it added on top. The server sends the figures
/// already computed, so this only shows them; the tax and the total are not touched.
bool contractHasAds(Map? c) {
  if (c == null) return false;
  return c['ads_percentage'] != null && c['ads_amount'] != null && c['ads_budget'] != null;
}

/// An ads contract with a dollar-conversion fee above zero. The fee is added on
/// top (a share of the full ad budget, never taxed).
bool contractHasConversion(Map? c) {
  if (!contractHasAds(c)) return false;
  return (num.tryParse('${c!['conversion_amount'] ?? 0}') ?? 0) > 0;
}

String _pct(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// The lines under an ads contract: the budget, then the fee added on top of it.
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
          line(l10n.adsBudget, n(contract['ads_budget'])),
          line(l10n.adsFee(_pct(n(contract['ads_percentage']))), n(contract['ads_amount'])),
          if (contractHasConversion(contract))
            KeyedSubtree(
              key: const ValueKey('ads-conversion'),
              child: line(l10n.adsConversion(_pct(n(contract['conversion_percentage']))), n(contract['conversion_amount'])),
            ),
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
