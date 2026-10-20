import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/app_notification.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/locale_provider.dart';
import '../../../core/reverb_service.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'sa_approvals_page.dart';
import 'sa_clients_page.dart';
import 'sa_team_page.dart';
import '../settings/admin_settings_page.dart';
import '../../../data/client_repository.dart';
import '../../../data/dashboard_repository.dart';
import '../../../data/dashboard_stats_repository.dart';
import '../../../data/manager_repository.dart';
import '../../../data/meeting_repository.dart';
import '../../../data/notification_repository.dart';
import '../../../data/payment_repository.dart';
import '../../../providers/client_provider.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/dashboard_stats_provider.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/meeting_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/payment_provider.dart';
import 'am_dashboard_home_tabs.dart';
import 'am_dashboard_sheets.dart';

class AmDashboardPage extends StatefulWidget {
  // Step 0 of the state-layer migration plan: lets widget tests suppress the
  // 60s notification/refresh Timer so `pumpAndSettle` doesn't hang on a
  // pending periodic timer. Defaults to true — zero behavior change for
  // every existing call site.
  final bool enablePolling;
  // Step 0 of the state-layer migration plan: lets widget tests inject a
  // ReverbService.forTesting() instance instead of the real singleton, so
  // pumping this screen never opens a real WebSocket. Defaults to null,
  // which falls back to the real singleton — zero behavior change for every
  // existing call site.
  final ReverbService? reverb;
  // Testability seam (state-layer migration plan) — optional so every
  // existing call site keeps compiling unchanged. Defaults fall back to the
  // real ApiClient instance, same singleton `ApiClient()` always resolved to
  // before this param existed — zero behavior change in production.
  final ApiClient? api;
  final NotificationProvider? notificationProvider;
  final DashboardProvider? dashboardProvider;
  // Testability seam for GET /dashboard/stats (server-side-stats-plan.md,
  // Stage 3) — same reasoning as dashboardProvider above. Defaults to null,
  // which falls back to a real DashboardStatsProvider built from `_api`.
  final DashboardStatsProvider? dashboardStatsProvider;
  final MeetingProvider? meetingProvider;
  const AmDashboardPage({super.key, this.enablePolling = true, this.reverb, this.api, this.notificationProvider, this.dashboardProvider, this.dashboardStatsProvider, this.meetingProvider});

  @override
  State<AmDashboardPage> createState() => _AmDashboardPageState();
}

class _AmDashboardPageState extends State<AmDashboardPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final _searchController = TextEditingController();
  // Was `ApiClient().role` (the real singleton) before this seam — reading
  // `_api.role` instead is identical in production (widget.api defaults to
  // that same singleton) but makes this field controllable from a test via
  // widget.api, rather than requiring the test to mutate the real singleton.
  late final _isSA = _api.role == 'super_admin';
  late final _isAssistant = _api.role == 'manager_assistant';
  // Derived from `_api` purely to break the singleton fallback in the four
  // tab screens embedded below via IndexedStack (which mounts every tab
  // eagerly, not just the selected one) — each already accepts these same
  // provider params for its own testability. In production `_api` is always
  // the real singleton, so these behave identically to each screen's own
  // `?? XProvider()` default — zero behavior change.
  late final ClientProvider _childClientProvider = ClientProvider(repository: ClientRepository(api: _api));
  late final ManagerProvider _childManagerProvider = ManagerProvider(repository: ManagerRepository(api: _api));
  late final ContractProvider _childContractProvider = ContractProvider(api: _api);
  late final PaymentProvider _childPaymentProvider = PaymentProvider(repository: PaymentRepository(api: _api));
  late final NotificationProvider _notificationProvider =
      widget.notificationProvider ?? NotificationProvider(repository: NotificationRepository(api: _api));
  late final DashboardProvider _dashboardProvider = widget.dashboardProvider ?? DashboardProvider(repository: DashboardRepository(api: _api));
  late final DashboardStatsProvider _dashboardStatsProvider =
      widget.dashboardStatsProvider ?? DashboardStatsProvider(repository: DashboardStatsRepository(api: _api));
  late final MeetingProvider _meetingProvider = widget.meetingProvider ?? MeetingProvider(repository: MeetingRepository(api: _api));
  List<dynamic> _allClients = [];
  List<dynamic> _allManagers = [];
  List<dynamic> _pendingPayments = [];
  List<Map<String, dynamic>> _pendingContracts = [];
  List<dynamic> _allContracts = [];
  // GET /dashboard/stats' raw response (server-side-stats-plan.md, Stage 3) —
  // clients.total/contracts.active/payments.pending/approvals.total back the
  // four home-tab summary cards. Null until the first successful fetch;
  // every read below defaults to 0 rather than crashing on a null map.
  Map<String, dynamic>? _stats;
  bool _loading = true;
  int _unreadNotifs = 0;
  int _selectedIndex = 0;
  int _badgeApprovals = 0;
  int _badgeChat = 0;
  // Latest notifications, shown as the home tab's "Recent activity" card
  // (staff mockup pHome). Comes from the same /notifications call as the bell.
  List<AppNotification> _recentActivity = [];
  Timer? _pollTimer;
  int _pollTick = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadNotifs();
    _searchController.addListener(_filter);
    _setupRealtimeNotifications();
    if (widget.enablePolling) {
      _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        _loadNotifs();
        _pollTick++;
        if (_pollTick % 5 == 0) _load();
      });
    }
  }

  late final ReverbService _reverb = widget.reverb ?? ReverbService();
  // plans/notifications-badges-toasts-plan.md ن15 — see the identical field
  // in client_dashboard_screen.dart for why this list exists.
  final List<VoidCallback> _reverbUnsubscribers = [];

  void _setupRealtimeNotifications() {
    final uid = _api.userId;
    if (uid == null) return;
    final reverb = _reverb;
    reverb.connectForUser(uid);
    _reverbUnsubscribers.add(reverb.addNotificationReceivedListener((payload) {
      _loadNotifs();
      if (!mounted) return;
      final msg = (payload['data'] as Map?)?['message'] as String? ?? AppLocalizations.of(context)!.amNewNotification;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
    }));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _api.refreshAssistantPermissions();
    await _api.refreshContractApproval();
    try {
      if (_isSA) {
        _allManagers = await _childManagerProvider.fetchAllManagersRaw();
        try {
          _allContracts = await _childContractProvider.fetchAllContractsAcrossCompanyRaw();
        } catch (e, s) {
          AppLog.error('am_dashboard._load(allContracts)', e, s);
          _allContracts = [];
        }
        _pendingContracts = _derivePendingContracts(_allContracts);
        try {
          final pData = await _childPaymentProvider.fetchPendingRaw();
          _pendingPayments = safeList(pData['payments']);
        } catch (e, s) {
          AppLog.error('am_dashboard._load(pendingPayments)', e, s);
          _pendingPayments = [];
        }
      } else {
        _allClients = await _childClientProvider.fetchClientsRaw();
        _filter();
        try {
          _allContracts = await _childContractProvider.fetchAllContractsAcrossCompanyRaw();
        } catch (e, s) {
          AppLog.error('am_dashboard._load(allContracts)', e, s);
          _allContracts = [];
        }
        _pendingContracts = _derivePendingContracts(_allContracts);
        // Assistants never see money — the endpoint refuses them.
        if (!_isAssistant) {
          try {
            final pData = await _childPaymentProvider.fetchPendingRaw();
            _pendingPayments = safeList(pData['payments']);
          } catch (e, s) {
            AppLog.error('am_dashboard._load(pendingPayments)', e, s);
            _pendingPayments = [];
          }
        }
      }
      // 24 Sept 2026 (server-side-stats-plan.md, Stage 3) — one request for
      // every summary-card number, scoped server-side the same way /reports
      // already is. Replaces the old _fetchAllContracts() N+1 loop entirely
      // (it fetched every client, then one more request per client's
      // workspace contracts — up to 31 requests just to find pending
      // contract approvals); see _derivePendingContracts above, which now
      // builds that preview list from _allContracts instead, already a
      // single request.
      try {
        _stats = await _dashboardStatsProvider.fetchStats();
      } catch (e, s) {
        AppLog.error('am_dashboard._load(stats)', e, s);
        _stats = null;
      }
    } catch (e, s) {
      AppLog.error('am_dashboard._load', e, s);
    }
    if (mounted) setState(() => _loading = false);
  }

  int _statInt(String section, String key) {
    final value = (_stats?[section] as Map?)?[key];
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _filter() {
    // Triggers a rebuild so any UI reading _searchController.text directly
    // picks up the new query. The previous version of this method computed
    // a _filteredClients list that nothing in build() ever read.
    setState(() {});
  }

  Future<void> _loadNotifs() async {
    try {
      final data = await _notificationProvider.fetchRaw();
      _unreadNotifs = int.tryParse(data['unread_count']?.toString() ?? '') ?? 0;
      final raw = (data['notifications'] ?? data['data']) as List<dynamic>? ?? const [];
      _recentActivity = raw.whereType<Map<String, dynamic>>().take(4).map(AppNotification.fromJson).toList();
    } catch (e, s) {
      AppLog.error('am_dashboard._loadNotifs(unread)', e, s);
    }
    try {
      final data = await _dashboardProvider.fetchBadgeCounts();
      _badgeApprovals = int.tryParse(data['approvals']?.toString() ?? '') ?? 0;
      _badgeChat = int.tryParse(data['chat']?.toString() ?? '') ?? 0;
    } catch (e, s) {
      AppLog.error('am_dashboard._loadNotifs(badges)', e, s);
    }
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.logout),
        content: Text(AppLocalizations.of(ctx)!.logoutConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx)!.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(ctx)!.logout)),
        ],
      ),
    );
    if (confirm == true) {
      // See client_dashboard_screen.dart's _logout for why this has to run
      // before clearToken() — an open socket left under the cleared identity
      // eventually 401s on reconnect and bounces the user back to /login a
      // second time. See docs/mobile-review-2026-08-round2.md, #1.
      _reverb.disconnect();
      await _api.clearToken();
      if (!mounted) return;
      context.go('/login');
    }
  }

  void _openClient(Map<String, dynamic> client) async {
    final ws = client['workspace'] as Map<String, dynamic>?;
    if (ws == null) {
      try {
        final created = await _childClientProvider.createWorkspaceForClient(client['id'] as int);
        final newWs = created['workspace'] as Map<String, dynamic>;
        await _api.setUserData(workspace: newWs['id']);
        if (!mounted) return;
        context.push('/am/workspace/${newWs['id']}');
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.amWorkspaceCreateFailed)));
      }
      return;
    }
    await _api.setUserData(workspace: ws['id']);
    if (!mounted) return;
    context.push('/am/workspace/${ws['id']}');
  }

  /// Builds the "latest pending contract approvals" preview list straight
  /// from [_allContracts] (already a single request — see [_load]) instead
  /// of the old `_fetchAllContracts()`, which fetched every client (page 1
  /// only) and then made one more request per client just to find their
  /// pending contracts — up to 31 requests to render 2 preview rows.
  /// server-side-stats-plan.md, Stage 3 (M4).
  List<Map<String, dynamic>> _derivePendingContracts(List<dynamic> contracts) {
    const pendingStatuses = {'sent', 'client_approved'};
    return contracts
        .where((c) => c is Map && pendingStatuses.contains(c['status']))
        .map<Map<String, dynamic>>((c) {
          final ws = c['workspace'] as Map<String, dynamic>?;
          final client = ws?['client'] as Map<String, dynamic>?;
          return {
            'title': c['title'] ?? '',
            'value': c['value'] ?? 0,
            'currency': c['currency'] ?? 'SAR',
            'company': client?['company_name'] ?? '',
            'client': client,
            'workspace_id': ws?['id'],
            'status': c['status'],
            'created_at': c['created_at'],
            'manager': ((ws?['account_manager'] ?? client?['account_manager']) as Map?)?['name'],
          };
        })
        .toList();
  }

  void _createMeeting() {
    final clients = _allClients.where((c) {
      final ws = c['workspace'] as Map<String, dynamic>?;
      return ws != null;
    }).toList();
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.amNoClientsAvailable)));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => CreateMeetingSheet(clients: clients, meetingProvider: _meetingProvider, onCreated: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.amMeetingCreated)])));
      }),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    for (final unsubscribe in _reverbUnsubscribers) {
      unsubscribe();
    }
    super.dispose();
  }

  String _avatarInitial() {
    final n = (_isSA ? 'Admin' : (_api.userName ?? '')).trim();
    return n.isEmpty ? '·' : n.substring(0, 1).toUpperCase();
  }

  String _roleLabel(AppLocalizations loc) =>
      _isSA ? loc.amRoleSuperAdmin : (_isAssistant ? loc.amRoleAssistant : loc.amRoleManager);

  /// The staff mockup's "More" sheet: who you are, the extra pages, language, logout.
  void _showMoreSheet() {
    final loc = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = _isSA ? 'Admin' : (_api.userName ?? '');
    showLuxeSheet<void>(context, builder: (ctx) {
      void go(int index) {
        Navigator.pop(ctx);
        setState(() => _selectedIndex = index);
      }

      void open(String route) {
        Navigator.pop(ctx);
        context.push(route);
      }

      final rows = <Widget>[
        if (_isSA) ...[
          LuxeMoreRow(key: const ValueKey('more-finance'), lxIcon: 'wallet', label: loc.financeTitle, onTap: () => open('/am/finance')),
          LuxeMoreRow(key: const ValueKey('more-reports'), lxIcon: 'chart', label: loc.amStatReports, onTap: () => open('/am/reports')),
          LuxeMoreRow(key: const ValueKey('more-audit'), lxIcon: 'list', label: loc.auditLogs, onTap: () => open('/am/audit-logs')),
          LuxeMoreRow(key: const ValueKey('more-managers'), lxIcon: 'key', label: loc.accountManagers_title, onTap: () => go(3)),
          LuxeMoreRow(key: const ValueKey('more-teams'), lxIcon: 'layers', label: loc.staffNavTitle, onTap: () => open('/am/staff')),
          LuxeMoreRow(key: const ValueKey('more-settings'), lxIcon: 'gear', label: loc.amNavSettings, onTap: () => go(4)),
        ] else ...[
          if (_api.role == 'account_manager')
            LuxeMoreRow(key: const ValueKey('more-myteam'), lxIcon: 'users', label: loc.mtTitle, onTap: () => open('/am/my-team')),
          if (!_isAssistant)
            LuxeMoreRow(key: const ValueKey('more-audit'), lxIcon: 'list', label: loc.auditLogs, onTap: () => open('/am/audit-logs')),
          LuxeMoreRow(key: const ValueKey('more-settings'), lxIcon: 'gear', label: loc.amNavSettings, onTap: () => go(3)),
        ],
        // Not in the mockup's home; kept here so the all-meetings sheet
        // (and creating a meeting) stays reachable.
        LuxeMoreRow(
          key: const ValueKey('home-meetings'),
          lxIcon: 'video',
          label: loc.amStatMeetings,
          onTap: () {
            Navigator.pop(ctx);
            _showAllMeetings();
          },
        ),
        LuxeMoreRow(
          key: const ValueKey('more-language'),
          lxIcon: 'lang',
          label: isAr ? 'English' : 'العربية',
          onTap: () {
            Navigator.pop(ctx);
            context.read<LocaleProvider>().toggle();
          },
        ),
        LuxeMoreRow(
          key: const ValueKey('more-logout'),
          lxIcon: 'out',
          label: loc.logout,
          danger: true,
          last: true,
          onTap: () {
            Navigator.pop(ctx);
            _logout();
          },
        ),
      ];
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            LuxeAvatar(initial: _avatarInitial()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, key: const ValueKey('more-name'), style: Lx.display(ctx, size: 16)),
                Text(_roleLabel(loc).toUpperCase(), style: Lx.text(ctx, size: 11, color: Lx.faint).copyWith(letterSpacing: 1.1)),
              ]),
            ),
          ]),
        ),
        ...rows,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final moreIndex = 3;
    final navItems = <LuxeNavItem>[
      LuxeNavItem(id: 'home', lxIcon: 'home', label: loc.amNavHome),
      LuxeNavItem(id: 'approvals', lxIcon: 'check', label: loc.amNavApprovals, badge: _badgeApprovals),
      LuxeNavItem(id: 'clients', lxIcon: 'users', label: _isSA ? loc.amNavClients : loc.staffMyClientsTitle),
      LuxeNavItem(id: 'more', lxIcon: 'more', label: loc.dashboard_more),
    ];

    return Scaffold(
      backgroundColor: Lx.page,
      body: SafeArea(
        bottom: false,
        child: LuxeGlow(
          child: Column(children: [
            LuxeTopBar(
              company: _roleLabel(loc),
              avatarInitial: _avatarInitial(),
              unread: _unreadNotifs > 0,
              // plans/notifications-badges-toasts-plan.md ن12 — this used to
              // leave the badge showing its stale pre-visit count until the
              // next 60s poll tick, even though the notifications page
              // itself just marked things read/deleted.
              onBell: () => context.push('/notifications').then((_) => _loadNotifs()),
              onAvatar: _showMoreSheet,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: Lx.crimsonInk,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Lx.crimsonInk))
                    : IndexedStack(
                        index: _selectedIndex,
                        children: _isSA
                            ? [
                                buildHomeTab(
                                  context: context,
                                  allManagers: _allManagers,
                                  pendingContracts: _pendingContracts,
                                  pendingPayments: _pendingPayments,
                                  api: _api,
                                  onSelectTab: (i) => setState(() => _selectedIndex = i),
                                  onShowAllMeetings: _showAllMeetings,
                                  onManagerTap: _showManagerClients,
                                  load: _load,
                                  clientsTotal: _statInt('clients', 'total'),
                                  contractsActive: _statInt('contracts', 'active'),
                                  paymentsPending: _statInt('payments', 'pending'),
                                  approvalsTotal: _statInt('approvals', 'total'),
                                  revenueThisMonth: _stats?['revenue_this_month'] is Map ? Map<String, dynamic>.from(_stats!['revenue_this_month'] as Map) : null,
                                  recentActivity: _recentActivity,
                                ),
                                SaApprovalsPage(dashboardStatsProvider: _dashboardStatsProvider),
                                SaClientsPage(clientProvider: _childClientProvider, managerProvider: _childManagerProvider, api: _api),
                                SaTeamPage(managerProvider: _childManagerProvider, api: _api),
                                AdminSettingsPage(api: _api),
                              ]
                            : [
                                buildAmHomeTab(
                                  context: context,
                                  allClients: _allClients,
                                  pendingContracts: _pendingContracts,
                                  pendingPayments: _pendingPayments,
                                  isSA: _isSA,
                                  api: _api,
                                  onSelectTab: (i) => setState(() => _selectedIndex = i),
                                  onShowAllMeetings: _showAllMeetings,
                                  onOpenClient: _openClient,
                                  load: _load,
                                  clientsTotal: _statInt('clients', 'total'),
                                  contractsActive: _statInt('contracts', 'active'),
                                  paymentsPending: _statInt('payments', 'pending'),
                                  approvalsTotal: _statInt('approvals', 'total'),
                                  contractsAwaiting: _statInt('contracts', 'awaiting_client'),
                                  unreadMessages: _badgeChat,
                                  recentActivity: _recentActivity,
                                ),
                                SaApprovalsPage(dashboardStatsProvider: _dashboardStatsProvider),
                                _buildAmClientsTab(),
                                AdminSettingsPage(api: _api),
                              ],
                      ),
              ),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: LuxeBottomNav(
        items: navItems,
        currentIndex: _selectedIndex >= moreIndex ? moreIndex : _selectedIndex,
        onTap: (i) {
          if (i == moreIndex) {
            _showMoreSheet();
            return;
          }
          setState(() => _selectedIndex = i);
        },
      ),
    );
  }

  Widget _buildAmClientsTab() {
    // Creating clients is the manager's job, not an assistant's.
    return SaClientsPage(
      clientProvider: _childClientProvider,
      managerProvider: _childManagerProvider,
      api: _api,
      onCreateClient: _isAssistant
          ? null
          : () async {
              final created = await context.push<bool>('/am/clients/create');
              if (created == true) _load();
            },
    );
  }

  Future<void> _showAllMeetings() async {
    try {
      final meetings = await _meetingProvider.fetchAllWorkspacesRaw();
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Lx.sheet,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet))),
        builder: (_) => AllMeetingsSheet(
          meetings: meetings,
          onCreate: !_isSA ? _createMeeting : null,
        ),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.amMeetingsLoadFailed)));
    }
  }

  void _showManagerClients(Map<String, dynamic> manager) async {
    final managerId = int.tryParse(manager['id']?.toString() ?? '') ?? 0;
    try {
      final data = await _childManagerProvider.fetchManagerRaw(managerId);
      final clients = data['clients'] as List<dynamic>? ?? [];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Lx.sheet,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet))),
        builder: (ctx) => ManagerClientsSheet(
          managerName: manager['name'] as String? ?? '',
          clients: clients,
          onClientTap: (client) {
            Navigator.pop(ctx);
            _openClient(client);
          },
        ),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.amClientsLoadFailed)));
    }
  }

}

