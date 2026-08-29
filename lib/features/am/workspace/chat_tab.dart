import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/reverb_service.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/helpers/meeting_helpers.dart';
import '../../../core/helpers/realtime_poller.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../core/widgets/payment_banner.dart';
import '../../../core/widgets/payment_detail_sheet.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/meeting_provider.dart';
import '../../chat/chat_shared.dart';
import 'chat_tab_widgets.dart';

class ChatTab extends StatefulWidget {
  final int? workspaceId;
  final String? wsStatus;
  // Step 0 of the state-layer migration plan: lets widget tests suppress the
  // fallback-refresh Timer so `pumpAndSettle` doesn't hang on a pending
  // periodic timer. Defaults to true — zero behavior change for every
  // existing call site.
  final bool enablePolling;
  // Step 0 of the state-layer migration plan: lets widget tests inject a
  // ReverbService.forTesting() instance instead of the real singleton, so
  // pumping this screen never opens a real WebSocket. Defaults to null,
  // which falls back to the real singleton — zero behavior change for every
  // existing call site.
  final ReverbService? reverb;
  // Testability seam (state-layer migration plan) — optional so every
  // existing call site keeps compiling unchanged. Defaults fall back to the
  // real ApiClient instance. Provider params are added one at a time, in the
  // same commit as the domain that starts actually using them — adding them
  // any earlier would leave an unused field and fail `flutter analyze`.
  final ApiClient? api;
  final ChatProvider? chatProvider;
  final ContractProvider? contractProvider;
  final MeetingProvider? meetingProvider;
  const ChatTab({
    super.key,
    this.workspaceId,
    this.wsStatus,
    this.enablePolling = true,
    this.reverb,
    this.api,
    this.chatProvider,
    this.contractProvider,
    this.meetingProvider,
  });

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> with WidgetsBindingObserver {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ChatProvider _chatProvider = widget.chatProvider ?? ChatProvider();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider();
  late final MeetingProvider _meetingProvider = widget.meetingProvider ?? MeetingProvider();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  // Fallback refresh only — live updates arrive over the Reverb socket, so
  // this stays quiet while that socket is healthy. See RealtimePoller.
  late final RealtimePoller _poller = RealtimePoller(onRefresh: () {
    _load();
    _pollTick++;
    // The workspace header (next meeting / next payment) changes far less
    // often than the messages do, so it rides along every fourth refresh.
    if (_pollTick % 4 == 0) _loadWorkspace();
  });
  int _pollTick = 0;
  Map<String, dynamic>? _workspaceData;
  Map<String, dynamic>? _nextMeeting;
  Map<String, dynamic>? _nextPayment;
  bool _requestApproval = false;
  Map<String, dynamic>? _editingMessage;
  Map<String, dynamic>? _replyTo;
  int? get _wsId => widget.workspaceId ?? _api.workspaceId;
  late final ReverbService _reverb = widget.reverb ?? ReverbService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load().then((_) => _markRead());
    _loadWorkspace();
    _startPolling();
    _scrollController.addListener(_onScroll);
    final wsId = _wsId;
    if (wsId != null) {
      final reverb = _reverb;
      reverb.onMessageReceived = chatOnMessageReceived(
        state: this,
        setState: setState,
        addMessage: (msg) => _messages.add(msg),
        scrollToBottom: _scrollToBottom,
      );
      reverb.onMessageUpdated = chatOnMessageUpdated(
        state: this,
        setState: setState,
        updateMessage: (msg) {
          final idx = _messages.indexWhere((m) => m['id'] == msg['id']);
          if (idx >= 0) _messages[idx] = msg;
        },
      );
      reverb.onContractStatusChanged = () {
        if (mounted) _load();
      };
      reverb.onPaymentScheduleChanged = (_) {
        if (mounted) _loadWorkspace();
      };
      reverb.connect(wsId);
    }
  }

  void _startPolling() {
    if (!widget.enablePolling) return;
    _poller.start();
  }

  Future<void> _loadWorkspace() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      final data = await _chatProvider.fetchWorkspace(wsId);
      final nm = data['nextMeeting'] as Map<String, dynamic>?;
      final np = data['nextPayment'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _workspaceData = data['workspace'] as Map<String, dynamic>?;
          _nextMeeting = nm;
          _nextPayment = np;
        });
      }
    } catch (e) {
      debugPrint('[chat_tab] _loadWorkspace error: $e');
    }
  }

  Future<void> _load() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      _messages = await _chatProvider.fetchMessages(wsId);
    } catch (e) {
      debugPrint('[chat_tab] _load error: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _markRead() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      await _chatProvider.markRead(wsId);
    } catch (e, s) {
      // Cosmetic only — the unread badge stays until the next successful
      // mark-read. Not worth interrupting the user for.
      AppLog.error('chat_tab._markRead', e, s);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50;
    if (atBottom) _markRead();
  }

  Future<void> _send() => chatSend(
    controller: _controller,
    wsId: _wsId,
    replyTo: _replyTo,
    chatProvider: _chatProvider,
    setState: setState,
    clearReplyTo: () => _replyTo = null,
    load: _load,
    markRead: _markRead,
    consumeRequiresAction: () {
      final needsApproval = _requestApproval;
      if (_requestApproval) setState(() => _requestApproval = false);
      return needsApproval;
    },
    logTag: 'chat_tab',
  );

  Future<void> _saveEdit() => chatSaveEdit(
    controller: _controller,
    editingMessage: _editingMessage,
    chatProvider: _chatProvider,
    state: this,
    setState: setState,
    clearEditingMessage: () => _editingMessage = null,
    load: _load,
    editFailedMessage: (e) => '${AppLocalizations.of(context)!.chatEditFailed}: $e',
    logTag: 'chat_tab',
  );

  Future<void> _requireAction(int msgId) async {
    if (_wsId == null) return;
    try {
      await _chatProvider.requireAction(msgId);
      _load();
    } catch (e) {
      debugPrint('[chat_tab] _requireAction error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.chatApprovalRequestFailed)));
    }
  }

  void _showMessageActions(dynamic m) {
    final isSA = _api.role == 'super_admin';
    final isOwnMessage = m['sender_type'] == 'App\\Models\\User'
        && m['sender_id'].toString() == _api.userId.toString();
    final canEdit = isOwnMessage && m['type'] == 'text' && m['approval_id'] == null;
    final alreadyRequested = m['requires_action'] == true;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.reply, size: 18),
              title: Text(l10n.chatReplyAction, style: const TextStyle(fontSize: 14)),
              dense: true,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyTo = m);
              },
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit, size: 18),
                title: Text(l10n.chatEditAction),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _editingMessage = m;
                    _controller.text = m['message'] ?? '';
                  });
                },
              ),
            if (!alreadyRequested && !isSA)
              ListTile(
                leading: const Icon(Icons.how_to_reg, color: ShadColors.primary),
                title: Text(l10n.chatRequestClientApproval),
                subtitle: Text(l10n.chatApprovalRequestedHint),
                onTap: () {
                  Navigator.pop(ctx);
                  _requireAction(m['id']);
                },
              )
            else if (alreadyRequested)
              ListTile(
                leading: const Icon(Icons.check_circle, color: ShadColors.success),
                title: Text(l10n.chatApprovalAlreadyRequested),
              ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: ShadColors.textSecondary),
              title: Text(l10n.chatMessageDetails),
              subtitle: Text('${m['message'] ?? l10n.chatNoText}'),
              onTap: () => Navigator.pop(ctx),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _sendWithAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
    );
    if (result == null || result.files.isEmpty || _wsId == null) return;
    final file = File(result.files.single.path!);
    try {
      await _chatProvider.uploadFile(_wsId!, file);
      _load();
    } catch (e) {
      debugPrint('[chat_tab] _sendWithAttachment error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.chatAttachFailed)));
    }
  }

  Future<void> _openContracts() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      final contracts = await _contractProvider.fetchWorkspaceContractsRaw(wsId);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => ContractsSheet(contracts: contracts),
      );
    } catch (e) {
      debugPrint('[chat_tab] _openContracts error: $e');
    }
  }

  Future<void> _openLatestZoomLink() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      final meetings = await _meetingProvider.fetchForWorkspaceRaw(wsId);
      if (!mounted) return;
      String? zoomLink;
      String? scheduledAt;
      for (final m in meetings.reversed) {
        final link = m['link'] as String?;
        final status = m['status'] as String?;
        if (link != null && status == 'scheduled') {
          zoomLink = link;
          scheduledAt = m['scheduled_at'] as String?;
          break;
        }
      }
      if (zoomLink == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.chatNoActiveMeeting)));
        return;
      }
      if (scheduledAt != null) {
        final joinStatus = getMeetingJoinStatus(scheduledAt, AppLocalizations.of(context)!);
        if (!joinStatus.canJoin) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(joinStatus.label)));
          return;
        }
      }
      final uri = Uri.tryParse(zoomLink);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[chat_tab] _openLatestZoomLink error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _poller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _startPolling();
      _load();
      _loadWorkspace();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller.stop();
    _controller.dispose();
    _scrollController.dispose();
    final uid = _api.userId;
    if (uid != null) {
      _reverb.connectForUser(uid);
    } else {
      _reverb.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSA = _api.role == 'super_admin';
    final clientName = _workspaceData?['client']?['contact_person'] as String? ?? l10n.chatClient;
    final clientAvatarUrl = _workspaceData?['client']?['avatar_url'] as String?;
    final clientOnline = chatIsOnline(_workspaceData?['client']);
    final wsActive = widget.wsStatus == 'active';

    if (!wsActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 48, color: ShadColors.textDisabled),
              const SizedBox(height: 16),
              Text(l10n.chatWorkspaceLocked,
                style: const TextStyle(fontSize: 14, color: ShadColors.textSecondary),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Column(children: [
      // Chat Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: ShadColors.chatHeaderBg,
          border: Border(bottom: BorderSide(color: ShadColors.cardBorder)),
        ),
        child: Row(children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: ShadColors.goldSoft,
                backgroundImage: clientAvatarUrl != null ? NetworkImage(_api.resolveFileUrl(clientAvatarUrl)) : null,
                child: clientAvatarUrl == null ? Text(chatInitials(clientName),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold)) : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                  child: Container(
                    width: 9, height: 9,
                    decoration: BoxDecoration(
                      color: clientOnline ? ShadColors.online : ShadColors.textDisabled,
                      shape: BoxShape.circle,
                      border: Border.all(color: ShadColors.chatHeaderBg, width: 1.5),
                    ),
                  ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(clientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.textPrimary))),
              const SizedBox(width: 6),
              ClientTypeBadge(clientType: _workspaceData?['client']?['client_type'] as String?, compact: true),
            ]),
            const SizedBox(height: 1),
            Text(clientOnline ? l10n.chatOnline : l10n.chatOffline,
              style: TextStyle(fontSize: 10, color: clientOnline ? ShadColors.online : ShadColors.textDisabled)),
          ])),
          chatHeaderIconBtn(Icons.copy_outlined, _openContracts),
          const SizedBox(width: 6),
          chatHeaderIconBtn(Icons.videocam_outlined, _openLatestZoomLink),
        ]),
      ),
      // Upcoming Meeting Banner
      if (_nextMeeting != null) chatUpcomingMeetingBanner(
        meeting: _nextMeeting!,
        fallbackTitle: l10n.chatUpcomingMeeting,
        inMinutesLabel: l10n.chatInMinutes,
        inHoursLabel: l10n.chatInHours,
        inDaysLabel: l10n.chatInDays,
        joinLabel: l10n.chatJoin,
      ),
      // Upcoming Payment Banner
      if (_nextPayment != null)
        PaymentBanner(
          payment: _nextPayment!,
          onTap: () => _onPaymentBannerTap(_nextPayment!),
        ),
      // Messages
      Expanded(
        child: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: ShadColors.chatBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: ShadColors.cardBorder, width: 0.5)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(height: 14, width: 140, decoration: BoxDecoration(color: ShadColors.cardBorder, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 100, decoration: BoxDecoration(color: ShadColors.cardBorder, borderRadius: BorderRadius.circular(6))),
                    ]),
                  ),
                ),
              ),
            )
          : _messages.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noMessagesYet, style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(14),
                  itemCount: _buildMessageList().length,
                  itemBuilder: (_, i) => _buildMessageList()[i],
                ),
      ),
      // SA Read-Only Indicator
      if (isSA)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: ShadColors.chatHeaderBg,
            border: Border(top: BorderSide(color: ShadColors.cardBorder, width: 0.5)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.visibility, size: 14, color: ShadColors.textSecondary),
            const SizedBox(width: 8),
            Text(l10n.chatReadOnly, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
          ]),
        ),
      // Input Bar (AM only)
      if (!isSA)
        Container(
          decoration: const BoxDecoration(
            color: ShadColors.chatHeaderBg,
            border: Border(top: BorderSide(color: ShadColors.cardBorder, width: 0.5)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => setState(() => _requestApproval = !_requestApproval),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(children: [
                  Icon(
                    _requestApproval ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: _requestApproval ? ShadColors.gold : ShadColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.chatRequestClientApproval,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _requestApproval ? FontWeight.w700 : FontWeight.w400,
                      color: _requestApproval ? ShadColors.gold : ShadColors.textSecondary,
                    ),
                  ),
                ]),
              ),
            ),
            if (_replyTo != null)
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 7, 14, 7),
                decoration: const BoxDecoration(
                  color: ShadColors.chatHeaderBg,
                  border: Border(top: BorderSide(color: ShadColors.cardBorder, width: 0.5)),
                ),
                child: Row(children: [
                  Container(width: 2.5, height: 26, decoration: BoxDecoration(
                    color: ShadColors.crimson, borderRadius: BorderRadius.circular(2),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_replyTo!['sender']?['name'] ?? l10n.chatMessage, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: ShadColors.crimson)),
                    Text(_replyTo!['message'] ?? '', style: const TextStyle(fontSize: 9.5, color: ShadColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  GestureDetector(
                    onTap: () => setState(() => _replyTo = null),
                    child: const Text('✕', style: TextStyle(fontSize: 12, color: ShadColors.textDisabled)),
                  ),
                ]),
              ),
            if (_editingMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(children: [
                  const Icon(Icons.edit, size: 14, color: ShadColors.gold),
                  const SizedBox(width: 6),
                  Text(l10n.chatEditMessage, style: const TextStyle(fontSize: 12, color: ShadColors.gold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() { _editingMessage = null; _controller.clear(); }),
                    child: const Icon(Icons.close, size: 16, color: ShadColors.textSecondary),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(13, 0, 13, 9),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: ShadColors.overlayFaint,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: ShadColors.cardBorder, width: 0.5),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.attach_file, size: 14),
                    onPressed: _editingMessage != null ? null : _sendWithAttachment,
                    color: ShadColors.textSecondary,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: _editingMessage != null ? l10n.chatEditYourMessage : l10n.typeMessage,
                      hintStyle: const TextStyle(fontSize: 12, color: ShadColors.textDim),
                      filled: true,
                      fillColor: ShadColors.chatInputFill,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: ShadColors.overlaySoft, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: ShadColors.overlaySoft, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: ShadColors.gold, width: 1),
                      ),
                    ),
                    onSubmitted: (_) => _editingMessage != null ? _saveEdit() : _send(),
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _editingMessage != null ? ShadColors.gold : ShadColors.crimson,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _editingMessage != null ? Icons.check : Icons.send_rounded,
                      color: Colors.white, size: 14,
                    ),
                    onPressed: _editingMessage != null ? _saveEdit : _send,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ]),
            ),
          ]),
        ),
    ]);
  }

  void _onPaymentBannerTap(Map<String, dynamic> payment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentDetailSheet(
        payment: payment,
        showPayButton: false,
      ),
    );
  }

  List<Widget> _buildMessageList() => buildChatTabMessageList(
    context: context,
    state: this,
    messages: _messages,
    api: _api,
    onLongPressMessage: _showMessageActions,
  );
}
