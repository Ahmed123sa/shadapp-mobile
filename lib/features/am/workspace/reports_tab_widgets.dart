// Extracted from reports_tab.dart (بند ٨: تقسيم الملفات فوق ٨٠٠ سطر) —
// pure(-ish) widget builders that don't need direct access to
// _ReportsTabState's private fields beyond what's passed in explicitly.
// Byte-identical logic to what used to live inline in reports_tab.dart.
//
// The custom-filter-panel builder keeps the same "caller owns the
// setState+_load() pairing" shape the original code already had for
// _buildDateChip/_buildDropdown (both already took an `onSelect` callback
// parameter before this extraction) — _typeChip and the two "apply/clear"
// buttons are the only pieces that used to reach into instance state
// directly, and now take the same kind of callback instead.
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../models/client.dart';
import '../../../models/manager.dart';

double _toDouble(dynamic value) => num.tryParse(value?.toString() ?? '')?.toDouble() ?? 0;

Widget reportsEmptyChart() {
  return const Center(
    child: Icon(Icons.bar_chart, color: ShadColors.textDisabled, size: 36),
  );
}

Widget buildRevenueLineChart(BuildContext context, Map<String, dynamic> data, String chartPeriod) {
  final l10n = AppLocalizations.of(context)!;
  final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final total = entries.length;
  final slice = chartPeriod == '6m' ? total > 6 ? entries.sublist(total - 6) : entries : entries;
  if (slice.isEmpty) return reportsEmptyChart();
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

Widget buildContractsChartBody(BuildContext context, Map<String, dynamic> contracts) {
  final l10n = AppLocalizations.of(context)!;
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

  return Column(
    children: [
      SizedBox(
        height: 130,
        child: entries.isEmpty
            ? reportsEmptyChart()
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
  );
}

// Returns null when there's no approval data at all — the caller
// (reports_tab.dart's _buildApprovalsChart) uses that to skip rendering the
// whole section (title included), matching the original early-return.
Widget? buildApprovalsChartBody(BuildContext context, Map<String, dynamic> approvalStats) {
  final l10n = AppLocalizations.of(context)!;
  final labels = ['approved', 'rejected', 'pending'];
  final displayLabels = [l10n.approved, l10n.rejected, l10n.pending];
  final colors = [ShadColors.success, ShadColors.error, ShadColors.gold];
  final data = labels.map((k) => _toDouble(approvalStats[k])).toList();
  if (data.every((v) => v == 0)) return null;

  return SizedBox(
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
  );
}

Widget buildReportKpiCard((String, String, String, Color, String, bool) k) {
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

Widget buildReportsCustomFilterPanel({
  required BuildContext context,
  required DateTime? dateFrom,
  required DateTime? dateTo,
  required int? selectedClientId,
  required int? selectedManagerId,
  required String? clientType,
  required List<Client> clients,
  required List<Manager> managers,
  required void Function(DateTime) onDateFromSelected,
  required void Function(DateTime) onDateToSelected,
  required VoidCallback onApply,
  required void Function(dynamic) onClientSelected,
  required void Function(dynamic) onManagerSelected,
  required void Function(String?) onTypeSelected,
  required VoidCallback onClearFilters,
}) {
  final l10n = AppLocalizations.of(context)!;
  return Container(
    padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: ShadColors.divider)),
    ),
    child: Column(
      children: [
        Row(children: [
          _dateChip(context, l10n.auditLogFrom, dateFrom, onDateFromSelected),
          const SizedBox(width: 8),
          _dateChip(context, l10n.auditLogTo, dateTo, onDateToSelected),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onApply,
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
          Expanded(child: _dropdown(
            context, selectedClientId, l10n.reportsClient, l10n.reportsAllClients,
            clients.map((c) => MapEntry<dynamic, String>(c.id, c.companyName)).toList(),
            onClientSelected,
          )),
          const SizedBox(width: 8),
          Expanded(child: _dropdown(
            context, selectedManagerId, l10n.reportsManager, l10n.reportsAllManagers,
            managers.map((m) => MapEntry<dynamic, String>(m.id, m.name)).toList(),
            onManagerSelected,
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _typeChip(l10n.all, null, clientType == null, () => onTypeSelected(null)),
          const SizedBox(width: 6),
          _typeChip(l10n.clientTypeCompany, 'business', clientType == 'business', () => onTypeSelected('business')),
          const SizedBox(width: 6),
          _typeChip(l10n.clientTypeIndividual, 'individual', clientType == 'individual', () => onTypeSelected('individual')),
          const Spacer(),
          GestureDetector(
            onTap: onClearFilters,
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

Widget _dateChip(BuildContext context, String label, DateTime? value, void Function(DateTime) onSelect) {
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

Widget _dropdown(BuildContext context, dynamic selected, String label, String hint, List<MapEntry<dynamic, String>> items, void Function(dynamic) onSelect) {
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

Widget _typeChip(String label, String? value, bool active, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
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
