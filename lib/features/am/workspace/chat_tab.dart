import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/reverb_service.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/helpers/realtime_poller.dart';
import '../../../core/widgets/payment_detail_sheet.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/meeting_provider.dart';
import '../../chat/chat_page_widgets.dart' show LxMeetingBanner, LxPaymentBanner;
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
    if (_pollTick % 4 == 0) {
      _loadWorkspace();
      _loadMeetings();
    }
  });
  int _pollTick = 0;
  Map<String, dynamic>? _nextMeeting;
  Map<String, dynamic>? _nextPayment;
  Map<int, int?> _hostByMeetingId = {};
  bool _requestApproval = false;
  Map<String, dynamic>? _editingMessage;
  Map<String, dynamic>? _replyTo;
  int? get _wsId => widget.workspaceId ?? _api.workspaceId;
  late final ReverbService _reverb = widget.reverb ?? ReverbService();
  // plans/notifications-badges-toasts-plan.md ن15 — see the identical field
  // in client_dashboard_screen.dart for why this list exists.
  final List<VoidCallback> _reverbUnsubscribers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load().then((_) => _markRead());
    _loadWorkspace();
    _loadMeetings();
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
      _reverbUnsubscribers.add(reverb.addContractStatusChangedListener(() {
        if (mounted) _load();
      }));
      _reverbUnsubscribers.add(reverb.addPaymentScheduleChangedListener((_) {
        if (mounted) {
          _loadWorkspace();
          _loadMeetings();
        }
      }));
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
          _nextMeeting = nm;
          _nextPayment = np;
        });
      }
    } catch (e, s) {
      AppLog.error('chat_tab._loadWorkspace', e, s);
    }
  }

  Future<void> _loadMeetings() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      final meetings = await _meetingProvider.fetchForWorkspaceRaw(wsId);
      final hosts = <int, int?>{};
      for (final m in meetings) {
        if (m is Map) {
          final id = m['id'] as int?;
          if (id != null) {
            hosts[id] = m['host_user_id'] as int?;
          }
        }
      }
      if (mounted) {
        setState(() => _hostByMeetingId = hosts);
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      _messages = await _chatProvider.fetchMessages(wsId);
    } catch (e, s) {
      AppLog.error('chat_tab._load', e, s);
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
    } catch (e, s) {
      AppLog.error('chat_tab._requireAction', e, s);
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
      backgroundColor: Lx.sheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet))),
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
            if (!alreadyRequested && !isSA && _api.canDo('can_manage_approvals'))
              ListTile(
                leading: const Icon(Icons.how_to_reg, color: Lx.crimsonInk),
                title: Text(l10n.chatRequestClientApproval),
                subtitle: Text(l10n.chatApprovalRequestedHint),
                onTap: () {
                  Navigator.pop(ctx);
                  _requireAction(m['id']);
                },
              )
            else if (alreadyRequested)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Lx.ok),
                title: Text(l10n.chatApprovalAlreadyRequested),
              ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Lx.muted),
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
    } catch (e, s) {
      AppLog.error('chat_tab._sendWithAttachment', e, s);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.chatAttachFailed)));
    }
  }

  Future<void> _enterMeetingById(int meetingId) async {
    try {
      final res = await _meetingProvider.enterMeeting(meetingId);
      final uri = Uri.tryParse(res.url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      _loadMeetings();
    } catch (e, s) {
      AppLog.error('chat_tab._enterMeetingById', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ));
      }
    }
  }

  Future<void> _enterMeeting(Map<String, dynamic> m) async {
    final meetingId = m['id'] as int?;
    final isZoom = m['zoom_meeting_id'] != null;
    if (isZoom && meetingId != null) {
      await _enterMeetingById(meetingId);
    } else {
      final link = m['link'] as String?;
      final uri = link != null ? Uri.tryParse(link) : null;
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
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
    // plans/notifications-badges-toasts-plan.md ن15 — used to reconnect for
    // the AM's own user channel here to *override* the workspace channel
    // this screen had taken over, since only one channel could ever be
    // subscribed at a time. Now that connect(wsId) above is additive, the
    // user channel (joined by am_dashboard_page.dart before this screen ever
    // opened) was never dropped in the first place — this screen only needs
    // to leave the one channel it joined itself.
    final wsId = _wsId;
    if (wsId != null) {
      _reverb.leaveWorkspace(wsId);
    }
    for (final unsubscribe in _reverbUnsubscribers) {
      unsubscribe();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSA = _api.role == 'super_admin';
    final wsActive = widget.wsStatus == 'active';

    if (!wsActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LxIcon('lock', size: 44, color: Lx.faint),
              const SizedBox(height: 16),
              Text(l10n.chatWorkspaceLocked,
                style: Lx.text(context, size: 14, color: Lx.muted),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Column(children: [
      // Mockup wsChat: banners first, then the stream (no header row — the
      // contracts live in their own tab and the meeting banner has "Join").
      if (_nextMeeting != null || _nextPayment != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            if (_nextMeeting != null)
              LxMeetingBanner(meeting: _nextMeeting!, canJoin: !isSA, onTap: () => _enterMeeting(_nextMeeting!)),
            if (_nextPayment != null)
              LxPaymentBanner(payment: _nextPayment!, onTap: () => _onPaymentBannerTap(_nextPayment!)),
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
                    child: Center(child: Text(AppLocalizations.of(context)!.noMessagesYet, style: Lx.text(context, size: 14, color: Lx.muted))),
                  );
                }
                return _buildMessageList()[i];
              },
            ),
      ),
      // SA Read-Only Indicator (mockup `.viewonly`)
      if (isSA)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Lx.line))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const LxIcon('lock', size: 18, color: Lx.faint),
            const SizedBox(width: 8),
            Text(l10n.chatReadOnly, style: Lx.text(context, size: 12.5, color: Lx.faint)),
          ]),
        ),
      // Input Bar (AM, or an assistant with can_chat)
      if (!isSA && _api.canDo('can_chat'))
        Column(mainAxisSize: MainAxisSize.min, children: [
            // Mockup `.rq`: ring + "request client approval".
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _requestApproval = !_requestApproval),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 2),
                child: Row(children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _requestApproval ? Lx.crimson : null,
                      border: Border.all(color: _requestApproval ? Lx.crimson : Lx.faint, width: 1.5),
                    ),
                    child: _requestApproval ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.chatRequestClientApproval, style: Lx.text(context, size: 12, color: _requestApproval ? Lx.ink : Lx.muted)),
                ]),
              ),
            ),
            if (_replyTo != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 7, 16, 7),
                child: Row(children: [
                  Container(width: 2.5, height: 28, decoration: BoxDecoration(color: Lx.crimsonInk, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_replyTo!['sender']?['name'] ?? l10n.chatMessage, style: Lx.text(context, size: 10.5, color: Lx.crimsonInk, weight: FontWeight.w500)),
                    Text(_replyTo!['message'] ?? '', style: Lx.text(context, size: 11, color: Lx.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  GestureDetector(
                    onTap: () => setState(() => _replyTo = null),
                    child: const Icon(Icons.close, size: 16, color: Lx.faint),
                  ),
                ]),
              ),
            if (_editingMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  const Icon(Icons.edit, size: 14, color: Lx.crimsonInk),
                  const SizedBox(width: 6),
                  Text(l10n.chatEditMessage, style: Lx.text(context, size: 12, color: Lx.crimsonInk)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() { _editingMessage = null; _controller.clear(); }),
                    child: const Icon(Icons.close, size: 16, color: Lx.faint),
                  ),
                ]),
              ),
            // Staff without "send" on this client can read but not write (PLAN_2 ق٣).
            if (!_api.staffCan('can_send_chat'))
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 14),
                child: Text(
                  l10n.chatStaffReadOnly,
                  key: const ValueKey('chat-read-only'),
                  textAlign: TextAlign.center,
                  style: Lx.text(context, size: 12.5, color: Lx.faint),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 26),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Lx.line))),
                child: Row(children: [
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
                              hintText: _editingMessage != null ? l10n.chatEditYourMessage : l10n.typeMessage,
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
              ),
          ]),
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
    onEnterMeeting: _enterMeetingById,
    isHostFor: (meetingId) {
      final hostId = _hostByMeetingId[meetingId];
      return hostId == null || hostId == _api.userId;
    },
  );
}
