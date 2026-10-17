import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/locale_provider.dart';
import '../../core/reverb_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/client_type_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_state.dart';
import '../../providers/auth_provider.dart';

/// A company staff member's home (STAFF_TEAMS_PLAN.md ف٦): just the clients
/// they are assigned to. Tapping one opens that client's workspace, which
/// shows chat, approval requests and meetings only. The backend returns only
/// assigned clients, so un-assigning removes a client on the next refresh.
class StaffDashboardPage extends StatefulWidget {
  final ApiClient? api;
  // Lets widget tests suppress the 60 s notification poll and the websocket.
  final bool enablePolling;
  final ReverbService? reverb;
  const StaffDashboardPage({super.key, this.api, this.enablePolling = true, this.reverb});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ReverbService _reverb = widget.reverb ?? ReverbService();
  final _searchController = TextEditingController();
  final List<VoidCallback> _reverbUnsubscribers = [];
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  bool _failed = false;
  int _page = 1;
  int _lastPage = 1;
  String _query = '';
  int _unread = 0;
  Timer? _debounce;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUnread();
    _setupRealtime();
    if (widget.enablePolling) {
      _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadUnread());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pollTimer?.cancel();
    _searchController.dispose();
    for (final unsub in _reverbUnsubscribers) {
      unsub();
    }
    super.dispose();
  }

  void _setupRealtime() {
    final uid = _api.userId;
    if (uid == null || !widget.enablePolling) return;
    _reverb.connectForUser(uid);
    _reverbUnsubscribers.add(_reverb.addNotificationReceivedListener((_) => _loadUnread()));
  }

  Future<void> _loadUnread() async {
    try {
      final res = await _api.get('/notifications');
      if (mounted) setState(() => _unread = int.tryParse(res['unread_count']?.toString() ?? '') ?? 0);
    } catch (e, s) {
      AppLog.error('staff_dashboard._loadUnread', e, s);
    }
  }

  Future<void> _load({int page = 1}) async {
    if (page == 1) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final q = _query.isEmpty ? '' : '&q=${Uri.encodeQueryComponent(_query)}';
      final res = await _api.get('/clients?page=$page$q');
      final paged = res['clients'];
      final rows = safeList(paged is Map ? paged['data'] : paged).whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() {
        _clients = page == 1 ? rows : [..._clients, ...rows];
        _page = page;
        _lastPage = (paged is Map ? int.tryParse('${paged['last_page'] ?? 1}') : null) ?? 1;
        _loading = false;
      });
    } catch (e, s) {
      AppLog.error('staff_dashboard._load', e, s);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = page == 1;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _query = value.trim();
      _load();
    });
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.logout)),
        ],
      ),
    );
    if (confirm != true) return;
    _reverb.disconnect();
    await AuthProvider().logout();
    if (!mounted) return;
    context.go('/login');
  }

  void _open(Map<String, dynamic> client) {
    final ws = client['workspace'] as Map<String, dynamic>?;
    final wsId = ws?['id'];
    if (wsId != null) context.push('/am/workspace/$wsId');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.staffMyClientsTitle),
        actions: [
          Stack(children: [
            IconButton(
              key: const ValueKey('staff-bell'),
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push('/notifications').then((_) => _loadUnread()),
            ),
            if (_unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: ShadColors.crimson, shape: BoxShape.circle),
                  child: Text(_unread > 99 ? '99+' : '$_unread', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
          IconButton(
            key: const ValueKey('staff-profile'),
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(icon: const Icon(Icons.language, size: 20), onPressed: () => context.read<LocaleProvider>().toggle()),
          IconButton(key: const ValueKey('staff-logout'), icon: const Icon(Icons.logout_rounded), onPressed: _logout, tooltip: l10n.logout),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            key: const ValueKey('staff-search'),
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 18), hintText: l10n.staffSearchHint),
          ),
        ),
        Expanded(child: _body(l10n)),
      ]),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_loading) return const LoadingState();
    if (_failed) return ErrorState(message: l10n.staffClientsLoadFailed, onRetry: _load);
    if (_clients.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.6, child: EmptyState(icon: Icons.people_outline, title: l10n.staffMyClientsEmpty)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final c in _clients) _clientCard(c),
          if (_page < _lastPage)
            Center(
              child: TextButton(
                key: const ValueKey('staff-load-more'),
                onPressed: () => _load(page: _page + 1),
                child: Text(l10n.auditLogNext),
              ),
            ),
        ],
      ),
    );
  }

  Widget _clientCard(Map<String, dynamic> c) {
    final name = (c['company_name'] as String?) ?? '';
    final contact = (c['contact_person'] as String?) ?? '';
    final avatar = c['avatar_url'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        key: ValueKey('staff-client-${c['id']}'),
        onTap: () => _open(c),
        leading: CircleAvatar(
          backgroundColor: ShadColors.crimson.withAlpha(40),
          backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(_api.resolveFileUrl(avatar)) : null,
          child: avatar != null && avatar.isNotEmpty
              ? null
              : Text(name.isEmpty ? '?' : name.substring(0, 1), style: const TextStyle(color: ShadColors.crimson, fontWeight: FontWeight.w700)),
        ),
        title: Row(children: [
          Flexible(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
          ClientTypeBadge(clientType: c['client_type'] as String?, compact: true),
        ]),
        subtitle: Text(contact, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
