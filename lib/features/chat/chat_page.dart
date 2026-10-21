import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/helpers/signature_required_dialog.dart';
import '../../core/reverb_service.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
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
  final void Function({int? targetPaymentId})? onGoToPayments;
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
  // plans/notifications-badges-toasts-plan.md ن15 — see the identical field
  // in client_dashboard_screen.dart for why this list exists.
  final List<VoidCallback> _reverbUnsubscribers = [];

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
      _reverbUnsubscribers.add(reverb.addMessageReceivedListener(chatOnMessageReceived(
        state: this,
        setState: setState,
        // Guards against the same message arriving twice — a real
        // possibility since onError/onDone can both fire _reconnect() and
        // leave two live socket listeners for a moment (see
        // docs/mobile-review-2026-08-round2.md, #2 and #3). updateMessage
        // right below already keys off `id`; this didn't.
        addMessage: (msg) {
          if (_messages.any((m) => m['id'] == msg['id'])) return;
          _messages.add(msg);
        },
        scrollToBottom: _scrollToBottom,
      )));
      _reverbUnsubscribers.add(reverb.addMessageUpdatedListener(chatOnMessageUpdated(
        state: this,
        setState: setState,
        updateMessage: (msg) {
          final idx = _messages.indexWhere((m) => m['id'] == msg['id']);
          if (idx >= 0) _messages[idx] = msg;
        },
      )));
      _reverbUnsubscribers.add(reverb.addMessageDeletedListener(chatOnMessageDeleted(
        state: this,
        setState: setState,
        deleteMessage: (messageId) {
          _messages.removeWhere((m) => m['id'] == messageId);
        },
      )));
      _reverbUnsubscribers.add(reverb.addPaymentScheduleChangedListener((_) {
        if (mounted) _checkWorkspace();
      }));
      // Was missing here — chat_tab.dart (the AM-facing side of this same
      // chat feature) has always listened for this, so a contract getting
      // approved/rejected/etc. refreshes the AM's view live. The client's
      // own chat view had no equivalent, so a contract status change while
      // the client had this screen open would silently show stale bubble
      // state until the next fallback poll. See
      // docs/state-layer-migration-plan.md, بند ٥'s "اكتشاف جانبي".
      _reverbUnsubscribers.add(reverb.addContractStatusChangedListener(() {
        if (mounted) _load();
      }));
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
    // plans/notifications-badges-toasts-plan.md ن15 — used to reconnect for
    // the client's own channel here to *override* the workspace channel this
    // screen had taken over, since only one channel could ever be subscribed
    // at a time — which meant the notifications channel (joined by whichever
    // dashboard screen opened this chat) went silent for as long as the chat
    // was open. Now that connect(wsId) above is additive, that channel was
    // never dropped in the first place — this screen only needs to leave the
    // one channel it joined itself.
    final wsId = _wsId;
    if (wsId != null) {
      _reverb.leaveWorkspace(wsId);
    }
    for (final unsubscribe in _reverbUnsubscribers) {
      unsubscribe();
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
      if (mounted) await maybeShowSignatureRequiredDialog(context, e, isSubUser: _api.subUserId != null);
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
        if (!mounted) return;
        if (await maybeShowSignatureRequiredDialog(context, e, isSubUser: _api.subUserId != null)) return;
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
          Text(l10n.editRequestPrompt, style: Lx.text(ctx, size: 12.5, color: Lx.muted, height: 1.5)),
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
      showLuxeSheet(
        context,
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
            const LxIcon('lock', size: 44, color: Lx.faint),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noMessagesYet, style: Lx.display(context, size: 20)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.chatUnavailable,
                textAlign: TextAlign.center,
                style: Lx.text(context, size: 13, color: Lx.muted)),
          ]),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final amName = _workspaceData?['manager']?['name'] as String? ?? l10n.accountManager;
    final amOnline = chatIsOnline(_workspaceData?['manager']);

    Widget headerBtn(String key, IconData icon, VoidCallback onTap) => InkResponse(
          key: ValueKey(key),
          onTap: onTap,
          radius: 20,
          child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 18, color: Lx.muted)),
        );

    return Column(children: [
      // Slim header (the mockup has none; kept so the contracts list and the
      // latest meeting link stay reachable).
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 10, 6),
        child: Row(children: [
          LuxeStatusDot(status: amOnline ? LxStatus.ok : LxStatus.off),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: amName, style: Lx.text(context, size: 13, weight: FontWeight.w500)),
                TextSpan(text: '  ${amOnline ? l10n.online : l10n.offline}', style: Lx.text(context, size: 11, color: Lx.faint)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          headerBtn('chat-contracts', Icons.copy_outlined, _openContracts),
          headerBtn('chat-zoom', Icons.videocam_outlined, _openLatestZoomLink),
        ]),
      ),
      // Messages
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: Lx.crimsonInk))
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              itemCount: _messages.isEmpty ? 1 : _buildMessageList().length,
              itemBuilder: (_, i) {
                if (_messages.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(child: Text(l10n.noMessagesYet, style: Lx.text(context, size: 14, color: Lx.muted))),
                  );
                }
                return _buildMessageList()[i];
              },
            ),
      ),
      // Banners sit above the composer so the stream keeps the room.
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          if (_nextMeeting != null)
            LxMeetingBanner(meeting: _nextMeeting!, canJoin: _api.canDo('can_join_meetings')),
          if (_nextPayment != null && _api.canDo('can_view_payments'))
            LxPaymentBanner(payment: _nextPayment!, onTap: () => _onPaymentBannerTap(_nextPayment!)),
        ]),
      ),
      // Reply Preview
      if (_replyTo != null)
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 7, 16, 7),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Lx.line))),
          child: Row(children: [
            Container(width: 2.5, height: 28, decoration: BoxDecoration(color: Lx.crimsonInk, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_replyTo!['sender']?['name'] ?? 'Message', style: Lx.text(context, size: 10.5, color: Lx.crimsonInk, weight: FontWeight.w500)),
              Text(_replyTo!['message'] ?? '', style: Lx.text(context, size: 11, color: Lx.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: () => setState(() => _replyTo = null),
              child: const Icon(Icons.close, size: 16, color: Lx.faint),
            ),
          ]),
        ),
      // Composer — mockup `.composer`: clip + underlined field + crimson send.
      Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 8),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Lx.line))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_editingMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.edit, size: 14, color: Lx.crimsonInk),
                const SizedBox(width: 6),
                Text(l10n.editMessage, style: Lx.text(context, size: 12, color: Lx.crimsonInk)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() { _editingMessage = null; _controller.clear(); }),
                  child: const Icon(Icons.close, size: 16, color: Lx.faint),
                ),
              ]),
            ),
          Row(children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                child: Row(children: [
                  InkResponse(
                    key: const ValueKey('chat-attach'),
                    radius: 18,
                    onTap: _editingMessage != null ? null : _sendWithAttachment,
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: LxIcon('clip', size: 18, color: Lx.faint)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: Lx.text(context, size: 14),
                      cursorColor: Lx.crimsonInk,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        hintText: _editingMessage != null ? l10n.editYourMessage : l10n.typeMessage,
                        hintStyle: Lx.text(context, size: 14, color: Lx.faint),
                      ),
                      onSubmitted: (_) => _editingMessage != null ? _saveEdit() : _send(),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              key: const ValueKey('chat-send'),
              onTap: _editingMessage != null ? _saveEdit : _send,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Lx.crimson, shape: BoxShape.circle),
                child: Center(
                  child: _editingMessage != null
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : const LxIcon('send', size: 18, color: Colors.white),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  void _onPaymentBannerTap(Map<String, dynamic> payment) {
    final isDirectRequest = payment['due_date'] == null;
    final paymentId = (payment['id'] as num?)?.toInt();
    if (isDirectRequest) {
      widget.onGoToPayments?.call(targetPaymentId: paymentId);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => PaymentDetailSheet(
          payment: payment,
          showPayButton: true,
          onPay: () {
            Navigator.pop(context);
            widget.onGoToPayments?.call(targetPaymentId: paymentId);
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
    onGoToPayments: widget.onGoToPayments != null ? () => widget.onGoToPayments!.call() : null,
    onLongPressMessage: _showReplyMenu,
  );

  void _showReplyMenu(Map<String, dynamic> msg) {
    final isMine = (msg['sender_type'] == 'App\\Models\\Client' && msg['sender_id'] == _api.userId) ||
                   (msg['sender_type'] == 'App\\Models\\SubUser' && msg['sender_id'] == _api.subUserId);
    final canEdit = isMine && msg['type'] == 'text' && msg['approval_id'] == null;
    showLuxeSheet(
      context,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined, size: 18, color: Lx.muted),
                title: Text(AppLocalizations.of(context)!.edit, style: Lx.text(context, size: 14, color: Lx.ink)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingMessage = msg;
                    _controller.text = msg['message'] ?? '';
                  });
                },
              ),
            ListTile(
              leading: const LxIcon('reply', size: 18, color: Lx.muted),
              title: Text(AppLocalizations.of(context)!.reply, style: Lx.text(context, size: 14, color: Lx.ink)),
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
