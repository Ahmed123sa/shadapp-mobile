import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/reverb_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/payment_banner.dart';
import '../../core/widgets/payment_detail_sheet.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/helpers/meeting_helpers.dart';
import '../../core/helpers/realtime_poller.dart';
import '../../providers/chat_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/meeting_provider.dart';
import 'chat_page_widgets.dart';
import 'chat_shared.dart';

class ChatPage extends StatefulWidget {
  final VoidCallback? onGoToPayments;
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

  const ChatPage({super.key, this.onGoToPayments, this.enablePolling = true, this.reverb, this.api, this.chatProvider, this.contractProvider, this.meetingProvider});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ChatProvider _chatProvider = widget.chatProvider ?? ChatProvider();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider();
  late final MeetingProvider _meetingProvider = widget.meetingProvider ?? MeetingProvider();
  // No cross-tenant fallback (see docs/state-layer-migration-plan.md, P0-1):
  // a null workspaceId means "we don't know this client's workspace yet",
  // not "assume workspace 1". Every call site below guards on this being
  // null instead, same pattern as am/workspace/chat_tab.dart's _wsId.
  int? get _wsId => _api.workspaceId;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _workspaceActive = true;
  // Fallback refresh only — live updates arrive over the Reverb socket, so
  // this stays quiet while that socket is healthy. See RealtimePoller.
  late final RealtimePoller _poller = RealtimePoller(onRefresh: () {
    _load();
    _checkWorkspace();
  });
  Map<String, dynamic>? _replyTo;
  Map<String, dynamic>? _editingMessage;
  Map<String, dynamic>? _workspaceData;
  Map<String, dynamic>? _nextMeeting;
  late final ReverbService _reverb = widget.reverb ?? ReverbService();
  Map<String, dynamic>? _nextPayment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkWorkspace();
    _load().then((_) => _markRead());
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
      reverb.onPaymentScheduleChanged = (_) {
        if (mounted) _checkWorkspace();
      };
      // Was missing here — chat_tab.dart (the AM-facing side of this same
      // chat feature) has always listened for this, so a contract getting
      // approved/rejected/etc. refreshes the AM's view live. The client's
      // own chat view had no equivalent, so a contract status change while
      // the client had this screen open would silently show stale bubble
      // state until the next fallback poll. See
      // docs/state-layer-migration-plan.md, بند ٥'s "اكتشاف جانبي".
      reverb.onContractStatusChanged = () {
        if (mounted) _load();
      };
      reverb.connect(wsId);
    }
  }

  void _startPolling() {
    if (!widget.enablePolling) return;
    _poller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _poller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _startPolling();
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller.stop();
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    final cid = _api.userId;
    if (cid != null) {
      _reverb.connectForClient(cid);
    } else {
      _reverb.disconnect();
    }
    super.dispose();
  }

  Future<void> _checkWorkspace() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      final data = await _chatProvider.fetchWorkspace(wsId);
      final ws = data['workspace'] as Map<String, dynamic>?;
      final nm = data['nextMeeting'] as Map<String, dynamic>?;
      final np = data['nextPayment'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _workspaceData = ws;
          _workspaceActive = ws?['status'] == 'active';
          _nextMeeting = nm;
          _nextPayment = np;
        });
      }
    } catch (e, s) {
      AppLog.error('chat_page._checkWorkspace', e, s);
    }
  }

  Future<void> _load() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      _messages = await _chatProvider.fetchMessages(wsId);
    } catch (e, s) {
      AppLog.error('chat_page._load', e, s);
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
      AppLog.error('chat_page._markRead', e, s);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
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
    consumeRequiresAction: () => false,
    logTag: 'chat_page',
  );

  Future<void> _saveEdit() => chatSaveEdit(
    controller: _controller,
    editingMessage: _editingMessage,
    chatProvider: _chatProvider,
    state: this,
    setState: setState,
    clearEditingMessage: () => _editingMessage = null,
    load: _load,
    editFailedMessage: (e) => AppLocalizations.of(context)!.editFailed(e.toString()),
    logTag: 'chat_page',
  );

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
    } catch (e, s) {
      AppLog.error('chat_page._sendWithAttachment', e, s);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.attachmentSendFailed)));
    }
  }

  Future<void> _approve(int contractId) async {
    try {
      await _contractProvider.clientAction(contractId, 'approved');
      _load();
    } catch (e, s) {
      AppLog.error('chat_page._approve', e, s);
    }
  }

  Future<void> _respondToMessage(int msgId, String action) async {
    if (action == 'edit_requested') {
      final reason = await _showEditRequestDialog();
      if (reason == null) return;
      try {
        await _chatProvider.respond(msgId, action: action, reason: reason);
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.edit, color: Colors.orange, size: 18), const SizedBox(width: 8), Text(l10n.editRequestedToast)])));
          _load();
        }
      } catch (e, s) {
        AppLog.error('chat_page._respondToMessage(edit_requested)', e, s);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.actionFailed)));
      }
    } else {
      try {
        await _chatProvider.respond(msgId, action: action);
        _load();
      } catch (e, s) {
        AppLog.error('chat_page._respondToMessage', e, s);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.actionFailed)));
      }
    }
  }

  Future<String?> _showEditRequestDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
        title: Text(l10n.editRequestTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.editRequestPrompt, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.editRequestHint),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.gold),
            child: Text(l10n.send),
          ),
        ],
      );},
    );
    return result;
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
    } catch (e, s) {
      AppLog.error('chat_page._openContracts', e, s);
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.noActiveMeeting)));
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
    } catch (e, s) {
      AppLog.error('chat_page._openLatestZoomLink', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_workspaceActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 64, color: ShadColors.textDisabled),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noMessagesYet, style: ShadTypography.cardTitle),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.chatUnavailable,
                style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
          ]),
        ),
      );
    }

    final amName = _workspaceData?['manager']?['name'] as String? ?? AppLocalizations.of(context)!.accountManager;
    final amOnline = chatIsOnline(_workspaceData?['manager']);
    final amAvatarUrl = _workspaceData?['manager']?['avatar_url'] as String?;

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
                backgroundColor: ShadColors.crimsonSoft,
                backgroundImage: amAvatarUrl != null ? NetworkImage(_api.resolveFileUrl(amAvatarUrl)) : null,
                child: amAvatarUrl == null ? Text(chatInitials(amName),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold)) : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 9, height: 9,
                  decoration: BoxDecoration(
                    color: amOnline ? ShadColors.online : ShadColors.textDisabled,
                    shape: BoxShape.circle,
                    border: Border.all(color: ShadColors.chatHeaderBg, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(amName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
            const SizedBox(height: 1),
            Text(amOnline ? AppLocalizations.of(context)!.online : AppLocalizations.of(context)!.offline,
              style: TextStyle(fontSize: 10, color: amOnline ? ShadColors.online : ShadColors.textDisabled)),
          ])),
          chatHeaderIconBtn(Icons.copy_outlined, _openContracts),
          const SizedBox(width: 6),
          chatHeaderIconBtn(Icons.videocam_outlined, _openLatestZoomLink),
        ]),
      ),
      // Upcoming Meeting Banner
      if (_nextMeeting != null) chatUpcomingMeetingBanner(
        meeting: _nextMeeting!,
        fallbackTitle: AppLocalizations.of(context)!.upcomingMeeting,
        inMinutesLabel: AppLocalizations.of(context)!.inMinutes,
        inHoursLabel: AppLocalizations.of(context)!.inHours,
        inDaysLabel: AppLocalizations.of(context)!.inDays,
        joinLabel: AppLocalizations.of(context)!.join,
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
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noMessagesYet, style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(14),
                  itemCount: _buildMessageList().length,
                  itemBuilder: (_, i) => _buildMessageList()[i],
                ),
      ),
      // Reply Preview
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
              Text(_replyTo!['sender']?['name'] ?? 'Message', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: ShadColors.crimson)),
              Text(_replyTo!['message'] ?? '', style: const TextStyle(fontSize: 9.5, color: ShadColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: () => setState(() => _replyTo = null),
              child: const Text('✕', style: TextStyle(fontSize: 12, color: ShadColors.textDisabled)),
            ),
          ]),
        ),
      // Input Bar
      Container(
        padding: const EdgeInsetsDirectional.fromSTEB(13, 9, 13, 9),
        decoration: const BoxDecoration(
          color: ShadColors.chatHeaderBg,
          border: Border(top: BorderSide(color: ShadColors.cardBorder, width: 0.5)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_editingMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: ShadColors.gold.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.edit, size: 14, color: ShadColors.gold),
                const SizedBox(width: 6),
                Text(AppLocalizations.of(context)!.editMessage, style: const TextStyle(fontSize: 12, color: ShadColors.gold)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() { _editingMessage = null; _controller.clear(); }),
                  child: const Icon(Icons.close, size: 16, color: ShadColors.textSecondary),
                ),
              ]),
            ),
          Row(children: [
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
                  hintText: _editingMessage != null ? AppLocalizations.of(context)!.editYourMessage : AppLocalizations.of(context)!.typeMessage,
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
        ]),
      ),
    ]);
  }

  void _onPaymentBannerTap(Map<String, dynamic> payment) {
    final isDirectRequest = payment['due_date'] == null;
    if (isDirectRequest) {
      widget.onGoToPayments?.call();
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => PaymentDetailSheet(
          payment: payment,
          showPayButton: true,
          onPay: () {
            Navigator.pop(context);
            widget.onGoToPayments?.call();
          },
        ),
      );
    }
  }

  List<Widget> _buildMessageList() => buildChatMessageList(
    context: context,
    state: this,
    messages: _messages,
    api: _api,
    onApprove: _approve,
    onRespondToMessage: _respondToMessage,
    onGoToPayments: widget.onGoToPayments,
    onLongPressMessage: _showReplyMenu,
  );

  void _showReplyMenu(Map<String, dynamic> msg) {
    final isMine = (msg['sender_type'] == 'App\\Models\\Client' && msg['sender_id'] == _api.userId) ||
                   (msg['sender_type'] == 'App\\Models\\SubUser' && msg['sender_id'] == _api.subUserId);
    final canEdit = isMine && msg['type'] == 'text' && msg['approval_id'] == null;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit, color: ShadColors.textPrimary),
                title: Text(AppLocalizations.of(context)!.edit, style: const TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingMessage = msg;
                    _controller.text = msg['message'] ?? '';
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply, color: ShadColors.textPrimary),
              title: Text(AppLocalizations.of(context)!.reply, style: const TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyTo = msg);
              },
            ),
          ]),
        ),
      ),
    );
  }
}
