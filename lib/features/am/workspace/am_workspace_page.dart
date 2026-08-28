import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../core/reverb_service.dart';
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
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 7));
    _tabController.addListener(_onTabChanged);
    _fetchWorkspace();
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
    } catch (e, s) {
      AppLog.error('am_workspace_page._loadWorkspace', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _wsStatus == 'active';
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(children: [
        // ── Compact Header ──
        Container(
          color: ShadColors.surfaceDarker,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 8),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: ShadColors.crimson.withAlpha(40),
                backgroundImage: _clientAvatar != null && _clientAvatar!.isNotEmpty ? NetworkImage(_clientAvatar!) : null,
                child: _clientAvatar == null || _clientAvatar!.isEmpty
                    ? Text((_wsContactPerson ?? '?').substring(0, 1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.crimson))
                    : null,
              ),
            ]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(_wsName ?? 'Workspace', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay'))),
                  const SizedBox(width: 6),
                  ClientTypeBadge(clientType: _clientType, compact: true),
                ]),
                if (_wsContactPerson != null)
                  Text(_wsContactPerson!, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? ShadColors.success.withAlpha(25) : ShadColors.crimson.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? ShadColors.success.withAlpha(80) : ShadColors.crimson.withAlpha(80)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: isActive ? ShadColors.success : ShadColors.crimson, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(isActive ? l10n.amStatusActive : l10n.amStatusInactive, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? ShadColors.success : ShadColors.crimson)),
              ]),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: ShadColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: ShadColors.cardBorder)),
                child: const Icon(Icons.keyboard_arrow_left, size: 20, color: ShadColors.textSecondary),
              ),
            ),
          ]),
        ),
        // ── Tab Bar ──
        Container(
          color: ShadColors.surfaceDarker,
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            indicatorColor: ShadColors.gold,
            indicatorWeight: 2.5,
            labelColor: ShadColors.textPrimary,
            unselectedLabelColor: ShadColors.textSecondary,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            tabs: [
              Tab(text: l10n.workspaceTabChat),
              Tab(text: l10n.workspaceTabFiles),
              Tab(text: l10n.workspaceTabContracts),
              Tab(text: l10n.workspaceTabPayments),
              Tab(text: l10n.workspaceTabApprovals),
              Tab(text: l10n.workspaceTabMeetings),
              Tab(text: l10n.workspaceTabLog),
              Tab(text: l10n.workspaceTabClientProfile),
            ],
          ),
        ),
        // ── Tab Content ──
        Expanded(
          child: IndexedStack(
            index: _tabController.index,
            children: [
              ChatTab(
                wsStatus: _wsStatus,
                workspaceId: widget.workspaceId,
                reverb: widget.reverb,
                api: _api,
                chatProvider: _childChatProvider,
                contractProvider: _childContractProvider,
                meetingProvider: _childMeetingProvider,
              ),
              FilesTab(workspaceId: widget.workspaceId, fileProvider: _childFileProvider, api: _api),
              ContractsTab(workspaceId: widget.workspaceId, api: _api),
              PaymentsTab(
                onWorkspaceUpdate: _fetchWorkspace,
                workspaceId: widget.workspaceId,
                paymentProvider: _childPaymentProvider,
                contractProvider: _childContractProvider,
                api: _api,
              ),
              ApprovalsTab(workspaceId: widget.workspaceId, approvalProvider: _childApprovalProvider, api: _api),
              MeetingsTab(workspaceId: widget.workspaceId, meetingProvider: _childMeetingProvider, contractProvider: _childContractProvider),
              CalendarTab(
                workspaceId: widget.workspaceId,
                meetingProvider: _childMeetingProvider,
                contractProvider: _childContractProvider,
                paymentProvider: _childPaymentProvider,
                approvalProvider: _childApprovalProvider,
                api: _api,
              ),
              ClientProfileTab(workspaceId: widget.workspaceId, clientProvider: _childClientProvider, contractProvider: _childContractProvider, api: _api),
            ],
          ),
        ),
      ]),
    );
  }

}
