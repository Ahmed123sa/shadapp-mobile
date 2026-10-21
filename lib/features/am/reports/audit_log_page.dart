import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../providers/audit_log_provider.dart';

class AuditLogPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with a mocked
  // AuditLogProvider instead of hitting the network.
  final AuditLogProvider? auditLogProvider;
  const AuditLogPage({super.key, this.auditLogProvider});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  late final AuditLogProvider _auditLogProvider = widget.auditLogProvider ?? AuditLogProvider();
  List<dynamic> _logs = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  String _searchQuery = '';
  String _actionFilter = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { if (_logs.isEmpty) _loading = true; _error = null; });
    try {
      final data = await _auditLogProvider.fetch(
        search: _searchQuery,
        action: _actionFilter,
        dateFrom: _dateFrom?.toIso8601String().substring(0, 10),
        dateTo: _dateTo?.toIso8601String().substring(0, 10),
        page: _page,
      );
      final paginated = data['logs'] as Map<String, dynamic>?;
      _logs = (paginated?['data'] as List<dynamic>?) ?? (data['logs'] as List<dynamic>?) ?? [];
      _totalPages = paginated?['last_page'] as int? ?? 1;
      _total = paginated?['total'] as int? ?? _logs.length;
    } on ServerException catch (e) {
      _error = e.message;
    } catch (_) {
      if (mounted) _error = AppLocalizations.of(context)!.errorOccurred;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _debouncedLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _goToPage(int p) {
    if (p < 1 || p > _totalPages) return;
    setState(() => _page = p);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget content;
    if (_loading) {
      content = const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: Lx.crimsonInk)));
    } else if (_error != null) {
      content = _buildError();
    } else if (_logs.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Text(l10n.auditLogNoEvents, style: Lx.display(context, size: 20)),
          const SizedBox(height: 8),
          Text(l10n.auditLogNoActivities, textAlign: TextAlign.center, style: Lx.text(context, size: 13.5, color: Lx.muted)),
        ]),
      );
    } else {
      content = Column(children: [..._buildGroupedLogs(), _buildPagination()]);
    }
    final h1 = Lx.display(context, size: 28).copyWith(height: 1.2);
    return Scaffold(
      backgroundColor: Lx.page,
      appBar: AppBar(
        backgroundColor: Lx.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Lx.muted),
        title: const SizedBox.shrink(),
      ),
      body: RefreshIndicator(
        onRefresh: () async { _page = 1; await _load(); },
        color: Lx.crimsonInk,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 18),
          children: [
            // Mockup pAudit: head('Record', 'Audit log') — the event count is
            // the lead line.
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.auditEyebrow.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.73)),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: l10n.auditLogTitle),
                    TextSpan(text: '.', style: h1.copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
                  ]),
                  key: const ValueKey('lx-page-title'),
                  style: h1,
                ),
                const SizedBox(height: 8),
                Text(l10n.auditLogEventCount(_total), style: Lx.text(context, size: 13, color: Lx.muted)),
              ]),
            ),
            _buildSearchBar(),
            _buildFilterChips(),
            _buildDateFilter(),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Text(_error!, textAlign: TextAlign.center, style: Lx.text(context, size: 14, color: Lx.danger)),
        const SizedBox(height: 16),
        LuxeButton(label: AppLocalizations.of(context)!.auditLogRetry, onPressed: _load),
      ]),
    );
  }

  List<Widget> _buildGroupedLogs() {
    final l10n = AppLocalizations.of(context)!;
    final grouped = <String, List<Map<String, dynamic>>>{};
    final dateFormat = <String, String>{};

    for (final log in _logs) {
      if (log is! Map) continue;
      final createdAt = log['created_at'] as String? ?? '';
      final dateKey = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
      final dt = DateTime.tryParse(createdAt);
      String displayDate = dateKey;
      if (dt != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final logDate = DateTime(dt.year, dt.month, dt.day);
        final diff = today.difference(logDate).inDays;
        if (diff == 0) {
          displayDate = '${l10n.auditLogToday}, ${_formatDate(dt)}';
        } else if (diff == 1) {
          displayDate = '${l10n.auditLogYesterday}, ${_formatDate(dt)}';
        } else {
          displayDate = _formatDate(dt);
        }
      }
      dateFormat[dateKey] = displayDate;
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(log.cast<String, dynamic>());
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final widgets = <Widget>[];

    for (final key in sortedKeys) {
      widgets.add(_buildDateDivider(dateFormat[key] ?? key));
      widgets.addAll(grouped[key]!.map((log) => _auditLogTile(log)));
    }

    return widgets;
  }

  String _formatDate(DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final months = [l10n.auditLogMonthJanuary, l10n.auditLogMonthFebruary, l10n.auditLogMonthMarch, l10n.auditLogMonthApril, l10n.auditLogMonthMay, l10n.auditLogMonthJune, l10n.auditLogMonthJuly, l10n.auditLogMonthAugust, l10n.auditLogMonthSeptember, l10n.auditLogMonthOctober, l10n.auditLogMonthNovember, l10n.auditLogMonthDecember];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  /// Mockup `.day`: 10px (.24em) uppercase faint label between hairlines.
  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Row(children: [
        const Expanded(child: Divider(height: 1, thickness: 1, color: Lx.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.4)),
        ),
        const Expanded(child: Divider(height: 1, thickness: 1, color: Lx.line)),
      ]),
    );
  }

  /// Mockup `.srch`.
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line)),
      child: Row(children: [
        const LxIcon('search', size: 18, color: Lx.faint),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            style: Lx.text(context, size: 12.5),
            cursorColor: Lx.crimsonInk,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: AppLocalizations.of(context)!.auditLogSearch,
              hintStyle: Lx.text(context, size: 12.5, color: Lx.faint),
            ),
            onChanged: (v) {
              _searchQuery = v;
              _page = 1;
              _debouncedLoad();
            },
          ),
        ),
      ]),
    );
  }

  /// Mockup `.chips` / `.chip` (all the real filters are kept).
  Widget _buildFilterChips() {
    final l10n = AppLocalizations.of(context)!;
    final chips = [
      ('', l10n.auditLogFilterAll),
      ('contract', l10n.auditLogFilterContracts),
      ('payment', l10n.auditLogFilterPayments),
      ('approval', l10n.auditLogFilterApprovals),
      ('meeting', l10n.auditLogFilterMeetings),
      ('login', l10n.auditLogFilterLogins),
      ('client', l10n.auditLogFilterClients),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((c) {
            final active = _actionFilter == c.$1;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _actionFilter = c.$1;
                  _page = 1;
                });
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                margin: const EdgeInsetsDirectional.only(end: 8),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFF0F0F0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(Lx.rPill),
                  border: Border.all(color: active ? const Color(0xFFF0F0F0) : Lx.line2),
                ),
                child: Text(c.$2, style: Lx.text(context, size: 12, color: active ? const Color(0xFF111111) : Lx.muted)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Expanded(child: _dateField(l10n.auditLogFrom, _dateFrom, (d) { setState(() => _dateFrom = d); _page = 1; _load(); })),
        const SizedBox(width: 8),
        Expanded(child: _dateField(l10n.auditLogTo, _dateTo, (d) { setState(() => _dateTo = d); _page = 1; _load(); })),
      ]),
    );
  }

  /// Date pill in the `.chip` outline with the mockup's calendar icon.
  Widget _dateField(String label, DateTime? value, Function(DateTime) onSelect) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: value != null ? Lx.ink2 : Lx.line2)),
        child: Row(children: [
          const LxIcon('cal', size: 15, color: Lx.faint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value != null ? '${value.day}/${value.month}/${value.year}' : label,
              style: Lx.text(context, size: 12, color: value != null ? Lx.ink : Lx.muted),
            ),
          ),
        ]),
      ),
    );
  }

  /// 20 Sept 2026 — audit_logs.user_id is a foreign key into `users`, so it
  /// only ever holds a staff id. Every action taken by a client or a
  /// sub-user therefore arrives here with `user: null`, and this tile used
  /// to read nothing but `log['user']['name']` — so all of those rows
  /// rendered with a blank actor and a '?' avatar.
  ///
  /// That is not a small subset: it covers every `sub_user.*` row, a
  /// contract approved or edit-requested by a client/sub-user, and (since
  /// AuthController started recording logins) every client and sub-user
  /// login. In other words the audit log showed no name against most
  /// client-side activity.
  ///
  /// The backend eager-loads `client` alongside `user` on exactly these
  /// rows for this reason (AuditController::index), and the dashboard has
  /// always walked the same fallback chain — this brings mobile in line
  /// with it rather than inventing a different one.
  String _actorName(Map<String, dynamic> log) {
    final user = log['user'] as Map<String, dynamic>?;
    final staffName = user?['name'] as String?;
    if (staffName != null && staffName.isNotEmpty) return staffName;

    final client = log['client'] as Map<String, dynamic>?;
    final companyName = client?['company_name'] as String?;
    if (companyName != null && companyName.isNotEmpty) return companyName;

    final contactPerson = client?['contact_person'] as String?;
    if (contactPerson != null && contactPerson.isNotEmpty) return contactPerson;

    return '';
  }

  /// Mockup pAudit card: `.st2` (crimson dot + action), then "who · what"
  /// (12.5 muted, margin-top 6), then the time.
  Widget _auditLogTile(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? '';
    final createdAt = log['created_at'] as String? ?? '';
    final userName = _actorName(log);
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    final time = dt == null ? createdAt : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final what = _entityText(action);
    final sub = [userName, if (what != action) what].where((e) => e.isNotEmpty).join(' · ');
    return LuxeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const LuxeStatusDot(status: LxStatus.bad),
          const SizedBox(width: 7),
          Expanded(child: Text(_auditLabel(action), style: Lx.text(context, size: 12, color: Lx.ink2))),
        ]),
        if (sub.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(sub, style: Lx.text(context, size: 12.5, color: Lx.muted)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(time, textDirection: TextDirection.ltr, style: Lx.text(context, size: 12.5, color: Lx.muted)),
        ),
      ]),
    );
  }

  String _entityText(String action) {
    final l10n = AppLocalizations.of(context)!;
    if (action.startsWith('contract.')) return l10n.auditLogTypeContract;
    if (action.startsWith('payment.')) return l10n.auditLogTypePayment;
    if (action.startsWith('client.')) return l10n.auditLogTypeClient;
    if (action.startsWith('approval.')) return l10n.auditLogTypeApproval;
    if (action.startsWith('meeting.')) return l10n.auditLogTypeMeeting;
    if (action.startsWith('login')) return l10n.auditLogTypeLogin;
    if (action.startsWith('file.')) return l10n.auditLogTypeFile;
    if (action.startsWith('workspace.')) return l10n.auditLogTypeSpace;
    return action;
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pageButton(AppLocalizations.of(context)!.auditLogPrevious, _page > 1, () => _goToPage(_page - 1)),
          const SizedBox(width: 6),
          ..._pageNumbers(),
          const SizedBox(width: 6),
          _pageButton(AppLocalizations.of(context)!.auditLogNext, _page < _totalPages, () => _goToPage(_page + 1)),
        ],
      ),
    );
  }

  List<Widget> _pageNumbers() {
    final widgets = <Widget>[];
    // With fewer than 3 pages `clamp(0, totalPages - 3)` has its bounds
    // reversed and throws "Invalid argument: 0" (the red error screen).
    final maxStart = _totalPages > 3 ? _totalPages - 3 : 0;
    final start = (_page - 1).clamp(0, maxStart);
    final end = (start + 3).clamp(0, _totalPages < 0 ? 0 : _totalPages);
    for (int i = start; i < end; i++) {
      final p = i + 1;
      widgets.add(Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: _pageButton('$p', true, () => _goToPage(p), active: _page == p),
      ));
    }
    if (end < _totalPages) {
      widgets.add(Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: Text('…$_totalPages', style: Lx.text(context, size: 12, color: Lx.faint)),
      ));
    }
    return widgets;
  }

  Widget _pageButton(String label, bool enabled, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF0F0F0) : Colors.transparent,
          borderRadius: BorderRadius.circular(Lx.rPill),
          border: Border.all(color: active ? const Color(0xFFF0F0F0) : Lx.line2),
        ),
        child: Text(label, style: Lx.text(context, size: 12, color: active ? const Color(0xFF111111) : enabled ? Lx.muted : Lx.faint)),
      ),
    );
  }

  String _auditLabel(String action) {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      'contract.created': l10n.auditLogActionCreateContract,
      'contract.sent': l10n.auditLogActionSendContract,
      'contract.client_approved': l10n.auditLogActionClientApprove,
      'contract.client_rejected': l10n.auditLogActionClientReject,
      'contract.edit_requested': l10n.auditLogActionRequestEdit,
      'contract.company_approved': l10n.auditLogActionCompanyApprove,
      'contract.completed': l10n.auditLogActionCompleteContract,
      'contract.archived': l10n.auditLogActionArchiveContract,
      'workspace.created': l10n.auditLogActionCreateSpace,
      'workspace.activated': l10n.auditLogActionActivateSpace,
      'approval.created': l10n.auditLogActionCreateApproval,
      'approval.approved': l10n.auditLogActionApproved,
      'approval.rejected': l10n.auditLogActionRejected,
      'approval.edit_requested': l10n.auditLogActionRequestEditApproval,
      'payment.submitted': l10n.auditLogActionSubmitPayment,
      'payment.approved': l10n.auditLogActionApprovePayment,
      'payment.rejected': l10n.auditLogActionRejectPayment,
      'file.uploaded': l10n.auditLogActionUploadFile,
      'file.approved': l10n.auditLogActionApproveFile,
      'file.rejected': l10n.auditLogActionRejectFile,
      'login': l10n.auditLogActionLogin,
      'meeting.created': l10n.auditLogActionCreateMeeting,
      'meeting.updated': l10n.auditLogActionUpdateMeeting,
      'client.created': l10n.auditLogActionCreateClient,
      'client.deleted': l10n.auditLogActionDeleteClient,
    };
    return labels[action] ?? action;
  }
}
