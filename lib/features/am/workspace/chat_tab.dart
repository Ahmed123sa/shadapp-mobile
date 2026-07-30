import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/reverb_service.dart';
import '../../../core/theme.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/helpers/meeting_helpers.dart';
import '../../../core/widgets/chat_contract_card.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../core/widgets/meeting_chip.dart';
import '../../../core/widgets/payment_banner.dart';
import '../../../core/widgets/payment_detail_sheet.dart';

class ChatTab extends StatefulWidget {
  final int? workspaceId;
  final String? wsStatus;
  const ChatTab({super.key, this.workspaceId, this.wsStatus});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> with WidgetsBindingObserver {
  final _api = ApiClient();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  Timer? _pollTimer;
  Map<String, dynamic>? _workspaceData;
  Map<String, dynamic>? _nextMeeting;
  Map<String, dynamic>? _nextPayment;
  bool _requestApproval = false;
  Map<String, dynamic>? _editingMessage;
  Map<String, dynamic>? _replyTo;
  int? get _wsId => widget.workspaceId ?? _api.workspaceId;

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
      final reverb = ReverbService();
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
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _load();
      _loadWorkspace();
    });
  }

  Future<void> _loadWorkspace() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      final data = await _api.get('/workspaces/$wsId');
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
      final data = await _api.get('/workspaces/$wsId/chat');
      _messages = data['messages'] as List<dynamic>? ?? [];
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
      await _api.post('/workspaces/$wsId/chat/mark-read', {});
    } catch (_) {}
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _wsId == null) return;
    _controller.clear();
    final needsApproval = _requestApproval;
    if (_requestApproval) setState(() => _requestApproval = false);
    final replyId = _replyTo?['id'];
    setState(() => _replyTo = null);
    try {
      final body = <String, dynamic>{'message': text};
      if (needsApproval) body['requires_action'] = true;
      if (replyId != null) body['reply_to_id'] = replyId;
      await _api.post('/workspaces/$_wsId/chat', body);
      _load();
      _markRead();
    } catch (e) {
      debugPrint('[chat_tab] _send error: $e');
    }
  }

  Future<void> _saveEdit() async {
    if (_editingMessage == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await _api.put('/chat/${_editingMessage!['id']}', {'message': text});
      setState(() {
        _editingMessage = null;
        _controller.clear();
      });
      _load();
    } catch (e) {
      debugPrint('[chat_tab] _saveEdit error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التعديل: $e')));
    }
  }

  Future<void> _requireAction(int msgId) async {
    if (_wsId == null) return;
    try {
      await _api.patch('/chat/$msgId/require-action', {});
      _load();
    } catch (e) {
      debugPrint('[chat_tab] _requireAction error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل طلب الموافقة')));
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
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.reply, size: 18),
            title: const Text('رد', style: TextStyle(fontSize: 14)),
            dense: true,
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _replyTo = m);
            },
          ),
          if (canEdit)
            ListTile(
              leading: const Icon(Icons.edit, size: 18),
              title: const Text('تعديل'),
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
              title: const Text('طلب موافقة العميل'),
              subtitle: const Text('سيُطلب من العميل الموافقة على هذه الرسالة'),
              onTap: () {
                Navigator.pop(ctx);
                _requireAction(m['id']);
              },
            )
          else if (alreadyRequested)
            const ListTile(
              leading: Icon(Icons.check_circle, color: ShadColors.success),
              title: Text('تم طلب الموافقة مسبقاً'),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: ShadColors.textSecondary),
            title: const Text('تفاصيل الرسالة'),
            subtitle: Text('${m['message'] ?? '(بدون نص)'}'),
            onTap: () => Navigator.pop(ctx),
          ),
        ]),
      ),
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
      await _api.multipartPost('/workspaces/$_wsId/chat', {}, file: file, fileField: 'file');
      _load();
    } catch (e) {
      debugPrint('[chat_tab] _sendWithAttachment error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إرسال المرفق')));
    }
  }

  Future<void> _openContracts() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      final data = await _api.get('/workspaces/$wsId/contracts');
      if (!mounted) return;
      final contracts = safeList(data['contracts']);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _ContractsSheet(contracts: contracts),
      );
    } catch (e) {
      debugPrint('[chat_tab] _openContracts error: $e');
    }
  }

  Future<void> _openLatestZoomLink() async {
    final wsId = _wsId;
    if (wsId == null) return;
    try {
      final data = await _api.get('/workspaces/$wsId/meetings');
      final meetings = safeList(data['meetings']);
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد اجتماع نشط')));
        return;
      }
      if (scheduledAt != null) {
        final joinStatus = getMeetingJoinStatus(scheduledAt);
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

  Widget _contractBubble(dynamic m, Map<String, dynamic> contract, bool isClient) {
    return Column(
      crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (m['message'] != null && m['message'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(m['message'], style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
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
        ),
      ],
    );
  }

  Widget _textBubble(dynamic m, bool isClient, bool isPending, [Map<String, dynamic>? replyTo, bool isConsecutive = false]) {
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
          border: isClient ? null : Border.all(color: const Color(0x1CFFFFFF), width: 0.5),
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
            if (isClient && !isConsecutive && senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSubUser ? ShadColors.subUserNameColor : ShadColors.gold,
                  ),
                ),
              ),
            if (replyTo != null)
              Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border(left: BorderSide(color: ShadColors.crimson.withAlpha(100), width: 2)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(replyTo['sender']?['name'] ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: ShadColors.crimson)),
                  Text(replyTo['message'] ?? '', style: TextStyle(fontSize: 10, color: ShadColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            if (m['type'] == 'file' && m['file_url'] != null)
              _buildFileAttachment(m),
            Text(m['message'] ?? '', style: ShadTypography.chatBubble.copyWith(color: ShadColors.textPrimary)),
            if (!isClient && m['created_at'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_formatTime(m['created_at'] as String?),
                      style: const TextStyle(fontSize: 9, color: ShadColors.textMuted)),
                    if (m['edited_at'] != null) ...[
                      const SizedBox(width: 3),
                      Text('(تم التعديل)', style: TextStyle(fontSize: 9, color: ShadColors.textMuted)),
                    ],
                    if (m['id'] != null) ...[
                      const SizedBox(width: 3),
                      Text(m['read_at'] != null ? '✓✓' : '✓',
                        style: const TextStyle(fontSize: 9, color: ShadColors.gold)),
                    ],
                  ],
                ),
              ),
            if (isClient && m['created_at'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(_formatTime(m['created_at'] as String?),
                  style: const TextStyle(fontSize: 9, color: ShadColors.textMuted)),
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
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('موافقة جديدة', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: ShadColors.gold, letterSpacing: 1.2)),
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
                      child: const Text('انتظار موافقة العميل', style: TextStyle(fontSize: 10, color: ShadColors.gold)),
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
                  color: const Color(0x1497C459),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x3397C459), width: 0.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    m['action_result'] == 'approved' ? '✓ تمت الموافقة' : m['action_result'] == 'rejected' ? '✗ تم الرفض' : '✎ طلب تعديل',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: m['action_result'] == 'approved' ? ShadColors.success : m['action_result'] == 'rejected' ? ShadColors.error : ShadColors.warning),
                  ),
                ]),
              ),
            if (m['approval']?['certificate']?['pdf_url'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = _api.resolveFileUrl(m['approval']['certificate']['pdf_url'] as String);
                    final uri = Uri.tryParse(url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 14),
                  label: const Text('تحميل شهادة الموافقة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShadColors.crimson,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileAttachment(Map<String, dynamic> m) {
    final fileName = m['file_name'] as String? ?? AppLocalizations.of(context)!.attachment;
    final fileSize = m['file_size'] as int?;
    String sizeText = '';
    if (fileSize != null) {
      if (fileSize > 1024 * 1024) {
        sizeText = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        sizeText = '${(fileSize / 1024).toStringAsFixed(0)} KB';
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, size: 20, color: ShadColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ShadColors.textPrimary), overflow: TextOverflow.ellipsis, maxLines: 1),
                if (sizeText.isNotEmpty)
                  Text(sizeText, style: const TextStyle(fontSize: 9, color: ShadColors.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final url = _api.resolveFileUrl(m['file_url'] as String);
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Icon(Icons.download, size: 16, color: ShadColors.gold),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) { return ''; }
  }

  bool _isOnline(Map<String, dynamic>? user) {
    if (user == null) return false;
    final lastSeen = user['last_seen_at'] as String?;
    if (lastSeen == null) return false;
    try {
      final dt = DateTime.parse(lastSeen).toLocal();
      return DateTime.now().difference(dt).inMinutes < 5;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pollTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startPolling();
      _load();
      _loadWorkspace();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    final uid = _api.userId;
    if (uid != null) {
      ReverbService().connectForUser(uid);
    } else {
      ReverbService().disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSA = _api.role == 'super_admin';
    final clientName = _workspaceData?['client']?['contact_person'] as String? ?? 'العميل';
    final clientAvatarUrl = _workspaceData?['client']?['avatar_url'] as String?;
    final clientOnline = _isOnline(_workspaceData?['client']);
    final wsActive = widget.wsStatus == 'active';

    if (!wsActive) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 48, color: ShadColors.textDisabled),
              SizedBox(height: 16),
              Text('المحادثة غير متاحة — بانتظار تفعيل مساحة العمل',
                style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
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
                child: clientAvatarUrl == null ? Text(_initials(clientName),
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
            Text(clientOnline ? 'متصل الآن' : 'غير متصل',
              style: TextStyle(fontSize: 10, color: clientOnline ? ShadColors.online : ShadColors.textDisabled)),
          ])),
          _headerIconBtn(Icons.copy_outlined, _openContracts),
          const SizedBox(width: 6),
          _headerIconBtn(Icons.videocam_outlined, _openLatestZoomLink),
        ]),
      ),
      // Upcoming Meeting Banner
      if (_nextMeeting != null) _buildUpcomingMeetingBanner(),
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
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.visibility, size: 14, color: ShadColors.textSecondary),
            SizedBox(width: 8),
            Text('عرض المحادثة فقط', style: TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
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
                    'طلب موافقة العميل',
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
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
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
            if (_editingMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(children: [
                  const Icon(Icons.edit, size: 14, color: ShadColors.gold),
                  const SizedBox(width: 6),
                  const Text('تعديل الرسالة', style: TextStyle(fontSize: 12, color: ShadColors.gold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() { _editingMessage = null; _controller.clear(); }),
                    child: const Icon(Icons.close, size: 16, color: ShadColors.textSecondary),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 9),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
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
                      hintText: _editingMessage != null ? 'عدّل رسالتك...' : AppLocalizations.of(context)!.typeMessage,
                      hintStyle: const TextStyle(fontSize: 12, color: ShadColors.textDim),
                      filled: true,
                      fillColor: ShadColors.chatInputFill,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0x12FFFFFF), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0x12FFFFFF), width: 1),
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

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ShadColors.cardBorder, width: 0.5),
        ),
        child: Icon(icon, size: 14, color: ShadColors.textSecondary),
      ),
    );
  }

  Widget _buildUpcomingMeetingBanner() {
    final m = _nextMeeting!;
    final title = m['title'] as String? ?? 'اجتماع قادم';
    final link = m['link'] as String?;
    String timeLabel = '';
    try {
      final scheduledAt = DateTime.parse(m['scheduled_at']).toLocal();
      final diff = scheduledAt.difference(DateTime.now());
      if (diff.inMinutes < 60) {
        timeLabel = 'بعد ${diff.inMinutes} دقيقة';
      } else if (diff.inHours < 24) {
        timeLabel = 'بعد ${diff.inHours} ساعة';
      } else {
        timeLabel = 'بعد ${diff.inDays} يوم';
      }
    } catch (_) {}
    return GestureDetector(
      onTap: link != null ? () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x1485B7EB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ShadColors.meetingBlueBorder, width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.videocam, size: 18, color: ShadColors.meetingBlue),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.meetingBlue)),
            if (timeLabel.isNotEmpty) Text(timeLabel, style: TextStyle(fontSize: 10, color: ShadColors.meetingBlue.withAlpha(180))),
          ])),
          if (link != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ShadColors.meetingBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('انضم', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
        ]),
      ),
    );
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

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  List<Widget> _buildMessageList() {
    final widgets = <Widget>[];
    String? lastDate;
    String? lastSenderKey;

    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final createdAt = m['created_at'] as String?;
      final dateKey = _dateKey(createdAt);

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
      final type = m['type'] as String?;
      final metadata = m['metadata'] as Map<String, dynamic>?;
      final replyTo = m['reply_to'] as Map<String, dynamic>?;
      final isConsecutive = senderKey == lastSenderKey;

      Widget bubble;
      if (type == 'meeting' && metadata != null) {
        bubble = _buildMeetingBubble(metadata, m);
      } else if (hasContract) {
        bubble = _contractBubble(m, contract, isClient);
      } else {
        bubble = _textBubble(m, isClient, isPending, replyTo, isConsecutive);
      }

      lastSenderKey = senderKey;

      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: isConsecutive ? 2 : 9),
          child: Row(
            mainAxisAlignment: isClient ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isClient) ...[
                if (!isConsecutive)
                  _buildSenderAvatar(m)
                else
                  SizedBox(width: 28),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: () => _showMessageActions(m),
                  child: bubble,
                ),
              ),
              if (isClient && !isConsecutive) ...[
                const SizedBox(width: 6),
                _buildSenderAvatar(m),
              ],
              if (isClient && isConsecutive) const SizedBox(width: 28),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildSenderAvatar(Map<String, dynamic> m) {
    final sender = m['sender'] as Map<String, dynamic>?;
    final name = sender?['name'] as String? ?? '?';
    final avatarUrl = sender?['avatar_url'] as String?;
    final senderType = m['sender_type'] as String?;
    final isSubUser = senderType == 'App\\Models\\SubUser';
    final isClient = senderType == 'App\\Models\\Client';
    final bgColor = isSubUser ? ShadColors.subUserBubble : isClient ? ShadColors.primary : ShadColors.managerBubble;
    final textColor = isSubUser ? ShadColors.subUserNameColor : isClient ? ShadColors.gold : ShadColors.managerNameColor;

    return CircleAvatar(
      radius: 14,
      backgroundColor: bgColor,
      backgroundImage: avatarUrl != null ? NetworkImage(_api.resolveFileUrl(avatarUrl)) : null,
      child: avatarUrl == null
          ? Text(_initials(name), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor))
          : null,
    );
  }

  Widget _buildMeetingBubble(Map<String, dynamic> metadata, Map<String, dynamic> m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MeetingChip(metadata: metadata),
        if (m['created_at'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 2),
            child: Text(_formatTime(m['created_at'] as String?),
              style: const TextStyle(fontSize: 9, color: ShadColors.textDisabled)),
          ),
      ],
    );
  }

  String? _dateKey(String? iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month}-${dt.day}';
    } catch (_) {
      return null;
    }
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
        const Expanded(child: Divider(color: Color(0x1CFFFFFF), thickness: 0.5, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: const TextStyle(fontSize: 9, color: ShadColors.textMuted)),
        ),
        const Expanded(child: Divider(color: Color(0x1CFFFFFF), thickness: 0.5, height: 1)),
      ]),
    );
  }

  String _monthName(int month) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return month >= 1 && month <= 12 ? names[month] : '';
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
            const Text('العقود', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const Divider(),
          Expanded(
            child: contracts.isEmpty
                ? const Center(child: Text('لا توجد عقود', style: TextStyle(color: ShadColors.textSecondary)))
                : ListView.separated(
                    controller: scrollController,
                    itemCount: contracts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = contracts[i];
                      final status = c['status'] as String? ?? '';
                      final statusColor = statusColors[status] ?? ShadColors.textDisabled;
                      final statusLabel = statusLabels[status] ?? status;
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
