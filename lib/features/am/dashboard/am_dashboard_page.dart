import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/theme.dart';
import '../../../core/locale_provider.dart';
import '../../../core/reverb_service.dart';
import '../../../core/widgets/shad_logo.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'sa_approvals_page.dart';
import 'sa_clients_page.dart';
import 'sa_team_page.dart';
import '../settings/admin_settings_page.dart';
import '../../../data/approval_repository.dart';
import '../../../data/client_repository.dart';
import '../../../data/dashboard_repository.dart';
import '../../../data/dashboard_stats_repository.dart';
import '../../../data/manager_repository.dart';
import '../../../data/meeting_repository.dart';
import '../../../data/notification_repository.dart';
import '../../../data/payment_repository.dart';
import '../../../providers/approval_provider.dart';
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
  late final ApprovalProvider _childApprovalProvider = ApprovalProvider(repository: ApprovalRepository(api: _api));
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

  void _setupRealtimeNotifications() {
    final uid = _api.userId;
    if (uid == null) return;
    final reverb = _reverb;
    reverb.connectForUser(uid);
    reverb.onNotificationReceived = (payload) {
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
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
        try {
          final pData = await _childPaymentProvider.fetchPendingRaw();
          _pendingPayments = safeList(pData['payments']);
        } catch (e, s) {
          AppLog.error('am_dashboard._load(pendingPayments)', e, s);
          _pendingPayments = [];
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isSA && _api.avatarUrl != null && _api.avatarUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: ShadColors.crimson,
                  backgroundImage: NetworkImage(_api.resolveFileUrl(_api.avatarUrl!)),
                ),
              ),
            Text.rich(TextSpan(children: [
              TextSpan(
                text: _isSA ? '' : 'Welcome, ',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, fontFamily: 'Tajawal', color: Colors.white70),
              ),
              TextSpan(
                text: _isSA ? 'Admin' : _api.userName ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Tajawal', color: ShadColors.gold),
              ),
            ])),
          ],
        ),
        leading: const Padding(
          padding: EdgeInsetsDirectional.only(start: 8),
          child: ShadLogo(size: 28, showText: false),
        ),
        actions: [
          Stack(children: [
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/notifications')),
            if (_unreadNotifs > 0)
              Positioned(
                right: 6, top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: ShadColors.crimson, shape: BoxShape.circle),
                  child: Text('$_unreadNotifs', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
          IconButton(icon: const Icon(Icons.language, size: 20), onPressed: () => context.read<LocaleProvider>().toggle(), tooltip: loc.amChangeLanguage),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout, tooltip: loc.logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
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
                    ),
                    SaApprovalsPage(clientProvider: _childClientProvider, contractProvider: _childContractProvider, paymentProvider: _childPaymentProvider, approvalProvider: _childApprovalProvider),
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
                    ),
                    SaApprovalsPage(clientProvider: _childClientProvider, contractProvider: _childContractProvider, paymentProvider: _childPaymentProvider, approvalProvider: _childApprovalProvider),
                    _buildAmClientsTab(),
                    AdminSettingsPage(api: _api),
                  ],
            ),
      ),
      bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              backgroundColor: ShadColors.surfaceDarker,
              indicatorColor: ShadColors.crimson.withAlpha(40),
              height: 65,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: _isSA
                  ? [
                      NavigationDestination(
                        icon: _badgeChat > 0 ? Badge.count(count: _badgeChat, backgroundColor: ShadColors.crimson, textColor: Colors.white, textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), child: const Icon(Icons.home_outlined)) : const Icon(Icons.home_outlined),
                        selectedIcon: _badgeChat > 0 ? Badge.count(count: _badgeChat, backgroundColor: ShadColors.crimson, textColor: Colors.white, textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), child: const Icon(Icons.home, color: ShadColors.gold)) : const Icon(Icons.home, color: ShadColors.gold),
                        label: loc.amNavHome,
                      ),
                      NavigationDestination(
                        icon: _badgeApprovals > 0 ? Badge.count(count: _badgeApprovals, backgroundColor: ShadColors.gold, textColor: Colors.black, textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), child: const Icon(Icons.check_circle_outline)) : const Icon(Icons.check_circle_outline),
                        selectedIcon: _badgeApprovals > 0 ? Badge.count(count: _badgeApprovals, backgroundColor: ShadColors.gold, textColor: Colors.black, textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), child: const Icon(Icons.check_circle, color: ShadColors.gold)) : const Icon(Icons.check_circle, color: ShadColors.gold),
                        label: loc.amNavApprovals,
                      ),
                      NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people, color: ShadColors.gold), label: loc.amNavClients),
                      NavigationDestination(icon: const Icon(Icons.supervisor_account_outlined), selectedIcon: const Icon(Icons.supervisor_account, color: ShadColors.gold), label: loc.amNavTeam),
                      NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings, color: ShadColors.gold), label: loc.amNavSettings),
                    ]
                  : [
                      NavigationDestination(
                        icon: _badgeChat > 0 ? Badge.count(count: _badgeChat, backgroundColor: ShadColors.crimson, textColor: Colors.white, textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), child: const Icon(Icons.home_outlined)) : const Icon(Icons.home_outlined),
                        selectedIcon: _badgeChat > 0 ? Badge.count(count: _badgeChat, backgroundColor: ShadColors.crimson, textColor: Colors.white, textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), child: const Icon(Icons.home, color: ShadColors.gold)) : const Icon(Icons.home, color: ShadColors.gold),
                        label: loc.amNavHome,
                      ),
                      NavigationDestination(
                        icon: _badgeApprovals > 0 ? Badge.count(count: _badgeApprovals, backgroundColor: ShadColors.gold, textColor: Colors.black, textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), child: const Icon(Icons.check_circle_outline)) : const Icon(Icons.check_circle_outline),
                        selectedIcon: _badgeApprovals > 0 ? Badge.count(count: _badgeApprovals, backgroundColor: ShadColors.gold, textColor: Colors.black, textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), child: const Icon(Icons.check_circle, color: ShadColors.gold)) : const Icon(Icons.check_circle, color: ShadColors.gold),
                        label: loc.amNavApprovals,
                      ),
                      NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people, color: ShadColors.gold), label: loc.amNavClients),
                      NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings, color: ShadColors.gold), label: loc.amNavSettings),
                    ],
            ),
    );
  }



  Widget _buildAmClientsTab() {
    return Stack(
      children: [
        SaClientsPage(clientProvider: _childClientProvider, managerProvider: _childManagerProvider, api: _api),
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton(
            onPressed: () async {
              final created = await context.push<bool>('/am/clients/create');
              if (created == true) _load();
            },
            backgroundColor: ShadColors.gold,
            child: const Icon(Icons.person_add, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Future<void> _showAllMeetings() async {
    try {
      final meetings = await _meetingProvider.fetchAllWorkspacesRaw();
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

