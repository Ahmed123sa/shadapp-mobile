import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/widgets/loading_state.dart';
import '../reports/audit_log_page.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  double _toDouble(dynamic value) => num.tryParse(value?.toString() ?? '')?.toDouble() ?? 0;
  String? _error;

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return {};
  }

  String _selectedPeriod = 'all';
  bool _showCustomFilters = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int? _selectedClientId;
  String? _clientType;
  int? _selectedManagerId;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _managers = [];
  List<Map<String, dynamic>> _managerStats = [];
  String _chartPeriod = '1y';

  @override
  void initState() {
    super.initState();
    _load();
    _loadClients();
    _loadManagers();
  }

  String _buildFilterQuery() {
    final params = <String, String>{};
    if (_selectedPeriod == 'month') {
      final now = DateTime.now();
      params['date_from'] = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
      params['date_to'] = now.toIso8601String().substring(0, 10);
    } else if (_selectedPeriod == '3months') {
      final now = DateTime.now();
      params['date_from'] = DateTime(now.year, now.month - 2, 1).toIso8601String().substring(0, 10);
      params['date_to'] = now.toIso8601String().substring(0, 10);
    } else if (_selectedPeriod == 'year') {
      final now = DateTime.now();
      params['date_from'] = DateTime(now.year, 1, 1).toIso8601String().substring(0, 10);
      params['date_to'] = now.toIso8601String().substring(0, 10);
    } else if (_selectedPeriod == 'custom') {
      if (_dateFrom != null) params['date_from'] = _dateFrom!.toIso8601String().substring(0, 10);
      if (_dateTo != null) params['date_to'] = _dateTo!.toIso8601String().substring(0, 10);
    }
    if (_selectedClientId != null) params['client_id'] = _selectedClientId.toString();
    if (_clientType != null) params['client_type'] = _clientType!;
    if (_selectedManagerId != null) params['manager_id'] = _selectedManagerId.toString();
    if (params.isEmpty) return '';
    return '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
  }

  Future<void> _loadClients() async {
    try {
      final data = await _api.get('/clients');
      final list = safeList(data['clients']);
      _clients = list.cast<Map<String, dynamic>>();
    } catch (_) {}
  }

  Future<void> _loadManagers() async {
    try {
      final data = await _api.get('/account-managers');
      final list = data['managers'] as List<dynamic>? ?? [];
      _managers = list.cast<Map<String, dynamic>>();
    } catch (_) {}
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
      final query = _buildFilterQuery();
      final reportsResult = await _api.get('/reports$query').catchError((e) {
        return <String, dynamic>{'error': true, 'message': e.toString()};
      });
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
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: ShadColors.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: ShadTypography.cardBody.copyWith(color: ShadColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: Text(AppLocalizations.of(context)!.retry)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildAppBar(),
        _buildFilterChips(),
        if (_selectedPeriod == 'custom' && _showCustomFilters) _buildCustomFilterPanel(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildKpiScroll(),
                const Divider(height: 1, color: ShadColors.divider),
                _buildRevenueChart(),
                _buildContractsChart(),
                _buildApprovalsChart(),
                _buildAmLeaderboard(),
                _buildAuditLogLink(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 14, top: 10, bottom: 10),
      decoration: const BoxDecoration(
        color: ShadColors.surfaceDarker,
        border: Border(bottom: BorderSide(color: ShadColors.divider)),
      ),
      child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios, size: 16, color: ShadColors.textSecondary),
            ),
            const SizedBox(width: 4),
          const Text('d', style: TextStyle(
            fontFamily: 'Playfair Display', fontSize: 15, fontStyle: FontStyle.italic, color: ShadColors.textPrimary,
          )),
          Container(
            width: 4, height: 4,
            margin: const EdgeInsetsDirectional.only(bottom: 1, start: 4),
            decoration: const BoxDecoration(color: ShadColors.crimson, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.reports, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ShadColors.textPrimary)),
                Text(AppLocalizations.of(context)!.reportsLast30Days, style: const TextStyle(fontSize: 9, color: ShadColors.textSecondary)),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final l10n = AppLocalizations.of(context)!;
    final periods = [
      ('all', l10n.all),
      ('month', l10n.reportsThisMonth),
      ('3months', l10n.reportsLast3Months),
      ('year', l10n.reportsThisYear),
      ('custom', l10n.reportsCustom),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShadColors.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: periods.map((p) {
            final active = _selectedPeriod == p.$1;
            return GestureDetector(
              onTap: () {
                if (p.$1 == 'custom') {
                  setState(() {
                    _showCustomFilters = !_showCustomFilters;
                    _selectedPeriod = _showCustomFilters ? 'custom' : 'all';
                  });
                  _load();
                } else {
                  setState(() {
                    _selectedPeriod = p.$1;
                    _showCustomFilters = false;
                  });
                  _load();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                margin: const EdgeInsetsDirectional.only(end: 6),
                decoration: BoxDecoration(
                  color: active ? ShadColors.crimsonSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? ShadColors.crimsonBorder : ShadColors.borderLight),
                ),
                child: Text(p.$2, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: active ? ShadColors.textPrimary : ShadColors.textSecondary,
                )),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomFilterPanel() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShadColors.divider)),
      ),
      child: Column(
        children: [
          Row(children: [
            _buildDateChip(l10n.auditLogFrom, _dateFrom, (d) { setState(() => _dateFrom = d); _load(); }),
            const SizedBox(width: 8),
            _buildDateChip(l10n.auditLogTo, _dateTo, (d) { setState(() => _dateTo = d); _load(); }),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () { _load(); },
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: ShadColors.crimsonSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadColors.crimsonBorder),
                ),
                child: const Icon(Icons.check, size: 14, color: ShadColors.crimson),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildDropdown(
              _selectedClientId, l10n.reportsClient, l10n.reportsAllClients,
              _clients.map((c) => MapEntry<dynamic, String>(c['id'], (c['company_name'] as String?) ?? '')).toList(),
              (v) { setState(() => _selectedClientId = v); _load(); },
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildDropdown(
              _selectedManagerId, l10n.reportsManager, l10n.reportsAllManagers,
              _managers.map((m) => MapEntry<dynamic, String>(m['id'], (m['name'] as String?) ?? '')).toList(),
              (v) { setState(() => _selectedManagerId = v); _load(); },
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _typeChip(l10n.all, null),
            const SizedBox(width: 6),
            _typeChip(l10n.clientTypeCompany, 'business'),
            const SizedBox(width: 6),
            _typeChip(l10n.clientTypeIndividual, 'individual'),
            const Spacer(),
            GestureDetector(
              onTap: _clearFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadColors.borderLight),
                ),
                child: Text(l10n.reportsReset, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, DateTime? value, Function(DateTime) onSelect) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: ShadColors.gold)),
              child: child!,
            ),
          );
          if (picked != null) onSelect(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: ShadColors.surfaceDarker,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ShadColors.borderLight),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 12, color: ShadColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              value != null ? '${value.day}/${value.month}/${value.year}' : label,
              style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildDropdown(dynamic selected, String label, String hint, List<MapEntry<dynamic, String>> items, Function(dynamic) onSelect) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
              ),
              ListTile(
                title: Text(hint, style: const TextStyle(fontSize: 12)),
                trailing: selected == null ? const Icon(Icons.check, size: 16, color: ShadColors.gold) : null,
                onTap: () { onSelect(null); Navigator.pop(ctx); },
              ),
              ...items.map((e) => ListTile(
                title: Text(e.value, style: const TextStyle(fontSize: 12)),
                trailing: selected == e.key ? const Icon(Icons.check, size: 16, color: ShadColors.gold) : null,
                onTap: () { onSelect(e.key); Navigator.pop(ctx); },
              )),
            ]),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ShadColors.surfaceDarker,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ShadColors.borderLight),
        ),
        child: Row(children: [
          Icon(Icons.person, size: 12, color: ShadColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              selected != null
                  ? items.firstWhere((e) => e.key == selected, orElse: () => MapEntry(null, selected.toString())).value
                  : hint,
              style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 16, color: ShadColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _typeChip(String label, String? value) {
    final active = _clientType == value;
    return GestureDetector(
      onTap: () { setState(() => _clientType = value); _load(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? ShadColors.goldSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? ShadColors.gold : ShadColors.borderLight),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          color: active ? ShadColors.gold : ShadColors.textSecondary,
        )),
      ),
    );
  }

  Widget _buildKpiScroll() {
    final l10n = AppLocalizations.of(context)!;
    final c = _stats;
    final totalClients = '${c?['total_clients'] ?? 0}';
    final payments = _safeMap(c?['payments_by_month']);
    final totalRevenue = payments.isEmpty ? '0' : '${payments.values.map((v) => _toDouble(v)).reduce((a, b) => a + b).toInt()}';
    final contracts = _safeMap(c?['contracts_by_status']);
    final totalContracts = '${contracts.values.map((v) => _toDouble(v)).reduce((a, b) => a + b).toInt()}';
    final pendingApprovals = '${c?['pending_approvals'] ?? 0}';
    final activeWorkspaces = '${c?['active_workspaces'] ?? 0}';

    final kpis = [
      _kpiData('clients', l10n.reportsClients, totalClients, ShadColors.success, l10n.reportsDeltaNew, true),
      _kpiData('revenue', l10n.reportsRevenue, totalRevenue.length > 3 ? '${totalRevenue.substring(0, totalRevenue.length - 3)}K' : totalRevenue, ShadColors.gold, l10n.reportsDeltaMonth, true),
      _kpiData('contracts', l10n.reportsContracts, totalContracts, ShadColors.blue, l10n.reportsDeltaActive, true),
      _kpiData('pending', l10n.reportsPending, pendingApprovals, ShadColors.error, l10n.reportsNeedsAction, false),
      _kpiData('workspaces', l10n.reportsWorkspaces, activeWorkspaces, ShadColors.purple, l10n.reportsDeltaActivated, true),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: kpis.map((k) => _kpiCard(k)).toList(),
        ),
      ),
    );
  }

  _kpiData(String kind, String label, String value, Color accent, String delta, bool isUp) {
    return (kind, label, value, accent, delta, isUp);
  }

  Widget _kpiCard((String, String, String, Color, String, bool) k) {
    final (kind, label, value, accent, delta, isUp) = k;
    return Container(
      width: 110,
      margin: const EdgeInsetsDirectional.only(end: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9.5, color: ShadColors.textSecondary)),
              const SizedBox(height: 5),
              Text(value, style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: kind == 'revenue' ? 16 : 20,
                fontWeight: FontWeight.w700,
                color: kind == 'pending' ? ShadColors.error : ShadColors.textPrimary,
              )),
              const SizedBox(height: 4),
              Text(delta, style: TextStyle(
                fontSize: 9,
                color: isUp ? ShadColors.success : ShadColors.error,
              )),
            ],
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(height: 2, decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    final l10n = AppLocalizations.of(context)!;
    final payments = _safeMap(_stats?['payments_by_month']);
    return _chartSection(
      title: l10n.reportsMonthlyRevenue,
      subtitle: l10n.reportsAcceptedPaymentsTotal,
      periodTabs: true,
      child: SizedBox(
        height: 130,
        child: payments.isEmpty
            ? _emptyChart()
            : _revenueLineChart(payments),
      ),
    );
  }

  Widget _revenueLineChart(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final total = entries.length;
    final slice = _chartPeriod == '6m' ? total > 6 ? entries.sublist(total - 6) : entries : entries;
    if (slice.isEmpty) return _emptyChart();
    final flatSpots = slice.asMap().entries.map((e) => FlSpot(e.key.toDouble(), _toDouble(e.value.value))).toList();

    return LineChart(LineChartData(
      lineBarsData: [LineChartBarData(
        spots: flatSpots, isCurved: true, color: ShadColors.crimson, barWidth: 2, curveSmoothness: 0.4,
        belowBarData: BarAreaData(show: true, color: ShadColors.crimson.withAlpha(20)),
        dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
          FlDotCirclePainter(radius: 3, color: ShadColors.gold, strokeWidth: 0)),
      )],
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 20, interval: 1,
          getTitlesWidget: (v, _) {
            final idx = v.toInt();
            if (idx < 0 || idx >= slice.length) return const SizedBox();
            final parts = slice[idx].key.split('-');
            final monthNames = [l10n.monthJanuary, l10n.monthFebruary, l10n.monthMarch, l10n.monthApril, l10n.monthMay, l10n.monthJune, l10n.monthJuly, l10n.monthAugust, l10n.monthSeptember, l10n.monthOctober, l10n.monthNovember, l10n.monthDecember];
            final m = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
            final name = monthNames[m - 1];
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(name.length <= 2 ? name : name.substring(0, 2), style: const TextStyle(color: ShadColors.textMuted, fontSize: 9)),
            );
          },
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
          getTitlesWidget: (v, _) => Text('${v.toInt() ~/ 1000}k', style: const TextStyle(color: ShadColors.textMuted, fontSize: 9)))),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (flatSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) / 4).ceilToDouble()),
    ));
  }

  Widget _buildContractsChart() {
    final l10n = AppLocalizations.of(context)!;
    final contracts = _safeMap(_stats?['contracts_by_status']);
    final statusOrder = ['completed', 'sent', 'client_approved', 'company_approved', 'draft', 'archived', 'client_rejected', 'edit_requested'];
    final entries = statusOrder.where((s) => contracts.containsKey(s) && _toDouble(contracts[s]) > 0).map((s) => MapEntry(s, _toDouble(contracts[s]))).toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    final contractColors = {
      'completed': ShadColors.success,
      'sent': ShadColors.blue,
      'client_approved': ShadColors.gold,
      'company_approved': ShadColors.purple,
      'draft': ShadColors.textMuted,
      'archived': ShadColors.orange,
      'client_rejected': ShadColors.error,
      'edit_requested': ShadColors.warning,
    };

    return _chartSection(
      title: l10n.reportsContractsByStatus,
      subtitle: l10n.reportsCurrentDistribution,
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: entries.isEmpty
                ? _emptyChart()
                : PieChart(PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 44,
                    sections: entries.asMap().entries.map((e) => PieChartSectionData(
                      value: e.value.value,
                      color: contractColors[e.value.key] ?? ShadColors.textMuted,
                      radius: 40,
                      title: '${(e.value.value / total * 100).toInt()}%',
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    )).toList(),
                  )),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 6,
            mainAxisSpacing: 2,
            crossAxisSpacing: 4,
            children: entries.map((e) {
              final labelMap = {
                'completed': l10n.completed, 'sent': l10n.sent, 'client_approved': l10n.clientApproved,
                'company_approved': l10n.companyApproved, 'draft': l10n.draft, 'archived': l10n.archived,
                'client_rejected': l10n.rejected, 'edit_requested': l10n.editRequestedStatus,
              };
              return Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                  color: contractColors[e.key] ?? ShadColors.textMuted, shape: BoxShape.circle,
                )),
                const SizedBox(width: 5),
                Text('${labelMap[e.key] ?? e.key} (${e.value.toInt()})', style: const TextStyle(fontSize: 9.5, color: ShadColors.textSecondary)),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalsChart() {
    final l10n = AppLocalizations.of(context)!;
    final approvalStats = _safeMap(_stats?['approval_stats']);
    final labels = ['approved', 'rejected', 'pending'];
    final displayLabels = [l10n.approved, l10n.rejected, l10n.pending];
    final colors = [ShadColors.success, ShadColors.error, ShadColors.gold];
    final data = labels.map((k) => _toDouble(approvalStats[k])).toList();
    if (data.every((v) => v == 0)) return const SizedBox.shrink();

    return _chartSection(
      title: l10n.approvals,
      subtitle: '${l10n.approved} / ${l10n.rejected} / ${l10n.pending}',
      child: SizedBox(
        height: 130,
        child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: data.reduce((a, b) => a > b ? a : b) * 1.3,
          barTouchData: BarTouchData(enabled: true, touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
              BarTooltipItem('${data[groupIndex].toInt()}', const TextStyle(color: Colors.white, fontSize: 11)),
          )),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= displayLabels.length) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(displayLabels[idx], style: const TextStyle(color: ShadColors.textMuted, fontSize: 9)));
              }, reservedSize: 24,
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: ShadColors.textMuted, fontSize: 9)))),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          barGroups: data.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(toY: e.value, color: colors[e.key], width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
          ])).toList(),
        )),
      ),
    );
  }

  Widget _buildAmLeaderboard() {
    final l10n = AppLocalizations.of(context)!;
    final useStats = _managerStats.isNotEmpty;
    final items = useStats
        ? _managerStats
        : _managers;
    if (items.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: l10n.reportsAmPerformance,
      icon: '🏆',
      child: Container(
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ShadColors.cardBorder),
        ),
        child: Column(
          children: List.generate(items.length > 3 ? 3 : items.length, (i) {
            final item = items[i];
            final name = item['name'] as String? ?? l10n.reportsManagerFallback(i + 1);
            final initials = name.length >= 2 ? name.substring(0, 2) : name[0];
            final revenue = useStats
                ? '${_toDouble(item['revenue']).toInt()}'
                : '${_toDouble(_stats?['payments_by_month']?.values?.fold(0, (a, b) => _toDouble(a) + _toDouble(b)) ?? 0) ~/ (items.length - i + 1)}';
            final pct = useStats
                ? (_toDouble(item['revenue']) / _toDouble(items.first['revenue']) * 100).clamp(10, 100)
                : (100 - i * 15).clamp(10, 100);
            final rankColors = [
              (ShadColors.goldSoft, ShadColors.gold, ShadColors.gold),
              (const Color(0x1EC0C0C0), const Color(0xFFC0C0C0), const Color(0xFFC0C0C0)),
              (const Color(0x1ECD7F32), const Color(0xFFCD7F32), const Color(0xFFCD7F32)),
            ];
            final (bgColor, borderColor, textColor) = i < 3 ? rankColors[i] : (ShadColors.cardBorder, ShadColors.cardBorder, ShadColors.textSecondary);
            final isLast = i == (items.length > 3 ? 2 : items.length - 1);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: ShadColors.cardBorder)),
              ),
              child: Row(children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor))),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: ShadColors.crimsonSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: ShadColors.crimsonBorder),
                  ),
                  child: Center(child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ShadColors.gold))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
                      const SizedBox(height: 4),
                      Container(height: 3, decoration: BoxDecoration(
                        color: ShadColors.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ), child: FractionallySizedBox(
                        widthFactor: pct / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: i == 0 ? ShadColors.crimson : (i == 1 ? ShadColors.purple : ShadColors.blue),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
                Text(revenue, style: const TextStyle(
                  fontFamily: 'Playfair Display', fontSize: 12, color: ShadColors.gold, fontWeight: FontWeight.w600,
                )),
              ]),
            );
          }),
        ),
      ),
    );
  }

  Widget _chartSection({
    required String title,
    String? subtitle,
    bool periodTabs = false,
    required Widget child,
  }) {
    return _buildSection(
      title: title,
      subtitle: subtitle,
      extra: periodTabs ? _buildChartTabs() : null,
      child: Container(
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ShadColors.cardBorder),
        ),
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }

  Widget _buildChartTabs() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _ctBtn(l10n.reportsPeriod6m, '6m', _chartPeriod == '6m'),
        const SizedBox(width: 4),
        _ctBtn(l10n.reportsPeriodYear, '1y', _chartPeriod == '1y'),
      ],
    );
  }

  Widget _ctBtn(String label, String value, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() => _chartPeriod = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? ShadColors.crimsonSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? ShadColors.crimsonBorder : ShadColors.borderLight),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 9.5, color: active ? ShadColors.textPrimary : ShadColors.textSecondary,
        )),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    String? icon,
    Widget? extra,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Text(icon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
              ],
              Text(title, style: const TextStyle(
                fontFamily: 'Playfair Display', fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.textPrimary,
              )),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
              ],
              const Spacer(),
              if (extra != null) extra,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildAuditLogLink() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 18, 14, 0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AuditLogPage()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ShadColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ShadColors.cardBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.history, size: 16, color: ShadColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(AppLocalizations.of(context)!.auditLogTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ShadColors.crimsonSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ShadColors.crimsonBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context)!.amViewAll, style: const TextStyle(fontSize: 10, color: ShadColors.textPrimary)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 8, color: ShadColors.textPrimary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyChart() {
    return const Center(
      child: Icon(Icons.bar_chart, color: ShadColors.textDisabled, size: 36),
    );
  }
}
