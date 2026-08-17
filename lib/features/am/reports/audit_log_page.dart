import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _api = ApiClient();
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
      final params = <String, String>{};
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (_actionFilter.isNotEmpty) params['action'] = _actionFilter;
      if (_dateFrom != null) params['date_from'] = _dateFrom!.toIso8601String().substring(0, 10);
      if (_dateTo != null) params['date_to'] = _dateTo!.toIso8601String().substring(0, 10);
      params['page'] = _page.toString();

      final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final data = await _api.get('/audit-logs?$qs');
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildSearchBar(),
            _buildFilterChips(),
            _buildDateFilter(),
            Expanded(
              child: _loading
                  ? const LoadingState()
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: () async { _page = 1; await _load(); },
                          child: _logs.isEmpty
                              ? ListView(children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.3,
                                    child: EmptyState(icon: Icons.history, title: AppLocalizations.of(context)!.auditLogNoEvents, subtitle: AppLocalizations.of(context)!.auditLogNoActivities),
                                  ),
                                ])
                              : ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    ..._buildGroupedLogs(),
                                    _buildPagination(),
                                  ],
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: ShadColors.error, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: ShadTypography.cardBody.copyWith(color: ShadColors.error)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: Text(AppLocalizations.of(context)!.auditLogRetry)),
        ],
      ),
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

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 4),
      child: Row(
        children: [
          Expanded(child: Container(height: 0.5, color: ShadColors.borderLight)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label, style: const TextStyle(fontSize: 9.5, color: ShadColors.textMuted)),
          ),
          Expanded(child: Container(height: 0.5, color: ShadColors.borderLight)),
        ],
      ),
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
                Text(AppLocalizations.of(context)!.auditLogTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ShadColors.textPrimary)),
                Text(AppLocalizations.of(context)!.auditLogEventCount(_total), style: const TextStyle(fontSize: 9, color: ShadColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShadColors.divider)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: ShadColors.surfaceDarker,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ShadColors.borderLight),
        ),
        child: Row(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 7),
            Expanded(
              child: TextField(
                style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary),
                decoration: InputDecoration.collapsed(
                  hintText: AppLocalizations.of(context)!.auditLogSearch,
                  hintStyle: const TextStyle(color: ShadColors.textMuted, fontSize: 12),
                ),
                onChanged: (v) {
                  _searchQuery = v;
                  _page = 1;
                  _debouncedLoad();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShadColors.divider)),
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                margin: const EdgeInsetsDirectional.only(end: 6),
                decoration: BoxDecoration(
                  color: active ? ShadColors.crimsonSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? ShadColors.crimsonBorder : ShadColors.borderLight),
                ),
                child: Text(c.$2, style: TextStyle(
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

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShadColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(child: _dateField(AppLocalizations.of(context)!.auditLogFrom, _dateFrom, (d) { setState(() => _dateFrom = d); _page = 1; _load(); })),
          const SizedBox(width: 6),
          Expanded(child: _dateField(AppLocalizations.of(context)!.auditLogTo, _dateTo, (d) { setState(() => _dateTo = d); _page = 1; _load(); })),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, Function(DateTime) onSelect) {
    return GestureDetector(
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ShadColors.surfaceDarker,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ShadColors.borderLight),
        ),
        child: Text(
          value != null ? '${value.day}/${value.month}/${value.year}' : label,
          style: const TextStyle(fontSize: 11, color: ShadColors.textMuted),
        ),
      ),
    );
  }

  Widget _auditLogTile(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? '';
    final createdAt = log['created_at'] as String? ?? '';
    final user = log['user'] as Map<String, dynamic>?;
    final userName = user?['name'] as String? ?? '';
    final initials = userName.length >= 2 ? userName.substring(0, 2) : (userName.isNotEmpty ? userName[0] : '?');
    final time = createdAt.length >= 16 ? createdAt.substring(11, 16) : createdAt;
    final (dotColor, badgeColor, badgeText) = _actionStyle(action);
    final avatarColors = _userAvatarColors(userName);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 14, 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9, height: 9,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_auditLabel(action), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badgeText, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: avatarColors.$1,
                        shape: BoxShape.circle,
                        border: Border.all(color: avatarColors.$2),
                      ),
                      child: Center(child: Text(initials, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: avatarColors.$3))),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      userName.isNotEmpty ? '$userName • $time' : time,
                      style: const TextStyle(fontSize: 10, color: ShadColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, String) _actionStyle(String action) {
    final prefix = action.split('.').firstOrNull ?? action;
    switch (prefix) {
      case 'contract':
        return (ShadColors.blue, ShadColors.blue.withAlpha(30), _entityText(action));
      case 'payment':
        return (ShadColors.gold, ShadColors.goldSoft, _entityText(action));
      case 'client':
        return (ShadColors.success, ShadColors.success.withAlpha(25), _entityText(action));
      case 'approval':
        return (ShadColors.purple, ShadColors.purple.withAlpha(30), _entityText(action));
      case 'login':
        return (ShadColors.orange, ShadColors.orange.withAlpha(25), _entityText(action));
      case 'meeting':
        return (ShadColors.crimson, ShadColors.crimsonSoft, _entityText(action));
      case 'file':
        return (ShadColors.blue, ShadColors.blue.withAlpha(25), _entityText(action));
      case 'workspace':
        return (ShadColors.purple, ShadColors.purple.withAlpha(25), _entityText(action));
      default:
        return (ShadColors.textSecondary, ShadColors.cardBorder, action);
    }
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

  (Color, Color, Color) _userAvatarColors(String name) {
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final palettes = [
      (ShadColors.crimsonSoft, ShadColors.crimsonBorder, ShadColors.gold),
      (ShadColors.purple.withAlpha(30), ShadColors.purple.withAlpha(80), ShadColors.purple),
      (ShadColors.blue.withAlpha(30), ShadColors.blue.withAlpha(80), ShadColors.blue),
      (ShadColors.success.withAlpha(25), ShadColors.success.withAlpha(60), ShadColors.success),
      (ShadColors.orange.withAlpha(25), ShadColors.orange.withAlpha(60), ShadColors.orange),
      (ShadColors.goldSoft, ShadColors.goldBorder, ShadColors.gold),
    ];
    return palettes[hash % palettes.length];
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ShadColors.divider)),
      ),
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
    final start = (_page - 1).clamp(0, _totalPages - 3);
    final end = (start + 3).clamp(0, _totalPages);
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
        child: Text('…$_totalPages', style: const TextStyle(fontSize: 10, color: ShadColors.textMuted)),
      ));
    }
    return widgets;
  }

  Widget _pageButton(String label, bool enabled, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? ShadColors.crimsonSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: active ? ShadColors.crimsonBorder : ShadColors.borderLight),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, color: enabled ? (active ? ShadColors.textPrimary : ShadColors.textSecondary) : ShadColors.textMuted,
        )),
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
