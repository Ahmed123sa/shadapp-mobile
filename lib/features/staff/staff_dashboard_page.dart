import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/locale_provider.dart';
import '../../core/reverb_service.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/client_card.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
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

  String _avatarInitial() {
    final n = (_api.userName ?? '').trim();
    return n.isEmpty ? '?' : n.substring(0, 1).toUpperCase();
  }

  void _showMenu() {
    final loc = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showLuxeSheet<void>(context, builder: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            LuxeAvatar(initial: _avatarInitial()),
            const SizedBox(width: 12),
            Expanded(child: Text(_api.userName ?? '', style: Lx.display(context, size: 18))),
          ]),
        ),
        LuxeMoreRow(
          key: const ValueKey('staff-profile'),
          lxIcon: 'gear',
          label: loc.amNavSettings,
          onTap: () {
            Navigator.pop(ctx);
            context.push('/profile');
          },
        ),
        LuxeMoreRow(
          key: const ValueKey('staff-language'),
          lxIcon: 'lang',
          label: isAr ? 'English' : 'العربية',
          onTap: () {
            Navigator.pop(ctx);
            context.read<LocaleProvider>().toggle();
          },
        ),
        LuxeMoreRow(
          key: const ValueKey('staff-logout'),
          lxIcon: 'out',
          label: loc.logout,
          danger: true,
          last: true,
          onTap: () {
            Navigator.pop(ctx);
            _logout();
          },
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Lx.page,
      body: SafeArea(
        bottom: false,
        child: LuxeGlow(
          child: Column(children: [
            LuxeTopBar(
              company: l10n.amRoleStaff,
              avatarInitial: _avatarInitial(),
              unread: _unread > 0,
              onBell: () => context.push('/notifications').then((_) => _loadUnread()),
              onAvatar: _showMenu,
            ),
            Expanded(child: _body(l10n)),
          ]),
        ),
      ),
      bottomNavigationBar: LuxeBottomNav(
        items: [
          LuxeNavItem(id: 'clients', lxIcon: 'users', label: l10n.staffMyClientsTitle),
          LuxeNavItem(id: 'settings', lxIcon: 'gear', label: l10n.amNavSettings),
        ],
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) context.push('/profile');
        },
      ),
    );
  }

  Widget _search(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line)),
      child: Row(children: [
        const Icon(Icons.search, size: 18, color: Lx.faint),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            key: const ValueKey('staff-search'),
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: Lx.text(context, size: 12.5),
            cursorColor: Lx.crimsonInk,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintText: l10n.staffSearchHint,
              hintStyle: Lx.text(context, size: 12.5, color: Lx.faint),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _body(AppLocalizations l10n) {
    final Widget content;
    if (_loading) {
      content = const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: Lx.crimsonInk)));
    } else if (_failed) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Text(l10n.staffClientsLoadFailed, style: Lx.text(context, size: 14, color: Lx.muted)),
          const SizedBox(height: 12),
          LuxeFormTheme(child: ElevatedButton(onPressed: _load, child: Text(l10n.retry))),
        ]),
      );
    } else if (_clients.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text(l10n.staffMyClientsEmpty, textAlign: TextAlign.center, style: Lx.text(context, size: 14, color: Lx.muted))),
      );
    } else {
      content = Column(children: [
        for (final c in _clients)
          KeyedSubtree(
            key: ValueKey('staff-client-${c['id']}'),
            child: ClientCard(
              companyName: (c['company_name'] as String?) ?? '',
              contactPerson: (c['contact_person'] as String?) ?? '',
              clientType: c['client_type'] as String?,
              workspaceStatus: (c['workspace'] as Map?)?['status'] as String?,
              onTap: () => _open(c),
            ),
          ),
        if (_page < _lastPage)
          Center(
            child: LuxeButton(
              key: const ValueKey('staff-load-more'),
              label: l10n.auditLogNext,
              kind: LuxeButtonKind.quiet,
              size: LuxeButtonSize.sm,
              onPressed: () => _load(page: _page + 1),
            ),
          ),
      ]);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: Lx.crimsonInk,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        children: [
          LuxePageTitle(l10n.staffMyClientsTitle),
          _search(l10n),
          content,
        ],
      ),
    );
  }
}
