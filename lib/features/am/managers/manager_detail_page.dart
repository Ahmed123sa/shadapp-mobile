import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class ManagerDetailPage extends StatefulWidget {
  final int managerId;
  const ManagerDetailPage({super.key, required this.managerId});

  @override
  State<ManagerDetailPage> createState() => _ManagerDetailPageState();
}

class _ManagerDetailPageState extends State<ManagerDetailPage> {
  final _api = ApiClient();
  Map<String, dynamic>? _manager;
  Map<String, dynamic>? _stats;
  List<dynamic> _clients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final managerFuture = _api.get('/account-managers/${widget.managerId}');
      final statsFuture = _api.get('/account-managers/${widget.managerId}/stats');
      final results = await Future.wait([managerFuture, statsFuture]);
      final managerData = results[0];
      final statsData = results[1];
      _manager = managerData['manager'] as Map<String, dynamic>?;
      _clients = (managerData['clients'] as List<dynamic>?) ?? [];
      _stats = statsData;
    } catch (e) {
      if (!mounted) return;
      _error = AppLocalizations.of(context)!.dataLoadFailed;
    }
    if (mounted) setState(() => _loading = false);
  }

  double _toDouble(dynamic v) => num.tryParse(v?.toString() ?? '')?.toDouble() ?? 0;

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return {};
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final l10n = AppLocalizations.of(context)!;
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: ShadColors.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: ShadColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: Text(l10n.retry)),
          ]),
        ),
      );
    }

    final name = _manager?['name'] as String? ?? '';
    final email = _manager?['email'] as String? ?? '';
    final phone = _manager?['phone'] as String?;
    final avatarUrl = _manager?['avatar_url'] as String?;
    final initials = name.isNotEmpty ? name.substring(0, name.length.clamp(0, 2)).toUpperCase() : '?';
    final clientsCount = _stats?['clients_count'] ?? 0;
    final totalRevenue = _toDouble(_stats?['total_revenue']);
    final activeWorkspaces = _stats?['active_workspaces'] ?? 0;
    final pendingPayments = _stats?['pending_payments'] ?? 0;
    final contractsByStatus = _safeMap(_stats?['contracts_by_status']);
    final paymentsByMonth = _safeMap(_stats?['payments_by_month']);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(name, style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: ShadColors.crimson,
                backgroundImage: avatarUrl != null ? NetworkImage(_api.resolveFileUrl(avatarUrl)) : null,
                child: avatarUrl == null ? Text(initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')) : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay', color: ShadColors.textPrimary))),
            const SizedBox(height: 4),
            Center(child: Text(email, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo'), textDirection: TextDirection.ltr)),
            if (phone != null && phone.isNotEmpty)
              Center(child: Text(phone, style: const TextStyle(fontSize: 11, color: ShadColors.textDisabled, fontFamily: 'Archivo'), textDirection: TextDirection.ltr)),
            const SizedBox(height: 20),

            _sectionLabel(l10n.managerDetailStats),
            Row(children: [
              _statCard(l10n.managerDetailClients, '$clientsCount', ShadColors.sent),
              const SizedBox(width: 8),
              _statCard(l10n.managerDetailActiveSpaces, '$activeWorkspaces', ShadColors.success),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _statCard(l10n.managerDetailTotalIncome, _formatCurrency(totalRevenue), ShadColors.gold),
              const SizedBox(width: 8),
              _statCard(l10n.managerDetailPendingPayments, '$pendingPayments', ShadColors.warning),
            ]),
            const SizedBox(height: 20),

            if (contractsByStatus.isNotEmpty) ...[
              _sectionLabel(l10n.managerDetailContractsByStatus),
              const SizedBox(height: 8),
              ...contractsByStatus.entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ShadColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _statusColor(e.key), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_statusLabel(e.key, l10n), style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary, fontFamily: 'Archivo'))),
                  Text('${e.value}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _statusColor(e.key), fontFamily: 'PlayfairDisplay')),
                ]),
              )),
              const SizedBox(height: 20),
            ],

            if (paymentsByMonth.isNotEmpty) ...[
              _sectionLabel(l10n.managerDetailMonthlyIncome),
              const SizedBox(height: 8),
              SizedBox(height: 180, child: _paymentsChart(paymentsByMonth, l10n)),
              const SizedBox(height: 20),
            ],

            if (_clients.isNotEmpty) ...[
              _sectionLabel(l10n.managerDetailClientsWithCount(_clients.length)),
              const SizedBox(height: 8),
              ..._clients.map((c) {
                final cName = c['company_name'] as String? ?? '';
                final person = c['contact_person'] as String? ?? '';
                final ws = c['workspace'] as Map<String, dynamic>?;
                final wsActive = ws?['status'] == 'active';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ShadColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ShadColors.cardBorder),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: ShadColors.crimson.withAlpha(30),
                      child: Text(cName.isNotEmpty ? cName.substring(0, 1).toUpperCase() : '?',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ShadColors.gold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                        Text(person, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (wsActive ? ShadColors.success : ShadColors.textDisabled).withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(wsActive ? l10n.managerDetailActive : l10n.managerDetailInactive,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: wsActive ? ShadColors.success : ShadColors.textDisabled)),
                    ),
                  ]),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, color: ShadColors.textDisabled, letterSpacing: 1.2, fontWeight: FontWeight.w500)),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ShadColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color, fontFamily: 'PlayfairDisplay')),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        ]),
      ),
    );
  }

  Widget _paymentsChart(Map<String, dynamic> data, AppLocalizations l10n) {
    final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return Center(child: Text(l10n.managerDetailNoData, style: const TextStyle(color: ShadColors.textDisabled)));
    final spots = entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), _toDouble(e.value.value))).toList();

    return LineChart(LineChartData(
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true, color: ShadColors.gold, barWidth: 2,
        belowBarData: BarAreaData(show: true, color: ShadColors.gold.withValues(alpha: 0.1)),
        dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 2, color: ShadColors.gold, strokeWidth: 0)),
      )],
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28, interval: 1,
          getTitlesWidget: (v, _) {
            final idx = v.toInt();
            if (idx < 0 || idx >= entries.length) return const SizedBox();
            final parts = entries[idx].key.split('-');
            final label = parts.length >= 2 ? '${parts[1]}/${parts[0].substring(2)}' : entries[idx].key;
            return Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: const TextStyle(color: ShadColors.textSecondary, fontSize: 9)));
          },
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: ShadColors.textDisabled, fontSize: 10)))),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false),
    ));
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  Color _statusColor(String status) {
    return statusColors[status] ?? ShadColors.textSecondary;
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    final labels = {
      'draft': l10n.draft, 'sent': l10n.sent, 'client_approved': l10n.clientApproved,
      'company_approved': l10n.companyApproved, 'completed': l10n.completed, 'archived': l10n.archived,
      'client_rejected': l10n.rejected, 'edit_requested': l10n.editRequestedStatus,
    };
    return labels[status] ?? status;
  }
}
