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
import '../../../core/widgets/client_type_badge.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'sa_approvals_page.dart';
import 'sa_clients_page.dart';
import 'sa_team_page.dart';
import '../settings/admin_settings_page.dart';
import '../../../data/client_repository.dart';
import '../../../data/dashboard_repository.dart';
import '../../../data/manager_repository.dart';
import '../../../data/notification_repository.dart';
import '../../../data/payment_repository.dart';
import '../../../providers/client_provider.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/payment_provider.dart';

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
  const AmDashboardPage({super.key, this.enablePolling = true, this.reverb, this.api, this.notificationProvider, this.dashboardProvider});

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
  late final NotificationProvider _notificationProvider =
      widget.notificationProvider ?? NotificationProvider(repository: NotificationRepository(api: _api));
  late final DashboardProvider _dashboardProvider = widget.dashboardProvider ?? DashboardProvider(repository: DashboardRepository(api: _api));
  List<dynamic> _allClients = [];
  List<dynamic> _allManagers = [];
  List<dynamic> _pendingPayments = [];
  List<Map<String, dynamic>> _pendingContracts = [];
  List<dynamic> _allContracts = [];
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
        _pendingContracts = await _fetchAllContracts(['sent', 'client_approved']);
        try {
          _allContracts = await _childContractProvider.fetchAllContractsAcrossCompanyRaw();
        } catch (e, s) {
          AppLog.error('am_dashboard._load(allContracts)', e, s);
          _allContracts = [];
        }
        try {
          final pData = await _api.get('/payments/pending');
          _pendingPayments = safeList(pData['payments']);
        } catch (e, s) {
          AppLog.error('am_dashboard._load(pendingPayments)', e, s);
          _pendingPayments = [];
        }
      } else {
        _allClients = await _childClientProvider.fetchClientsRaw();
        _filter();
        _pendingContracts = await _fetchAllContracts(['sent', 'client_approved']);
        try {
          final pData = await _api.get('/payments/pending');
          _pendingPayments = safeList(pData['payments']);
        } catch (e, s) {
          AppLog.error('am_dashboard._load(pendingPayments)', e, s);
          _pendingPayments = [];
        }
        try {
          _allContracts = await _childContractProvider.fetchAllContractsAcrossCompanyRaw();
        } catch (e, s) {
          AppLog.error('am_dashboard._load(allContracts)', e, s);
          _allContracts = [];
        }
      }
    } catch (e, s) {
      AppLog.error('am_dashboard._load', e, s);
    }
    if (mounted) setState(() => _loading = false);
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
      await _api.clearToken();
      if (!mounted) return;
      context.go('/login');
    }
  }

  void _openClient(Map<String, dynamic> client) async {
    final ws = client['workspace'] as Map<String, dynamic>?;
    if (ws == null) {
      try {
        final created = await _api.post('/workspaces', {'client_id': client['id']});
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

  Future<List<Map<String, dynamic>>> _fetchAllContracts(List<String> statuses) async {
    final results = <Map<String, dynamic>>[];
    try {
      final clients = await _childClientProvider.fetchClientsRaw();
      for (final client in clients) {
        final ws = client['workspace'] as Map<String, dynamic>?;
        if (ws == null) continue;
        try {
          final contracts = await _childContractProvider.fetchWorkspaceContractsRaw(ws['id'] as int);
          for (final c in contracts) {
            if (statuses.contains(c['status'])) {
              results.add({
                'title': c['title'] ?? '',
                'value': c['value'] ?? 0,
                'currency': c['currency'] ?? 'SAR',
                'company': client['company_name'] ?? '',
                'client': client,
                'workspace_id': ws['id'],
              });
            }
          }
        } catch (e, s) {
          // One workspace failing shouldn't drop the whole list.
          AppLog.error('am_dashboard._fetchAllContracts(workspace)', e, s);
          continue;
        }
      }
    } catch (e, s) {
      AppLog.error('am_dashboard._fetchAllContracts', e, s);
    }
    return results;
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
      builder: (ctx) => _CreateMeetingSheet(clients: clients, onCreated: () {
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
                    _buildHomeTab(),
                    SaApprovalsPage(clientProvider: _childClientProvider, contractProvider: _childContractProvider, paymentProvider: _childPaymentProvider),
                    SaClientsPage(clientProvider: _childClientProvider, managerProvider: _childManagerProvider, api: _api),
                    SaTeamPage(managerProvider: _childManagerProvider, api: _api),
                    AdminSettingsPage(api: _api),
                  ]
                : [
                    _buildAmHomeTab(),
                    SaApprovalsPage(clientProvider: _childClientProvider, contractProvider: _childContractProvider, paymentProvider: _childPaymentProvider),
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



  Widget _buildAmHomeTab() {
    final l10n = AppLocalizations.of(context)!;
    final totalClients = _allClients.length;
    final activeContracts = _allContracts.where((c) => c['status'] == 'company_approved' || c['status'] == 'completed').length;
    final totalPending = _pendingContracts.length + _pendingPayments.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _homeStatCard(l10n.amStatTotalClients, '$totalClients', Icons.people, ShadColors.sent)),
          const SizedBox(width: 8),
          Expanded(child: _homeStatCard(l10n.amStatActiveContracts, '$activeContracts', Icons.description, ShadColors.gold)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _homeStatCard(l10n.amStatPendingPayments, '${_pendingPayments.length}', Icons.payments, ShadColors.warning)),
          const SizedBox(width: 8),
          Expanded(child: _homeStatCard(l10n.amStatPendingApprovals, '$totalPending', Icons.pending_actions, ShadColors.crimson)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          if (_isSA)
            Expanded(child: _homeStatCard(l10n.amStatReports, '', Icons.bar_chart, ShadColors.gold, onTap: () => context.push('/am/reports'))),
          if (_isSA) const SizedBox(width: 8),
          Expanded(child: _homeStatCard(l10n.amStatMeetings, '', Icons.videocam, ShadColors.sent, onTap: _showAllMeetings)),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Text(l10n.amRecentApprovals, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 1),
            child: Text(l10n.amViewAll, style: const TextStyle(fontSize: 11, color: ShadColors.gold, fontFamily: 'Archivo')),
          ),
        ]),
        const SizedBox(height: 8),
        if (_pendingContracts.isEmpty && _pendingPayments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text(l10n.amNoPendingApprovals, style: const TextStyle(fontSize: 12, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
          )
        else ...[
          if (_pendingContracts.isNotEmpty)
            ..._pendingContracts.take(2).map((c) => _approvalItem(
              title: '${l10n.amContractApproval} — ${c['title'] ?? ''}',
              subtitle: '${c['company'] ?? ''} • ${double.tryParse(c['value']?.toString() ?? '')?.toStringAsFixed(0) ?? '0'} ${c['currency'] ?? ''}',
              isContract: true,
            )),
          if (_pendingPayments.isNotEmpty)
            ..._pendingPayments.take(2).map((p) {
              final client = p['workspace']?['client'] as Map<String, dynamic>?;
              return _approvalItem(
                title: '${l10n.amPaymentApproval} — ${client?['company_name'] ?? ''}',
                subtitle: '${p['currency'] ?? ''} ${(double.tryParse(p['amount']?.toString() ?? '') ?? 0).toStringAsFixed(0)}',
                isContract: false,
              );
            }),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Text(l10n.amClients, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 2),
            child: Text(l10n.amViewAll, style: const TextStyle(fontSize: 11, color: ShadColors.gold, fontFamily: 'Archivo')),
          ),
        ]),
        const SizedBox(height: 8),
        if (_allClients.isNotEmpty)
          ..._allClients.take(3).map((c) => _clientCard(c)),
        if (_allClients.isEmpty)
          _buildEmptyState(),
      ],
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

  Widget _buildHomeTab() {
    final l10n = AppLocalizations.of(context)!;
    final totalClients = _allManagers.fold<int>(0, (sum, m) => sum + ((m['managed_clients_count'] as int? ?? 0)));
    final activeContracts = _allContracts.where((c) => c['status'] == 'company_approved' || c['status'] == 'completed').length;
    final totalPending = _pendingContracts.length + _pendingPayments.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats Grid 3x2
        Row(children: [
          Expanded(child: _homeStatCard(l10n.amStatTotalClients, '$totalClients', Icons.people, ShadColors.sent)),
          const SizedBox(width: 8),
          Expanded(child: _homeStatCard(l10n.amStatActiveContracts, '$activeContracts', Icons.description, ShadColors.gold)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _homeStatCard(l10n.amStatPendingPayments, '${_pendingPayments.length}', Icons.payments, ShadColors.warning)),
          const SizedBox(width: 8),
          Expanded(child: _homeStatCard(l10n.amStatPendingApprovals, '$totalPending', Icons.pending_actions, ShadColors.crimson)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _homeStatCard(l10n.amStatReports, '', Icons.bar_chart, ShadColors.gold, onTap: () => context.push('/am/reports'))),
          const SizedBox(width: 8),
          Expanded(child: _homeStatCard(l10n.amStatMeetings, '', Icons.videocam, ShadColors.sent, onTap: _showAllMeetings)),
        ]),
        const SizedBox(height: 20),
        // Latest Pending Approvals
        Row(children: [
          Text(l10n.amRecentApprovals, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 1),
            child: Text(l10n.amViewAll, style: const TextStyle(fontSize: 11, color: ShadColors.gold, fontFamily: 'Archivo')),
          ),
        ]),
        const SizedBox(height: 8),
        if (_pendingContracts.isEmpty && _pendingPayments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text(l10n.amNoPendingApprovals, style: const TextStyle(fontSize: 12, color: ShadColors.textDisabled, fontFamily: 'Archivo'))),
          )
        else ...[
          if (_pendingContracts.isNotEmpty)
            ..._pendingContracts.take(2).map((c) => _approvalItem(
              title: '${l10n.amContractApproval} — ${c['title'] ?? ''}',
              subtitle: '${c['company'] ?? ''} • ${double.tryParse(c['value']?.toString() ?? '')?.toStringAsFixed(0) ?? '0'} ${c['currency'] ?? ''}',
              isContract: true,
            )),
          if (_pendingPayments.isNotEmpty)
            ..._pendingPayments.take(2).map((p) {
              final client = p['workspace']?['client'] as Map<String, dynamic>?;
              return _approvalItem(
                title: '${l10n.amPaymentApproval} — ${client?['company_name'] ?? ''}',
                subtitle: '${p['currency'] ?? ''} ${(double.tryParse(p['amount']?.toString() ?? '') ?? 0).toStringAsFixed(0)}',
                isContract: false,
              );
            }),
        ],
        const SizedBox(height: 20),
        // Team Section
        Row(children: [
          Text(l10n.amNavTeam, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 3),
            child: Text(l10n.amViewAll, style: const TextStyle(fontSize: 11, color: ShadColors.gold, fontFamily: 'Archivo')),
          ),
        ]),
        const SizedBox(height: 8),
        if (_allManagers.isNotEmpty)
          ..._allManagers.take(3).map((m) => _managerCard(m)),
        if (_allManagers.isEmpty)
          _buildEmptyState(),
      ],
    );
  }

  Widget _homeStatCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const Spacer(),
          if (value.isNotEmpty) Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: color, fontFamily: 'PlayfairDisplay')),
        ]),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
      ]),
    ),
    );
  }

  Widget _approvalItem({required String title, required String subtitle, required bool isContract}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: Row(children: [
        Container(width: 3, height: 48, decoration: BoxDecoration(color: isContract ? ShadColors.gold : ShadColors.sent, borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)))),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _showAllMeetings() async {
    try {
      final data = await _api.get('/all-meetings');
      final meetings = safeList(data['meetings']);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _AllMeetingsSheet(
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
      final data = await _api.get('/account-managers/$managerId');
      final clients = data['clients'] as List<dynamic>? ?? [];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => _ManagerClientsSheet(
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

  Widget _managerCard(Map<String, dynamic> manager) {
    final name = manager['name'] as String? ?? '';
    final email = manager['email'] as String? ?? '';
    final clientCount = int.tryParse(manager['managed_clients_count']?.toString() ?? '') ?? 0;
    final avatarUrl = manager['avatar_url'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showManagerClients(manager),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: ShadColors.cardBorder,
              backgroundImage: avatarUrl != null ? NetworkImage(_api.resolveFileUrl(avatarUrl)) : null,
              child: avatarUrl == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 18, color: ShadColors.textSecondary)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ShadColors.sent.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$clientCount', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.sent, fontFamily: 'PlayfairDisplay')),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _clientCard(Map<String, dynamic> client) {
    final l10n = AppLocalizations.of(context)!;
    final ws = client['workspace'] as Map<String, dynamic>?;
    final wsStatus = ws?['status'] as String? ?? 'inactive';
    final wsActive = wsStatus == 'active';
    final name = client['company_name'] as String? ?? '';
    final person = client['contact_person'] as String? ?? '';
    final paymentStatus = client['payment_status'] as String?;
    final signedAt = client['signed_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openClient(client),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: ShadColors.crimson,
                backgroundImage: (client['avatar_url'] as String?)?.isNotEmpty == true
                    ? NetworkImage(_api.resolveFileUrl(client['avatar_url']))
                    : null,
                child: (client['avatar_url'] as String?)?.isNotEmpty != true
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: ShadColors.gold, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Archivo'))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo'))),
                    const SizedBox(width: 6),
                    ClientTypeBadge(clientType: client['client_type'] as String?, compact: true),
                  ]),
                  const SizedBox(height: 2),
                  Text(person, style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (wsActive ? ShadColors.success : ShadColors.textDisabled).withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  wsActive ? l10n.amStatusActive : l10n.amStatusInactive,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3,
                    color: wsActive ? ShadColors.success : ShadColors.textDisabled,
                    fontFamily: 'Archivo',
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _statusChip(Icons.description_outlined, signedAt != null ? l10n.amStatusContracted : l10n.amStatusNotContracted, signedAt != null ? ShadColors.success : ShadColors.textDisabled),
                _statusChip(Icons.payment, paymentStatus == 'approved' ? l10n.amStatusPaid : paymentStatus == 'pending' ? l10n.amStatusPending : '—',
                  paymentStatus == 'approved' ? ShadColors.success : paymentStatus == 'pending' ? ShadColors.warning : ShadColors.textDisabled),
                _statusChip(wsActive ? Icons.check_circle : Icons.schedule, wsActive ? l10n.amStatusActive : l10n.amStatusPending,
                  wsActive ? ShadColors.success : ShadColors.textDisabled),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500, fontFamily: 'Archivo')),
      ]),
    );
  }

  Widget _buildEmptyState() {
    final loc2 = AppLocalizations.of(context)!;
    final isSA = _api.role == 'super_admin';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        const Icon(Icons.people_outline, size: 56, color: ShadColors.textDisabled),
        const SizedBox(height: 16),
        Text(loc2.noClients, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
        const SizedBox(height: 8),
        Text(loc2.noClientsSubtitle, style: TextStyle(fontSize: 14, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
        const SizedBox(height: 24),
        if (!isSA)
          ElevatedButton.icon(
            onPressed: () async { final created = await context.push<bool>('/am/clients/create'); if (created == true) _load(); },
            icon: const Icon(Icons.person_add, size: 18),
            label: Text(loc2.createClient),
          ),
      ]),
    );
  }

}

class _ManagerClientsSheet extends StatelessWidget {
  final String managerName;
  final List<dynamic> clients;
  final void Function(Map<String, dynamic> client) onClientTap;
  const _ManagerClientsSheet({required this.managerName, required this.clients, required this.onClientTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${l10n.amClients} $managerName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
        if (clients.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(l10n.amNoClientsAvailable, style: const TextStyle(color: ShadColors.textSecondary))),
          )
        else
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: clients.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = clients[i];
                final ws = c['workspace'] as Map<String, dynamic>?;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: ShadColors.cardBorder,
                    child: Text((c['company_name'] as String? ?? '')[0].toUpperCase(), style: const TextStyle(color: ShadColors.textSecondary)),
                  ),
                  title: Row(children: [
                    Flexible(child: Text(c['company_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                    const SizedBox(width: 6),
                    ClientTypeBadge(clientType: c['client_type'] as String?, compact: true),
                  ]),
                  subtitle: Text(c['contact_person'] ?? '', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ws?['status'] == 'active' ? ShadColors.success.withAlpha(25) : ShadColors.cardBorder,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(ws?['status'] == 'active' ? l10n.amStatusActive : l10n.amStatusInactive, style: TextStyle(fontSize: 10, color: ws?['status'] == 'active' ? ShadColors.success : ShadColors.textSecondary)),
                  ),
                  onTap: () => onClientTap(c),
                );
              },
            ),
          ),
      ]),
    );
  }
}

class _AllMeetingsSheet extends StatelessWidget {
  final List<dynamic> meetings;
  final VoidCallback? onCreate;
  const _AllMeetingsSheet({required this.meetings, this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: ShadColors.cardBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text(l10n.amStatMeetings, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: ShadColors.crimson.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Text('${meetings.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, size: 20, color: ShadColors.textSecondary), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: meetings.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(l10n.amNoMeetings, style: const TextStyle(fontSize: 13, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
                      if (onCreate != null) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () { Navigator.pop(context); onCreate?.call(); },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(l10n.createMeeting),
                        ),
                      ],
                    ]),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: meetings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m = meetings[i];
                      final client = m['workspace']?['client'] as Map<String, dynamic>?;
                      final status = m['status'] as String? ?? '';
                      final statusColor = status == 'completed' ? ShadColors.success : status == 'scheduled' ? ShadColors.sent : ShadColors.textSecondary;
                      final statusLabel = status == 'scheduled' ? l10n.scheduled : status == 'completed' ? l10n.completed : status == 'cancelled' ? l10n.cancelled : status;
                      String? dateStr;
                      try {
                        final dt = DateTime.parse(m['scheduled_at'] ?? '');
                        dateStr = '${dt.year}/${dt.month}/${dt.day}';
                      } catch (_) {
                        // A meeting with no/invalid date just renders without
                        // one. Not reported: this is normal for drafts, and
                        // it runs inside a list builder, so a bad record
                        // would report on every rebuild.
                      }
                      final wsId = m['workspace_id'] ?? m['workspace']?['id'];
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.pop(context);
                          if (wsId != null) context.push('/am/workspace/$wsId?tab=5');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ShadColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ShadColors.cardBorder),
                          ),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: ShadColors.gold.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.videocam, size: 18, color: ShadColors.gold),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                                const SizedBox(height: 2),
                                Text('${client?['company_name'] ?? ''} • ${dateStr ?? ''}', style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor, fontFamily: 'Archivo')),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _CreateMeetingSheet extends StatefulWidget {
  final List<dynamic> clients;
  final VoidCallback onCreated;
  const _CreateMeetingSheet({required this.clients, required this.onCreated});

  @override
  State<_CreateMeetingSheet> createState() => _CreateMeetingSheetState();
}

class _CreateMeetingSheetState extends State<_CreateMeetingSheet> {
  final _api = ApiClient();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int? _duration;
  dynamic _selectedClient;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ws = _selectedClient?['workspace'] as Map<String, dynamic>?;
    if (_titleController.text.trim().isEmpty || ws == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.amMeetingValidation)));
      return;
    }
    setState(() => _saving = true);
    final dt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    final tzOffset = dt.timeZoneOffset;
    final tzSign = tzOffset.isNegative ? '-' : '+';
    final tzHours = tzOffset.inHours.abs().toString().padLeft(2, '0');
    final tzMinutes = (tzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final scheduledAtIso = '${dt.toIso8601String()}$tzSign$tzHours:$tzMinutes';
    try {
      await _api.post('/workspaces/${ws['id']}/meetings', {
        'title': _titleController.text.trim(),
        'scheduled_at': scheduledAtIso,
        'duration_minutes': _duration ?? 30,
        'notes': _notesController.text.trim(),
      });
      widget.onCreated();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.amMeetingCreateFailed)));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l10n.createMeeting, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
        DropdownButtonFormField(
          decoration: InputDecoration(labelText: l10n.amClientRequired),
          items: widget.clients.map((c) => DropdownMenuItem(
            value: c,
            child: Text(c['company_name'] ?? ''),
          )).toList(),
          onChanged: (v) => setState(() => _selectedClient = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(labelText: l10n.amMeetingTitle, hintText: l10n.amMeetingTitleHint),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _selectedDate = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: l10n.amDate),
                child: Text('${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _selectedTime);
                if (t != null) setState(() => _selectedTime = t);
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: l10n.amTime),
                child: Text('${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(labelText: l10n.amDurationMinutes),
          initialValue: _duration,
          items: [15, 30, 45, 60, 90, 120].map((d) => DropdownMenuItem(value: d, child: Text('$d ${l10n.amMinutes}'))).toList(),
          onChanged: (v) => setState(() => _duration = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(labelText: l10n.amNotes),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(l10n.createMeeting),
          ),
        ),
        ],
      ),
      ),
    );
  }
}

