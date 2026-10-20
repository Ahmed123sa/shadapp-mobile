import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../core/reverb_service.dart';
import '../../../data/staff_permissions.dart';
import '../../../data/approval_repository.dart';
import '../../../data/chat_repository.dart';
import '../../../data/client_repository.dart';
import '../../../data/file_repository.dart';
import '../../../data/meeting_repository.dart';
import '../../../data/payment_repository.dart';
import '../../../providers/approval_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/client_provider.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/file_provider.dart';
import '../../../providers/meeting_provider.dart';
import '../../../providers/payment_provider.dart';
import 'chat_tab.dart';
import 'files_tab.dart';
import 'calendar_tab.dart';
import 'contracts_tab.dart';
import 'payments_tab.dart';
import 'approvals_tab.dart';
import 'meetings_tab.dart';
import 'client_profile_tab.dart';
import 'team_tab.dart';

class AmWorkspacePage extends StatefulWidget {
  final int? workspaceId;
  final int initialTabIndex;
  // Step 0 of the state-layer migration plan: this screen doesn't call
  // ReverbService itself, but it embeds ChatTab (which does) inside an
  // IndexedStack — passed through so widget tests can inject
  // ReverbService.forTesting() and never open a real WebSocket. Defaults to
  // null, which falls back to the real singleton — zero behavior change for
  // every existing call site.
  final ReverbService? reverb;
  // Optional so this screen can be pumped in a widget test with a mocked
  // ApiClient instead of hitting the network. Defaults to the real
  // singleton — zero behavior change for every existing call site.
  final ApiClient? api;
  const AmWorkspacePage({super.key, this.workspaceId, this.initialTabIndex = 0, this.reverb, this.api});

  @override
  State<AmWorkspacePage> createState() => _AmWorkspacePageState();
}

class _AmWorkspacePageState extends State<AmWorkspacePage> with SingleTickerProviderStateMixin {
  late final ApiClient _api = widget.api ?? ApiClient();
  // Derived from `_api` purely to break the singleton fallback in the eight
  // tabs embedded via IndexedStack below (which mounts every tab eagerly, so
  // all of them need to be controllable from a test even though this screen's
  // own single domain — _fetchWorkspace — is the only one migrated this
  // slice). Each embedded tab still owns its own provider params for its own
  // testability; in production `_api` is always the real singleton, so this
  // changes nothing.
  late final ChatProvider _childChatProvider = ChatProvider(repository: ChatRepository(api: _api));
  late final ContractProvider _childContractProvider = ContractProvider(api: _api);
  late final MeetingProvider _childMeetingProvider = MeetingProvider(repository: MeetingRepository(api: _api));
  late final FileProvider _childFileProvider = FileProvider(repository: FileRepository(api: _api));
  late final PaymentProvider _childPaymentProvider = PaymentProvider(repository: PaymentRepository(api: _api));
  late final ApprovalProvider _childApprovalProvider = ApprovalProvider(repository: ApprovalRepository(api: _api));
  late final ClientProvider _childClientProvider = ClientProvider(repository: ClientRepository(api: _api));
  String? _wsStatus;
  String? _wsContactPerson;
  String? _wsName;
  String? _clientAvatar;
  String? _clientType;
  late TabController _tabController;

  bool get _isAssistant => _api.role == 'manager_assistant';
  // Company staff (STAFF_TEAMS_PLAN.md): chat, approval requests and meetings.
  bool get _isStaff => _api.role == 'staff_member';
  // Only the super admin and the client's account manager assign staff.
  bool get _canManageTeam => _api.role == 'super_admin' || _api.role == 'account_manager';
  // 0 chat, 1 files, 2 contracts, 3 payments, 4 approvals, 5 meetings,
  // 6 log (calendar), 7 client profile, 8 team (staff assignment).
  static const _tabCount = 9;
  bool _isTabVisible(int i) {
    // Staff only see the tabs they may view on THIS client (PLAN_2 ق٣).
    if (_isStaff) {
      if (i == 0) return _api.staffCan('can_view_chat');
      if (i == 4) return _api.staffCan('can_view_approvals');
      if (i == 5) return _api.staffCan('can_view_meetings');
      return false;
    }
    if (i == 8) return _canManageTeam;
    return !(_isAssistant && i == 3);
  }

  List<int> get _visibleTabs => [
        for (var i = 0; i < _tabCount; i++)
          if (_isTabVisible(i)) i,
      ];

  @override
  void initState() {
    super.initState();
    // Assistants never see money and staff only see three tabs, so some tabs
    // are left out. initialTabIndex still counts the full 9-tab layout (deep
    // links and notification routing use it), so map it onto the visible list.
    // A previous workspace's staff permissions must not leak into this one.
    _api.staffPermissions = null;
    _tabController = _newController(widget.initialTabIndex.clamp(0, _tabCount - 1));
    _fetchWorkspace();
  }

  /// A controller for the tabs visible right now; [fullIndex] is the tab of the
  /// full 9-tab layout to start on (falls back to the first visible one).
  TabController _newController(int fullIndex) {
    final visible = _visibleTabs;
    final visibleIndex = visible.indexOf(fullIndex);
    final c = TabController(length: visible.length, vsync: this, initialIndex: visibleIndex < 0 ? 0 : visibleIndex);
    c.addListener(_onTabChanged);
    return c;
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchWorkspace() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    try {
      final data = await _childChatProvider.fetchWorkspace(wsId);
      if (!mounted) return;
      final ws = data['workspace'] as Map<String, dynamic>?;
      final client = ws?['client'] as Map<String, dynamic>?;
      setState(() {
        _wsStatus = ws?['status'] as String?;
        _wsContactPerson = client?['contact_person'] as String?;
        _wsName = client?['company_name'] as String?;
        _clientAvatar = client?['avatar_url'] as String?;
        _clientType = client?['client_type'] as String?;
      });
      // A staff member's tabs depend on what they may view on THIS client, so
      // the tab set can change once the workspace has loaded.
      if (_isStaff) {
        final current = _visibleTabs.isEmpty ? null : _visibleTabs[_tabController.index.clamp(0, _visibleTabs.length - 1)];
        final before = _visibleTabs.join(',');
        _api.staffPermissions = normalizeStaffPermissions(ws?['my_staff_permissions']);
        if (_visibleTabs.join(',') != before) {
          final old = _tabController;
          old.removeListener(_onTabChanged);
          setState(() => _tabController = _newController(current ?? 0));
          old.dispose();
        } else {
          setState(() {});
        }
      }
    } catch (e, s) {
      AppLog.error('am_workspace_page._loadWorkspace', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _wsStatus == 'active';
    final l10n = AppLocalizations.of(context)!;
    // SafeArea(top: false): keeps the chat composer (and every tab's bottom
    // controls) above the Android gesture bar / iOS home indicator.
    return Scaffold(
      backgroundColor: Lx.page,
      body: SafeArea(top: false, child: LuxeGlow(child: Column(children: [
        // ── Header (mockup `.wsh`) ──
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 14, 10),
            child: Row(children: [
              InkResponse(
                key: const ValueKey('ws-back'),
                onTap: () => Navigator.pop(context),
                radius: 22,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Lx.line2)),
                  child: const Center(child: LxIcon('back', size: 18, color: Lx.muted)),
                ),
              ),
              const SizedBox(width: 10),
              if (_clientAvatar != null && _clientAvatar!.isNotEmpty)
                CircleAvatar(radius: 16, backgroundImage: NetworkImage(_clientAvatar!))
              else
                LuxeAvatar(initial: (_wsName ?? _wsContactPerson ?? '?').isEmpty ? '?' : (_wsName ?? _wsContactPerson ?? '?').substring(0, 1).toUpperCase()),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(_wsName ?? 'Workspace', maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.display(context, size: 16))),
                    const SizedBox(width: 6),
                    ClientTypeBadge(clientType: _clientType, compact: true),
                  ]),
                  if (_wsContactPerson != null)
                    Text(_wsContactPerson!, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                ]),
              ),
              Container(
                key: const ValueKey('ws-status'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Lx.rPill),
                  border: Border.all(color: isActive ? const Color(0x668FB98B) : Lx.line2),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  LuxeStatusDot(status: isActive ? LxStatus.ok : LxStatus.off),
                  const SizedBox(width: 7),
                  Text(isActive ? l10n.amStatusActive : l10n.amStatusInactive, style: Lx.text(context, size: 11, color: Lx.ink2)),
                ]),
              ),
            ]),
          ),
        ),
        // ── Tab Bar (mockup `.tabsx`) ──
        if (_visibleTabs.isNotEmpty)
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line))),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Lx.crimsonInk, width: 2),
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              labelColor: Lx.ink,
              unselectedLabelColor: Lx.muted,
              labelStyle: Lx.text(context, size: 12.5),
              unselectedLabelStyle: Lx.text(context, size: 12.5),
              tabs: [
                for (final i in _visibleTabs)
                  Tab(
                    height: 40,
                    text: [
                      l10n.workspaceTabChat,
                      l10n.workspaceTabFiles,
                      l10n.workspaceTabContracts,
                      l10n.workspaceTabPayments,
                      l10n.workspaceTabApprovals,
                      l10n.workspaceTabMeetings,
                      l10n.workspaceTabLog,
                      l10n.workspaceTabClientProfile,
                      l10n.workspaceTabTeam,
                    ][i],
                  ),
              ],
            ),
          ),
        // ── Tab Content ──
        Expanded(
          child: _visibleTabs.isEmpty
              // A staff member with nothing viewable on this client.
              ? Center(child: Text(l10n.mtNone, key: const ValueKey('workspace-no-access'), style: Lx.text(context, size: 14, color: Lx.muted)))
              : IndexedStack(
                  index: _tabController.index,
                  children: [for (final i in _visibleTabs) _tabChild(i)],
                ),
        ),
      ]))),
    );
  }

  /// The widget for a tab of the full 9-tab layout (see [_isTabVisible]).
  Widget _tabChild(int i) {
    switch (i) {
      case 0:
        return ChatTab(
          wsStatus: _wsStatus,
          workspaceId: widget.workspaceId,
          reverb: widget.reverb,
          api: _api,
          chatProvider: _childChatProvider,
          contractProvider: _childContractProvider,
          meetingProvider: _childMeetingProvider,
        );
      case 1:
        return FilesTab(workspaceId: widget.workspaceId, fileProvider: _childFileProvider, api: _api);
      case 2:
        return ContractsTab(workspaceId: widget.workspaceId, api: _api, contractProvider: _childContractProvider);
      case 3:
        return PaymentsTab(
          onWorkspaceUpdate: _fetchWorkspace,
          workspaceId: widget.workspaceId,
          paymentProvider: _childPaymentProvider,
          contractProvider: _childContractProvider,
          api: _api,
        );
      case 4:
        return ApprovalsTab(workspaceId: widget.workspaceId, approvalProvider: _childApprovalProvider, api: _api);
      case 5:
        return MeetingsTab(workspaceId: widget.workspaceId, meetingProvider: _childMeetingProvider, contractProvider: _childContractProvider, api: _api);
      case 6:
        return CalendarTab(
          workspaceId: widget.workspaceId,
          meetingProvider: _childMeetingProvider,
          contractProvider: _childContractProvider,
          paymentProvider: _childPaymentProvider,
          approvalProvider: _childApprovalProvider,
          api: _api,
        );
      case 7:
        return ClientProfileTab(workspaceId: widget.workspaceId, clientProvider: _childClientProvider, contractProvider: _childContractProvider, api: _api);
      default:
        return TeamTab(workspaceId: widget.workspaceId, api: _api, clientName: _wsName);
    }
  }
}
