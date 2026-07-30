import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_state.dart';

class CalendarTab extends StatefulWidget {
  final int? workspaceId;
  const CalendarTab({super.key, this.workspaceId});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<dynamic> _extractList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map && raw['data'] is List) return raw['data'] as List;
    return [];
  }

  Future<void> _load() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    setState(() => _loading = true);
    _events = [];
    try {
      final meetingsData = await _api.get('/workspaces/$wsId/meetings');
      for (final m in _extractList(meetingsData['meetings'])) {
        _events.add({
          'id': m['id'],
          'title': m['title'],
          'type': 'meeting',
          'status': m['status'],
          'date': m['scheduled_at'],
          'duration': m['duration'],
          'notes': m['notes'],
          'link': m['link'],
        });
      }
    } catch (e) {
      debugPrint('Calendar: failed to load meetings: $e');
    }

    try {
      final contractsData = await _api.get('/workspaces/$wsId/contracts');
      for (final c in _extractList(contractsData['contracts'])) {
        if (c['start_date'] != null) {
          _events.add({
            'id': c['id'],
            'title': 'بداية: ${c['title']}',
            'type': 'contract_start',
            'status': c['status'],
            'date': c['start_date'],
            'ref': c['reference_no'],
          });
        }
        if (c['end_date'] != null) {
          _events.add({
            'id': c['id'],
            'title': 'نهاية: ${c['title']}',
            'type': 'contract_deadline',
            'status': c['status'],
            'date': c['end_date'],
            'ref': c['reference_no'],
          });
        }
      }
    } catch (e) {
      debugPrint('Calendar: failed to load contracts: $e');
    }

    try {
      final paymentsData = await _api.get('/workspaces/$wsId/payments');
      for (final p in _extractList(paymentsData['payments'])) {
        if (p['created_at'] != null) {
          _events.add({
            'id': p['id'],
            'title': 'دفعة: ${double.tryParse(p['amount']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'} ${p['currency'] ?? 'SAR'}',
            'type': 'payment',
            'status': p['status'],
            'date': p['created_at'],
            'ref': p['method_type'] ?? '',
          });
        }
      }
    } catch (e) {
      debugPrint('Calendar: failed to load payments: $e');
    }

    try {
      final approvalsData = await _api.get('/workspaces/$wsId/approvals');
      for (final a in _extractList(approvalsData['approvals'])) {
        if (a['created_at'] != null) {
          _events.add({
            'id': a['id'],
            'title': 'موافقة: ${a['title']}',
            'type': 'approval',
            'status': a['status'],
            'date': a['created_at'],
            'ref': a['reference_no'],
          });
        }
      }
    } catch (e) {
      debugPrint('Calendar: failed to load approvals: $e');
    }

    _events.sort((a, b) {
      final da = DateTime.tryParse(a['date'] ?? '')?.toLocal();
      final db = DateTime.tryParse(b['date'] ?? '')?.toLocal();
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });

    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _events;
    return _events.where((e) => e['type'] == _filter || (_filter == 'contract' && (e['type'] == 'contract_start' || e['type'] == 'contract_deadline'))).toList();
  }

  String _formatDate(String? dt) {
    if (dt == null) return '';
    try {
      final parsed = DateTime.parse(dt).toLocal();
      final weekdays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
      final wd = weekdays[parsed.weekday % 7];
      return '$wd، ${parsed.year}/${parsed.month}/${parsed.day}';
    } catch (_) { return dt; }
  }

  Map<String, List<Map<String, dynamic>>> get _groupedByDate {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in _filtered) {
      final date = _formatDate(e['date']);
      map.putIfAbsent(date, () => []).add(e);
    }
    return map;
  }

  Color _eventColor(dynamic e) {
    switch (e['type']) {
      case 'meeting': return ShadColors.primary;
      case 'contract_start': return ShadColors.success;
      case 'contract_deadline': return ShadColors.error;
      case 'approval': return const Color(0xFF9C27B0);
      case 'payment': return ShadColors.gold;
      default: return ShadColors.textSecondary;
    }
  }

  IconData _eventIcon(dynamic e) {
    switch (e['type']) {
      case 'meeting': return Icons.videocam;
      case 'contract_start': return Icons.play_circle;
      case 'contract_deadline': return Icons.warning_rounded;
      case 'approval': return Icons.check_circle;
      case 'payment': return Icons.payments;
      default: return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip('كل الأحداث', 'all'),
            const SizedBox(width: 8),
            _filterChip('اجتماعات', 'meeting'),
            const SizedBox(width: 8),
            _filterChip('مدفوعات', 'payment'),
            const SizedBox(width: 8),
            _filterChip('موافقات', 'approval'),
          ]),
        ),
      ),
      // Legend
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          _legendDot(ShadColors.primary, 'اجتماع'),
          const SizedBox(width: 12),
          _legendDot(ShadColors.success, 'بداية عقد'),
          const SizedBox(width: 12),
          _legendDot(ShadColors.error, 'نهاية عقد'),
          const SizedBox(width: 12),
          _legendDot(ShadColors.gold, 'دفعة'),
          const SizedBox(width: 12),
          _legendDot(const Color(0xFF9C27B0), 'موافقة'),
        ]),
      ),
      Expanded(
        child: _events.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_month_outlined, size: 56, color: ShadColors.textDisabled),
              const SizedBox(height: 12),
              Text('لا توجد أحداث', style: ShadTypography.emptyTitle),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _groupedByDate.entries.map((entry) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.key, style: ShadTypography.sectionHeader),
                    const SizedBox(height: 8),
                    ...entry.value.map((e) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _eventColor(e).withAlpha(25),
                          child: Icon(_eventIcon(e), size: 18, color: _eventColor(e)),
                        ),
                        title: Text(e['title'] ?? '', style: ShadTypography.cardTitle),
                        subtitle: Text(_formatDate(e['date']), style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary)),
                      ),
                    )),
                    const SizedBox(height: 12),
                  ]);
                }).toList(),
              ),
            ),
      ),
    ]);
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
    ]);
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}
