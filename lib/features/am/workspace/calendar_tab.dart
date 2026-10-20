import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/error_state.dart';
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
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    setState(() { _loading = true; _error = null; });
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
      // 24 Sept 2026 - start/end dates are optional (and the "show contract
      // dates" setting can hide them), so a contract with neither never
      // appeared here. It now shows once, on the day it was signed off or,
      // failing that, created - the same rule as the web calendar.
      if (c['start_date'] == null && c['end_date'] == null) {
        final fallback = c['company_signed_at'] ?? c['created_at'];
        if (fallback != null) {
          _events.add({
            'id': c['id'],
            'title': '${l10n.calendarContract}: ${c['title']}',
            'type': 'contract',
            'status': c['status'],
            'date': fallback,
            'ref': c['reference_no'],
          });
        }
      }
    }

    // Assistants never see money — the endpoint refuses them anyway.
    if (!_api.isAssistant) await _paymentProvider.fetchForWorkspace(wsId);
    for (final p in (_api.isAssistant ? const [] : _paymentProvider.payments)) {
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

    // 24 Sept 2026 - each provider swallows its own fetch error, so a failed
    // section used to just come out empty with no message, looking like
    // there was nothing to show. Any failure now shows the error state with
    // a retry, the same as the web calendar.
    final failed = [_meetingProvider.error, _contractProvider.error, _paymentProvider.error, _approvalProvider.error]
        .any((e) => e != null);
    if (mounted) {
      setState(() {
        _loading = false;
        if (failed) _error = l10n.dataLoadFailed;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _events;
    return _events.where((e) => e['type'] == _filter || (_filter == 'contract' && (e['type'] == 'contract_start' || e['type'] == 'contract_deadline' || e['type'] == 'contract'))).toList();
  }

  String _formatDate(String? dt, AppLocalizations l10n) {
    if (dt == null) return '';
    try {
      final parsed = DateTime.parse(dt).toLocal();
      final weekdays = [l10n.weekdaySunday, l10n.weekdayMonday, l10n.weekdayTuesday, l10n.weekdayWednesday, l10n.weekdayThursday, l10n.weekdayFriday, l10n.weekdaySaturday];
      final wd = weekdays[parsed.weekday % 7];
      // The generated signature is alphabetical: (day, month, weekday, year).
      return l10n.calendarDateFormat(parsed.day, parsed.month, wd, parsed.year);
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
      case 'meeting': return Lx.crimsonInk;
      case 'contract_start': return Lx.ok;
      case 'contract_deadline': return Lx.danger;
      case 'contract': return Lx.muted;
      case 'approval': return Lx.tuscan;
      case 'payment': return Lx.wait;
      default: return Lx.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final l10n = AppLocalizations.of(context)!;

    final groups = _groupedByDate(l10n).entries.toList();
    return RefreshIndicator(
      onRefresh: _load,
      color: Lx.crimsonInk,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 28),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip(l10n.calendarAllEvents, 'all'),
              _filterChip(l10n.calendarMeetings, 'meeting'),
              _filterChip(l10n.calendarPayments, 'payment'),
              _filterChip(l10n.calendarApprovals, 'approval'),
            ]),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 14, runSpacing: 6, children: [
            _legendDot(Lx.crimsonInk, l10n.calendarMeeting),
            _legendDot(Lx.ok, l10n.calendarContractStartLegend),
            _legendDot(Lx.danger, l10n.calendarContractEndLegend),
            _legendDot(Lx.wait, l10n.calendarPayment),
            _legendDot(Lx.tuscan, l10n.calendarApproval),
          ]),
          const SizedBox(height: 14),
          if (_events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text(l10n.calendarEmpty, style: Lx.display(context, size: 20))),
            ),
          for (final entry in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: LuxeKind(entry.key),
            ),
            for (final e in entry.value)
              LuxeCard(
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _eventColor(e), shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${e['title'] ?? ''}', style: Lx.text(context, size: 15)),
                      const SizedBox(height: 2),
                      Text(_formatDate(e['date'], l10n), style: Lx.text(context, size: 12, color: Lx.muted)),
                    ]),
                  ),
                ]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: Lx.text(context, size: 11, color: Lx.muted)),
    ]);
  }

  // Mockup `.chip`: selected = light fill with dark text.
  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(Lx.rPill),
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Lx.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(Lx.rPill),
            border: Border.all(color: selected ? Lx.ink : Lx.line2),
          ),
          child: Text(label, style: Lx.text(context, size: 12, color: selected ? const Color(0xFF111111) : Lx.muted)),
        ),
      ),
    );
  }
}
