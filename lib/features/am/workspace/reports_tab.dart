import 'package:flutter/material.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/theme.dart' show statusLabels;
import '../../../core/widgets/luxe/luxe_widgets.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../models/client.dart';
import '../../../models/manager.dart';
import '../../../providers/client_provider.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/report_provider.dart';
import 'reports_tab_widgets.dart';

class ReportsTab extends StatefulWidget {
  final ClientProvider? clientProvider;
  final ManagerProvider? managerProvider;
  final ReportProvider? reportProvider;

  const ReportsTab({super.key, this.clientProvider, this.managerProvider, this.reportProvider});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider();
  late final ManagerProvider _managerProvider = widget.managerProvider ?? ManagerProvider();
  late final ReportProvider _reportProvider = widget.reportProvider ?? ReportProvider();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  double _toDouble(dynamic value) => num.tryParse(value?.toString() ?? '')?.toDouble() ?? 0;

  String? _error;

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return {};
  }

  // SAR/USD first (matches the web Finance page's card order), rest
  // alphabetical — applied to whatever currencies actually show up in the
  // data, not a fixed list.
  List<String> _sortCurrencies(Iterable<String> currencies) {
    const order = ['SAR', 'USD'];
    final list = currencies.toList();
    list.sort((a, b) {
      final ai = order.indexOf(a);
      final bi = order.indexOf(b);
      if (ai != -1 || bi != -1) return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
      return a.compareTo(b);
    });
    return list;
  }

  // 21 Sept 2026 — shared by the KPI card and the revenue chart, both of
  // which used to read payments_by_month (every currency summed into one
  // number, no currency attached at all). Computed once per build so both
  // call sites agree on the same currencies/totals/default.
  (Map<String, Map<String, dynamic>>, List<String>, Map<String, double>, String?) _revenueByCurrency() {
    final byMonth = _safeMap(_stats?['payments_by_month_by_currency'])
        .map((month, byCur) => MapEntry(month, _safeMap(byCur)));
    final currencySet = <String>{};
    for (final byCur in byMonth.values) {
      currencySet.addAll(byCur.keys);
    }
    final currencies = _sortCurrencies(currencySet);
    final totals = <String, double>{
      for (final cur in currencies)
        cur: byMonth.values.fold<double>(0, (s, byCur) => s + _toDouble(byCur[cur])),
    };
    final defaultCurrency = currencies.isEmpty
        ? null
        : currencies.reduce((best, cur) => totals[cur]! > totals[best]! ? cur : best);
    return (byMonth, currencies, totals, defaultCurrency);
  }

  String _selectedPeriod = 'all';
  bool _showCustomFilters = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int? _selectedClientId;
  String? _clientType;
  int? _selectedManagerId;
  List<Client> _clients = [];
  List<Manager> _managers = [];
  List<Map<String, dynamic>> _managerStats = [];
  String _chartPeriod = '1y';
  // 21 Sept 2026 — null means "no explicit pick yet"; the render below falls
  // back to whichever currency has the largest total. See _revenueByCurrency.
  String? _selectedRevenueCurrency;

  @override
  void initState() {
    super.initState();
    _load();
    _loadClients();
    _loadManagers();
  }

  /// Resolves the date range implied by [_selectedPeriod] (or the explicit
  /// custom pickers) — the client/type/manager filters are passed straight
  /// through to [ReportProvider.fetch] separately.
  (String?, String?) _resolveDateRange() {
    if (_selectedPeriod == 'month') {
      final now = DateTime.now();
      return (
        DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10),
        now.toIso8601String().substring(0, 10),
      );
    } else if (_selectedPeriod == '3months') {
      final now = DateTime.now();
      return (
        DateTime(now.year, now.month - 2, 1).toIso8601String().substring(0, 10),
        now.toIso8601String().substring(0, 10),
      );
    } else if (_selectedPeriod == 'year') {
      final now = DateTime.now();
      return (
        DateTime(now.year, 1, 1).toIso8601String().substring(0, 10),
        now.toIso8601String().substring(0, 10),
      );
    } else if (_selectedPeriod == 'custom') {
      return (
        _dateFrom?.toIso8601String().substring(0, 10),
        _dateTo?.toIso8601String().substring(0, 10),
      );
    }
    return (null, null);
  }

  Future<void> _loadClients() async {
    await _clientProvider.fetchClients();
    _clients = _clientProvider.clients;
  }

  Future<void> _loadManagers() async {
    await _managerProvider.fetchManagers();
    _managers = _managerProvider.managers;
  }

  void _clearFilters() {
    setState(() {
      _selectedPeriod = 'all';
      _showCustomFilters = false;
      _dateFrom = null;
      _dateTo = null;
      _selectedClientId = null;
      _clientType = null;
      _selectedManagerId = null;
    });
    _load();
  }

  Future<void> _load() async {
    setState(() { if (_stats == null) _loading = true; _error = null; });
    try {
      final (dateFrom, dateTo) = _resolveDateRange();
      final reportsResult = await _reportProvider.fetch(
        dateFrom: dateFrom,
        dateTo: dateTo,
        clientId: _selectedClientId,
        clientType: _clientType,
        managerId: _selectedManagerId,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;

      if (reportsResult['error'] == true) {
        _error = reportsResult['message']?.toString() ?? l10n.reportsLoadFailed;
      } else {
        _stats = reportsResult;
        final raw = reportsResult['manager_stats'];
        if (raw is List) _managerStats = raw.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      if (mounted) _error = AppLocalizations.of(context)!.errorOccurred;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    final l10n = AppLocalizations.of(context)!;
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: Lx.text(context, size: 14, color: Lx.danger)),
            const SizedBox(height: 16),
            LuxeFormTheme(child: ElevatedButton(onPressed: _load, child: Text(l10n.retry))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: Lx.crimsonInk,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 28),
        children: [
          _head(l10n),
          _periodChips(l10n),
          if (_selectedPeriod == 'custom' && _showCustomFilters) _buildCustomFilterPanel(),
          _kpiGrid(l10n),
          _monthlyCard(l10n),
          _statusCard(l10n),
          _approvalsCard(l10n),
          _rankingCard(l10n),
        ],
      ),
    );
  }

  // Mockup `head()`: eyebrow + serif title with the crimson full stop.
  Widget _head(AppLocalizations l10n) {
    final style = Lx.display(context, size: 28);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.reportsEyebrow.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.7)),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: l10n.reports),
            TextSpan(text: '.', style: style.copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
          ]),
          key: const ValueKey('lx-page-title'),
          style: style,
        ),
      ]),
    );
  }

  // Mockup `.chips` / `.chip`: the selected chip is a light pill with dark text.
  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(Lx.rPill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Lx.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(Lx.rPill),
            border: Border.all(color: active ? Lx.ink : Lx.line2),
          ),
          child: Text(label, style: Lx.text(context, size: 12, color: active ? const Color(0xFF111111) : Lx.muted)),
        ),
      ),
    );
  }

  Widget _periodChips(AppLocalizations l10n) {
    final periods = [
      ('all', l10n.all),
      ('month', l10n.reportsThisMonth),
      ('3months', l10n.reportsLast3Months),
      ('year', l10n.reportsThisYear),
      ('custom', l10n.reportsCustom),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: periods.map((p) {
            final active = _selectedPeriod == p.$1;
            return _chip(p.$2, active, () {
              if (p.$1 == 'custom') {
                setState(() {
                  _showCustomFilters = !_showCustomFilters;
                  _selectedPeriod = _showCustomFilters ? 'custom' : 'all';
                });
              } else {
                setState(() {
                  _selectedPeriod = p.$1;
                  _showCustomFilters = false;
                });
              }
              _load();
            });
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomFilterPanel() => buildReportsCustomFilterPanel(
    context: context,
    dateFrom: _dateFrom,
    dateTo: _dateTo,
    selectedClientId: _selectedClientId,
    selectedManagerId: _selectedManagerId,
    clientType: _clientType,
    clients: _clients,
    managers: _managers,
    onDateFromSelected: (d) { setState(() => _dateFrom = d); _load(); },
    onDateToSelected: (d) { setState(() => _dateTo = d); _load(); },
    onApply: () { _load(); },
    onClientSelected: (v) { setState(() => _selectedClientId = v); _load(); },
    onManagerSelected: (v) { setState(() => _selectedManagerId = v); _load(); },
    onTypeSelected: (v) { setState(() => _clientType = v); _load(); },
    onClearFilters: _clearFilters,
  );

  // Mockup `.kpi`: label (uppercase), serif value (+ small currency), hint.
  // The `act` one (needs action) gets the crimson border and crimson hint.
  Widget _kpi(String label, String value, String hint, {String unit = '', bool act = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1A19),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: act ? const Color(0x59941414) : Lx.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 1.6)),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: value, style: Lx.display(context, size: 26)),
                if (unit.isNotEmpty) TextSpan(text: ' $unit', style: Lx.text(context, size: 11, color: Lx.muted)),
              ]),
            ),
          ),
        ),
        Text(hint, style: Lx.text(context, size: 11.5, color: act ? Lx.crimsonInk : Lx.muted)),
      ]),
    );
  }

  Widget _kpiGrid(AppLocalizations l10n) {
    final c = _stats;
    final (_, _, revenueTotalsByCurrency, defaultRevenueCurrency) = _revenueByCurrency();
    final payments = _safeMap(c?['payments_by_month']);
    final fallbackRevenue = payments.values.fold<double>(0, (a, v) => a + _toDouble(v));
    // Mockup `.kpi .v`: the full grouped number ("79,500") + small currency.
    final revenueValue = lxFormatMoney(defaultRevenueCurrency != null
        ? revenueTotalsByCurrency[defaultRevenueCurrency]!
        : fallbackRevenue);
    final contracts = _safeMap(c?['contracts_by_status']);
    final totalContracts = contracts.values.fold<double>(0, (a, v) => a + _toDouble(v)).toInt();
    final pending = int.tryParse('${c?['pending_approvals'] ?? 0}') ?? 0;
    final tiles = [
      _kpi(l10n.reportsClients, '${c?['total_clients'] ?? 0}', l10n.reportsDeltaNew),
      _kpi(l10n.reportsRevenue, revenueValue, l10n.reportsDeltaMonth, unit: defaultRevenueCurrency ?? ''),
      _kpi(l10n.reportsContracts, '$totalContracts', l10n.reportsDeltaActive),
      _kpi(l10n.reportsPending, '$pending', l10n.reportsNeedsAction, act: true),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(children: [
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: tiles[0]), const SizedBox(width: 10), Expanded(child: tiles[1])])),
        const SizedBox(height: 10),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: tiles[2]), const SizedBox(width: 10), Expanded(child: tiles[3])])),
        const SizedBox(height: 12),
      ]),
    );
  }

  // Mockup monthly card: kind label + bars (last one crimson, rest line-2).
  Widget _monthlyCard(AppLocalizations l10n) {
    final payments = _safeMap(_stats?['payments_by_month']);
    final (byMonth, revenueCurrencies, _, defaultRevenueCurrency) = _revenueByCurrency();
    final activeRevenueCurrency =
        (_selectedRevenueCurrency != null && revenueCurrencies.contains(_selectedRevenueCurrency))
            ? _selectedRevenueCurrency
            : defaultRevenueCurrency;
    final Map<String, dynamic> chartData = activeRevenueCurrency != null
        ? {for (final e in byMonth.entries) e.key: e.value[activeRevenueCurrency] ?? 0}
        : payments;
    final entries = chartData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final take = _chartPeriod == '6m' ? 6 : 12;
    final shown = entries.length > take ? entries.sublist(entries.length - take) : entries;
    final maxV = shown.fold<double>(0, (m, e) => _toDouble(e.value) > m ? _toDouble(e.value) : m);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    String label(String key) {
      final parts = key.split('-');
      final m = parts.length >= 2 ? int.tryParse(parts[1]) : null;
      return (m != null && m >= 1 && m <= 12) ? months[m - 1] : key;
    }

    return LuxeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: LuxeKind(l10n.reportsMonthlyRevenue)),
          _miniChip(l10n.reportsPeriod6m, _chartPeriod == '6m', () => setState(() => _chartPeriod = '6m')),
          const SizedBox(width: 6),
          _miniChip(l10n.reportsPeriodYear, _chartPeriod == '1y', () => setState(() => _chartPeriod = '1y')),
        ]),
        if (revenueCurrencies.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final cur in revenueCurrencies) _miniChip(cur, cur == activeRevenueCurrency, () => setState(() => _selectedRevenueCurrency = cur)),
          ]),
        ],
        SizedBox(
          height: 140,
          child: shown.isEmpty || maxV <= 0
              ? Center(child: Text(l10n.managerDetailNoData, style: Lx.text(context, size: 12.5, color: Lx.faint)))
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Container(
                            height: (_toDouble(shown[i].value) / maxV * 100).clamp(2.0, 100.0),
                            decoration: BoxDecoration(
                              color: i == shown.length - 1 ? Lx.crimsonInk : Lx.line2,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(label(shown[i].key), style: Lx.text(context, size: 10, color: Lx.faint)),
                        ]),
                      ),
                    ],
                  ]),
                ),
        ),
      ]),
    );
  }

  Widget _miniChip(String label, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(Lx.rPill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: active ? Lx.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(Lx.rPill),
          border: Border.all(color: active ? Lx.ink : Lx.line2),
        ),
        child: Text(label, style: Lx.text(context, size: 10.5, color: active ? const Color(0xFF111111) : Lx.muted)),
      ),
    );
  }

  // Mockup `.split`: label | thin progress bar | count.
  Widget _splitRow(String label, double value, double total, {Color color = Lx.crimsonInk}) {
    final pct = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 110, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 12.5, color: Lx.ink2))),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: Lx.line2, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 20,
          child: Directionality(textDirection: TextDirection.ltr, child: Text('${value.toInt()}', textAlign: TextAlign.end, style: Lx.text(context, size: 12.5, color: Lx.ink2))),
        ),
      ]),
    );
  }

  Widget _statusCard(AppLocalizations l10n) {
    final contracts = _safeMap(_stats?['contracts_by_status']);
    final total = contracts.values.fold<double>(0, (a, v) => a + _toDouble(v));
    final labels = statusLabels(l10n);
    return LuxeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LuxeKind(l10n.reportsContractsByStatus),
        const SizedBox(height: 8),
        if (contracts.isEmpty)
          Text(l10n.managerDetailNoData, style: Lx.text(context, size: 12.5, color: Lx.faint))
        else
          for (final e in contracts.entries) _splitRow(labels[e.key] ?? e.key, _toDouble(e.value), total),
      ]),
    );
  }

  Widget _approvalsCard(AppLocalizations l10n) {
    final stats = _safeMap(_stats?['approval_stats']);
    final keys = ['approved', 'rejected', 'pending'];
    final names = [l10n.approved, l10n.rejected, l10n.pending];
    final values = keys.map((k) => _toDouble(stats[k])).toList();
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    return LuxeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LuxeKind(l10n.approvals),
        const SizedBox(height: 8),
        for (var i = 0; i < keys.length; i++) _splitRow(names[i], values[i], total, color: [Lx.ok, Lx.danger, Lx.wait][i]),
      ]),
    );
  }

  // Mockup ranking card: `.doc` rows — rank, name, revenue in serif.
  Widget _rankingCard(AppLocalizations l10n) {
    final useStats = _managerStats.isNotEmpty;
    // Only `name` is read when falling back to `_managers`; revenue then shows
    // "—" rather than a guessed number (see 21 Sept 2026 note in git history).
    final items = useStats ? _managerStats : _managers.map((m) => {'name': m.name}).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return LuxeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LuxeKind(l10n.reportsAmPerformance),
        const SizedBox(height: 6),
        for (var i = 0; i < items.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: i == items.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
            child: Row(children: [
              SizedBox(width: 18, child: Directionality(textDirection: TextDirection.ltr, child: Text('${i + 1}', style: Lx.text(context, size: 12.5, color: Lx.muted)))),
              Expanded(child: Text(items[i]['name'] as String? ?? l10n.reportsManagerFallback(i + 1), style: Lx.text(context, size: 13.5))),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(useStats ? lxFormatMoney(_toDouble(items[i]['revenue'])) : '—', style: Lx.display(context, size: 15)),
              ),
            ]),
          ),
      ]),
    );
  }
}
