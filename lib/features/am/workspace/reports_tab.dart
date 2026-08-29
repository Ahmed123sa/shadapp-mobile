import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../models/client.dart';
import '../../../models/manager.dart';
import '../../../providers/client_provider.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/report_provider.dart';
import '../reports/audit_log_page.dart';
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
          children: kpis.map((k) => buildReportKpiCard(k)).toList(),
        ),
      ),
    );
  }

  _kpiData(String kind, String label, String value, Color accent, String delta, bool isUp) {
    return (kind, label, value, accent, delta, isUp);
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
            ? reportsEmptyChart()
            : buildRevenueLineChart(context, payments, _chartPeriod),
      ),
    );
  }

  Widget _buildContractsChart() {
    final l10n = AppLocalizations.of(context)!;
    final contracts = _safeMap(_stats?['contracts_by_status']);
    return _chartSection(
      title: l10n.reportsContractsByStatus,
      subtitle: l10n.reportsCurrentDistribution,
      child: buildContractsChartBody(context, contracts),
    );
  }

  Widget _buildApprovalsChart() {
    final l10n = AppLocalizations.of(context)!;
    final approvalStats = _safeMap(_stats?['approval_stats']);
    final body = buildApprovalsChartBody(context, approvalStats);
    if (body == null) return const SizedBox.shrink();
    return _chartSection(
      title: l10n.approvals,
      subtitle: '${l10n.approved} / ${l10n.rejected} / ${l10n.pending}',
      child: body,
    );
  }

  Widget _buildAmLeaderboard() {
    final l10n = AppLocalizations.of(context)!;
    final useStats = _managerStats.isNotEmpty;
    // Only `name` is read from `items` when falling back to `_managers`
    // (the `revenue`/pct branches below all check `useStats` first), so a
    // minimal map preserves the original bracket-access shape here without
    // needing a second typed code path.
    final items = useStats
        ? _managerStats
        : _managers.map((m) => {'name': m.name}).toList();
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
              (ShadColors.silverSoft, ShadColors.silver, ShadColors.silver),
              (ShadColors.bronzeSoft, ShadColors.bronze, ShadColors.bronze),
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
}
