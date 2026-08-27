import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../providers/approval_provider.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/meeting_provider.dart';
import '../../../providers/payment_provider.dart';

class CalendarTab extends StatefulWidget {
  final int? workspaceId;
  // Optional so this screen can be pumped in a widget test with mocked
  // providers instead of hitting the network.
  final MeetingProvider? meetingProvider;
  final ContractProvider? contractProvider;
  final PaymentProvider? paymentProvider;
  final ApprovalProvider? approvalProvider;
  final ApiClient? api;
  const CalendarTab({
    super.key,
    this.workspaceId,
    this.meetingProvider,
    this.contractProvider,
    this.paymentProvider,
    this.approvalProvider,
    this.api,
  });

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final MeetingProvider _meetingProvider = widget.meetingProvider ?? MeetingProvider();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider();
  late final PaymentProvider _paymentProvider = widget.paymentProvider ?? PaymentProvider();
  late final ApprovalProvider _approvalProvider = widget.approvalProvider ?? ApprovalProvider();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    setState(() => _loading = true);
    _events = [];

    await _meetingProvider.fetchForWorkspace(wsId);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    for (final m in _meetingProvider.meetings) {
      _events.add({
        'id': m.id,
        'title': m.title,
        'type': 'meeting',
        'status': m.status,
        'date': m.scheduledAt,
      });
    }

    await _contractProvider.fetchContracts(wsId);
    for (final c in _contractProvider.contracts) {
      if (c['start_date'] != null) {
        _events.add({
          'id': c['id'],
          'title': '${l10n.calendarStart}: ${c['title']}',
          'type': 'contract_start',
          'status': c['status'],
          'date': c['start_date'],
          'ref': c['reference_no'],
        });
      }
      if (c['end_date'] != null) {
        _events.add({
          'id': c['id'],
          'title': '${l10n.calendarEnd}: ${c['title']}',
          'type': 'contract_deadline',
          'status': c['status'],
          'date': c['end_date'],
          'ref': c['reference_no'],
        });
      }
    }

    await _paymentProvider.fetchForWorkspace(wsId);
    for (final p in _paymentProvider.payments) {
      if (p['created_at'] != null) {
        _events.add({
          'id': p['id'],
          'title': '${l10n.calendarPayment}: ${double.tryParse(p['amount']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'} ${p['currency'] ?? 'SAR'}',
          'type': 'payment',
          'status': p['status'],
          'date': p['created_at'],
          'ref': p['method_type'] ?? '',
        });
      }
    }

    await _approvalProvider.fetchApprovals(wsId);
    for (final a in _approvalProvider.approvals) {
      if (a.createdAt != null) {
        _events.add({
          'id': a.id,
          'title': '${l10n.calendarApproval}: ${a.title}',
          'type': 'approval',
          'status': a.status,
          'date': a.createdAt,
          'ref': a.referenceNo,
        });
      }
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

  String _formatDate(String? dt, AppLocalizations l10n) {
    if (dt == null) return '';
    try {
      final parsed = DateTime.parse(dt).toLocal();
      final weekdays = [l10n.weekdaySunday, l10n.weekdayMonday, l10n.weekdayTuesday, l10n.weekdayWednesday, l10n.weekdayThursday, l10n.weekdayFriday, l10n.weekdaySaturday];
      final wd = weekdays[parsed.weekday % 7];
      return l10n.calendarDateFormat(wd, parsed.year, parsed.month, parsed.day);
    } catch (_) { return dt; }
  }

  Map<String, List<Map<String, dynamic>>> _groupedByDate(AppLocalizations l10n) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in _filtered) {
      final date = _formatDate(e['date'], l10n);
      map.putIfAbsent(date, () => []).add(e);
    }
    return map;
  }

  Color _eventColor(dynamic e) {
    switch (e['type']) {
      case 'meeting': return ShadColors.primary;
      case 'contract_start': return ShadColors.success;
      case 'contract_deadline': return ShadColors.error;
      case 'approval': return ShadColors.calendarMeeting;
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
    final l10n = AppLocalizations.of(context)!;

    return Column(children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip(l10n.calendarAllEvents, 'all'),
            const SizedBox(width: 8),
            _filterChip(l10n.calendarMeetings, 'meeting'),
            const SizedBox(width: 8),
            _filterChip(l10n.calendarPayments, 'payment'),
            const SizedBox(width: 8),
            _filterChip(l10n.calendarApprovals, 'approval'),
          ]),
        ),
      ),
      // Legend
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
        child: Row(children: [
          _legendDot(ShadColors.primary, l10n.calendarMeeting),
          const SizedBox(width: 12),
          _legendDot(ShadColors.success, l10n.calendarContractStartLegend),
          const SizedBox(width: 12),
          _legendDot(ShadColors.error, l10n.calendarContractEndLegend),
          const SizedBox(width: 12),
          _legendDot(ShadColors.gold, l10n.calendarPayment),
          const SizedBox(width: 12),
          _legendDot(ShadColors.calendarMeeting, l10n.calendarApproval),
        ]),
      ),
      Expanded(
        child: _events.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_month_outlined, size: 56, color: ShadColors.textDisabled),
              const SizedBox(height: 12),
              Text(l10n.calendarEmpty, style: ShadTypography.emptyTitle),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _groupedByDate(l10n).entries.map((entry) {
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
                        subtitle: Text(_formatDate(e['date'], l10n), style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary)),
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
