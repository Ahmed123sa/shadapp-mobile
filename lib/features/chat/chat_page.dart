import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/reverb_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/chat_contract_card.dart';
import '../../core/widgets/payment_banner.dart';
import '../../core/widgets/payment_detail_sheet.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/helpers/meeting_helpers.dart';
import '../../core/helpers/realtime_poller.dart';
import '../../providers/chat_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/meeting_provider.dart';
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
      reverb.onMessageReceived = (payload) {
        final msg = payload['message'] as Map<String, dynamic>?;
        if (msg != null && mounted) {
          setState(() => _messages.add(msg));
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      };
      reverb.onMessageUpdated = (payload) {
        final msg = payload['message'] as Map<String, dynamic>?;
        if (msg != null && mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m['id'] == msg['id']);
            if (idx >= 0) _messages[idx] = msg;
          });
        }
      };
      reverb.onPaymentScheduleChanged = (_) {
        if (mounted) _checkWorkspace();
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
    } catch (e) {
      debugPrint('[chat_page] _checkWorkspace error: $e');
    }
  }

  Future<void> _load() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      _messages = await _chatProvider.fetchMessages(wsId);
    } catch (e) {
      debugPrint('[chat_page] _load error: $e');
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _wsId == null) return;
    _controller.clear();
    final replyId = _replyTo?['id'];
    setState(() => _replyTo = null);
    try {
      await _chatProvider.sendMessage(_wsId!, text, replyToId: replyId as int?);
      _load();
      _markRead();
    } catch (e) {
      debugPrint('[chat_page] _send error: $e');
    }
  }

  Future<void> _saveEdit() async {
    if (_editingMessage == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await _chatProvider.editMessage(_editingMessage!['id'] as int, text);
      setState(() {
        _editingMessage = null;
        _controller.clear();
      });
      _load();
    } catch (e) {
      debugPrint('[chat_page] _saveEdit error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.editFailed(e.toString()))));
    }
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
      debugPrint('[chat_page] _sendWithAttachment error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.attachmentSendFailed)));
    }
  }

  Future<void> _approve(int contractId) async {
    try {
      await _contractProvider.clientAction(contractId, 'approved');
      _load();
    } catch (e) {
      debugPrint('[chat_page] _approve error: $e');
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
      } catch (e) {
        debugPrint('[chat_page] _respondToMessage error: $e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.actionFailed)));
      }
    } else {
      try {
        await _chatProvider.respond(msgId, action: action);
        _load();
      } catch (e) {
        debugPrint('[chat_page] _respondToMessage error: $e');
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
        builder: (_) => _ContractsSheet(contracts: contracts),
      );
    } catch (e) {
      debugPrint('[chat_page] _openContracts error: $e');
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
    } catch (e) {
      debugPrint('[chat_page] _openLatestZoomLink error: $e');
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

  List<Widget> _buildMessageList() {
    final widgets = <Widget>[];
    String? lastDate;
    String? lastSenderKey;

    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final createdAt = m['created_at'] as String?;
      final dateKey = chatDateKey(createdAt);

      if (dateKey != null && dateKey != lastDate) {
        widgets.add(_dateSeparator(dateKey, createdAt));
        lastDate = dateKey;
        lastSenderKey = null;
      }

      final senderType = m['sender_type'] as String?;
      final isClient = senderType == 'App\\Models\\Client' || senderType == 'App\\Models\\SubUser';
      final isSubUserSender = senderType == 'App\\Models\\SubUser';
      final senderKey = '${senderType}_${m['sender_id']}';
      final isPending = m['requires_action'] == true && m['action_taken'] != true;
      final contract = m['contract'] as Map<String, dynamic>?;
      final hasContract = contract != null;
      final replyTo = m['reply_to'] as Map<String, dynamic>?;
      final type = m['type'] as String?;
      final metadata = m['metadata'] as Map<String, dynamic>?;
      final isConsecutive = senderKey == lastSenderKey;

      Widget bubble;
      if (type == 'meeting' && metadata != null) {
        bubble = chatMeetingBubble(metadata, m);
      } else if (hasContract) {
        bubble = _buildContractBubble(m, contract, isClient);
      } else {
        bubble = _buildTextBubble(m, isClient, isPending, replyTo, isConsecutive);
      }

      lastSenderKey = senderKey;

      widgets.add(
        GestureDetector(
          onLongPress: () => _showReplyMenu(m),
          child: Padding(
            padding: EdgeInsets.only(bottom: isConsecutive ? 2 : 9),
            child: Row(
              mainAxisAlignment: isClient ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isClient) ...[
                  if (!isConsecutive)
                    chatSenderAvatar(_api, m)
                  else
                    SizedBox(width: 28),
                  const SizedBox(width: 6),
                ],
                Flexible(child: bubble),
                if (isClient && isSubUserSender && !isConsecutive) ...[
                  const SizedBox(width: 6),
                  chatSenderAvatar(_api, m),
                ],
                if (isClient && !isSubUserSender && !isConsecutive) ...[
                  const SizedBox(width: 6),
                  chatSenderAvatar(_api, m),
                ],
                if (isClient && isConsecutive) const SizedBox(width: 40),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _dateSeparator(String dateKey, String? iso) {
    String label;
    if (iso == null) {
      label = '';
    } else {
      try {
        final dt = DateTime.parse(iso).toLocal();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final msgDate = DateTime(dt.year, dt.month, dt.day);
        final diff = today.difference(msgDate).inDays;
        if (diff == 0) {
          label = 'Today';
        } else if (diff == 1) {
          label = 'Yesterday';
        } else {
          label = '${dt.day} ${_monthName(dt.month)} ${dt.year}';
        }
      } catch (_) {
        label = '';
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        const Expanded(child: Divider(color: ShadColors.overlayMedium, thickness: 0.5, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: const TextStyle(fontSize: 9, color: ShadColors.textMuted)),
        ),
        const Expanded(child: Divider(color: ShadColors.overlayMedium, thickness: 0.5, height: 1)),
      ]),
    );
  }

  String _monthName(int month) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return month >= 1 && month <= 12 ? names[month] : '';
  }


  Widget _buildContractBubble(Map<String, dynamic> m, Map<String, dynamic> contract, bool isClient) {
    return Column(
      crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (m['message'] != null && m['message'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(m['message'], style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
          ),
        if (m['created_at'] != null && (m['message'] != null && m['message'].toString().isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(chatFormatTime(m['created_at'] as String?),
              style: const TextStyle(fontSize: 9, color: ShadColors.textDisabled)),
          ),
        ChatContractCard(
          contract: contract,
          isClient: isClient,
          onViewClauses: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => _ClausesSheet(clauses: contract['clauses'] as List<dynamic>? ?? []),
            );
          },
          onApprove: isClient && contract['status'] == 'sent' ? () => _approve(contract['id']) : null,
          onGoToPayments: isClient && contract['status'] == 'company_approved' ? widget.onGoToPayments : null,
        ),
      ],
    );
  }

  Widget _buildTextBubble(Map<String, dynamic> m, bool isClient, bool isPending, Map<String, dynamic>? replyTo, bool isConsecutive) {
    final senderType = m['sender_type'] as String?;
    final isSubUser = senderType == 'App\\Models\\SubUser';
    final sender = m['sender'] as Map<String, dynamic>?;
    final senderName = sender?['name'] as String?;

    Color bubbleColor;
    if (isSubUser) {
      bubbleColor = ShadColors.subUserBubble;
    } else if (isClient) {
      bubbleColor = ShadColors.primary;
    } else {
      bubbleColor = ShadColors.managerBubble;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isClient ? 12 : 3),
            bottomRight: Radius.circular(isClient ? 3 : 12),
          ),
          border: isClient ? null : Border.all(color: ShadColors.overlayMedium, width: 0.5),
        ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isClient && !isConsecutive && senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSubUser ? ShadColors.subUserNameColor : ShadColors.managerNameColor,
                    ),
                  ),
                ),
              if (isClient && isSubUser && !isConsecutive && senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    senderName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ShadColors.subUserNameColor,
                    ),
                  ),
                ),
              if (isClient && !isSubUser && !isConsecutive && senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ShadColors.gold,
                    ),
                  ),
                ),
            if (replyTo != null)
              Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: (isClient ? Colors.white : Colors.black).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border(left: BorderSide(color: ShadColors.crimson.withAlpha(100), width: 2)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(replyTo['sender']?['name'] ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: ShadColors.crimson)),
                  Text(replyTo['message'] ?? '', style: TextStyle(fontSize: 10, color: isClient ? Colors.white70 : ShadColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            if (m['type'] == 'file' && m['file_url'] != null)
              chatFileAttachment(
                api: _api,
                m: m,
                fallbackFileName: AppLocalizations.of(context)!.attachment,
                backgroundColor: ShadColors.chatBg,
                borderColor: ShadColors.chatBorder,
              ),
            Text(m['message'] ?? '', style: ShadTypography.chatBubble.copyWith(color: isClient ? Colors.white : ShadColors.textPrimary)),
            if (m['created_at'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(chatFormatTime(m['created_at'] as String?),
                      style: const TextStyle(fontSize: 9, color: ShadColors.textMuted)),
                    if (m['edited_at'] != null) ...[
                      const SizedBox(width: 3),
                      Text(AppLocalizations.of(context)!.edited, style: TextStyle(fontSize: 9, color: ShadColors.textMuted)),
                    ],
                    if (isClient && m['id'] != null) ...[
                      const SizedBox(width: 3),
                      Text(m['read_at'] != null ? '✓✓' : '✓',
                        style: const TextStyle(fontSize: 9, color: ShadColors.gold)),
                    ],
                  ],
                ),
              ),
            if (isPending)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: ShadColors.chatBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ShadColors.goldBorder, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)!.newApproval, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: ShadColors.gold, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text(m['message'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay', height: 1.3)),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: ShadColors.goldSoft,
                        border: Border(top: BorderSide(color: ShadColors.goldBorder, width: 0.5)),
                      ),
                      child: Text(AppLocalizations.of(context)!.needsYourApproval, style: const TextStyle(fontSize: 10, color: ShadColors.gold)),
                    ),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _respondToMessage(m['id'], 'edit_requested'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: ShadColors.chatBorder, width: 0.5)),
                                ),
                                child: Text(AppLocalizations.of(context)!.requestEdit, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ShadColors.textDisabled)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _respondToMessage(m['id'], 'approved'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: ShadColors.chatBorder, width: 0.5),
                                    left: BorderSide(color: ShadColors.chatBorder, width: 0.5),
                                  ),
                                ),
                                child: Text(AppLocalizations.of(context)!.approve, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ShadColors.crimson)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (m['action_taken'] == true)
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ShadColors.actionTakenBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadColors.actionTakenBorder, width: 0.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    m['action_result'] == 'approved' ? AppLocalizations.of(context)!.approvedLabel : m['action_result'] == 'rejected' ? AppLocalizations.of(context)!.rejectedLabel : AppLocalizations.of(context)!.editRequestedLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: m['action_result'] == 'approved' ? ShadColors.success : m['action_result'] == 'rejected' ? ShadColors.error : ShadColors.warning),
                  ),
                ]),
              ),
            if (m['approval']?['certificate']?['pdf_url'] != null)
              chatCertificateDownloadButton(
                state: this,
                api: _api,
                m: m,
                label: AppLocalizations.of(context)!.downloadApprovalCert,
                fileOpenFailedMessage: AppLocalizations.of(context)!.fileOpenFailed,
              ),
          ],
        ),
      ),
    );
  }

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

class _ContractsSheet extends StatelessWidget {
  final List<dynamic> contracts;
  const _ContractsSheet({required this.contracts});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(AppLocalizations.of(context)!.contracts, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const Divider(),
          Expanded(
            child: contracts.isEmpty
                ? Center(child: Text(AppLocalizations.of(context)!.noContracts, style: TextStyle(color: ShadColors.textSecondary)))
                : ListView.separated(
                    controller: scrollController,
                    itemCount: contracts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = contracts[i];
                      final status = c['status'] as String? ?? '';
                      final statusColor = statusColors[status] ?? ShadColors.textDisabled;
                      final statusLabel = statusLabels(AppLocalizations.of(context)!)[status] ?? status;
                      return ListTile(
                        leading: const Icon(Icons.description, size: 24, color: ShadColors.gold),
                        title: Text(c['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                          child: Text(statusLabel, style: TextStyle(fontSize: 10, color: statusColor)),
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

class _ClausesSheet extends StatelessWidget {
  final List<dynamic> clauses;
  const _ClausesSheet({required this.clauses});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(AppLocalizations.of(context)!.contractClauses, style: ShadTypography.cardTitle),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 12),
          if (clauses.isEmpty)
            Text(AppLocalizations.of(context)!.noClauses, style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary))
          else
            ...clauses.map((cl) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.circle, size: 6, color: ShadColors.textDisabled),
                const SizedBox(width: 8),
                Expanded(child: Text(cl['content'] ?? '', style: ShadTypography.cardBody)),
              ]),
            )),
        ],
      ),
    );
  }
}
