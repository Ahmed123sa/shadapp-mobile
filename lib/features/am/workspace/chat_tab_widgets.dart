// Extracted from chat_tab.dart as part of بند ٨ (file splitting) — the last
// file in that item. Mirrors chat_page_widgets.dart's extraction of the
// client-facing chat screen, but is NOT merged with it: this AM-facing tab
// has real differences (no approve/reject buttons on the pending-approval
// banner, a different sender-avatar layout with no sub-user branch, l10n
// keys passed explicitly into _dateSeparator/_monthName instead of read from
// context inside them) that must stay separate — same precedent as بند ٥'s
// chat dedup work and chat_page_widgets.dart's own header comment.

import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/theme.dart' show statusLabels;
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/chat_contract_card.dart';
import '../../chat/chat_shared.dart';

List<Widget> buildChatTabMessageList({
  required BuildContext context,
  required State state,
  required List<dynamic> messages,
  required ApiClient api,
  required void Function(dynamic msg) onLongPressMessage,
  required Future<void> Function(int meetingId) onEnterMeeting,
  bool Function(int meetingId)? isHostFor,
}) {
  final l10n = AppLocalizations.of(context)!;
  final widgets = <Widget>[];
  String? lastDate;
  String? lastSenderKey;

  for (int i = 0; i < messages.length; i++) {
    final m = messages[i];
    final createdAt = m['created_at'] as String?;
    final dateKey = chatDateKey(createdAt);

    if (dateKey != null && dateKey != lastDate) {
      widgets.add(_dateSeparator(dateKey, createdAt, l10n));
      lastDate = dateKey;
      lastSenderKey = null;
    }

    final senderType = m['sender_type'] as String?;
    final isClient = senderType == 'App\\Models\\Client' || senderType == 'App\\Models\\SubUser';
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
      final meetingId = metadata['meeting_id'] as int?;
      final isHost = (meetingId != null && isHostFor != null) ? isHostFor(meetingId) : true;
      bubble = chatMeetingBubble(
        metadata,
        m,
        onEnter: onEnterMeeting,
        isHost: isHost,
      );
    } else if (hasContract) {
      bubble = _contractBubble(context, m, contract, isClient);
    } else {
      bubble = _textBubble(context, state, api, m, isClient, isPending, replyTo, isConsecutive);
    }

    lastSenderKey = senderKey;

    // Mockup `.msg`: staff are "mine" (right), the client is on the left.
    final isMine = !isClient;
    final sender = m['sender'] as Map<String, dynamic>?;
    final senderName = sender?['name'] as String? ?? '';
    final timeStr = chatFormatTime(createdAt);
    final fullWidth = type == 'meeting' || hasContract || isPending;
    final screenW = MediaQuery.of(context).size.width;

    widgets.add(
      Padding(
        padding: EdgeInsets.only(bottom: isConsecutive ? 6 : 16),
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              if (!isConsecutive) _lxAvatar(context, api, sender, senderName) else const SizedBox(width: 32),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: GestureDetector(
                key: ValueKey('chat-msg-${m['id']}'),
                onLongPress: () => onLongPressMessage(m),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: screenW * (fullWidth ? 0.96 : 0.88)),
                  child: Column(
                    crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (!isConsecutive)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (senderName.isNotEmpty) Text(senderName, style: Lx.text(context, size: 11, color: Lx.ink2, weight: FontWeight.w500)),
                            if (!isClient && senderName.isNotEmpty) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
                                child: Text(l10n.accountManager, style: Lx.text(context, size: 9.5, color: Lx.muted)),
                              ),
                            ],
                            if (isClient && senderName.isNotEmpty) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
                                child: Text(l10n.chatClient, style: Lx.text(context, size: 9.5, color: Lx.muted)),
                              ),
                            ],
                            if (timeStr.isNotEmpty) ...[
                              const SizedBox(width: 7),
                              Text(timeStr, style: Lx.text(context, size: 11, color: Lx.faint)),
                            ],
                          ]),
                        ),
                      bubble,
                    ],
                  ),
                ),
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: 10),
              if (!isConsecutive) _lxAvatar(context, api, sender, senderName) else const SizedBox(width: 32),
            ],
          ],
        ),
      ),
    );
  }
  return widgets;
}

Widget _dateSeparator(String dateKey, String? iso, AppLocalizations l10n) {
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
        label = l10n.chatToday;
      } else if (diff == 1) {
        label = l10n.chatYesterday;
      } else {
        label = '${dt.day} ${_monthName(dt.month, l10n)} ${dt.year}';
      }
    } catch (_) {
      label = '';
    }
  }
  return Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        const Expanded(child: Divider(color: Lx.line, thickness: 1, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.4)),
        ),
        const Expanded(child: Divider(color: Lx.line, thickness: 1, height: 1)),
      ]),
    ),
  );
}

/// Mockup `.av`: 32px dark circle, serif-italic initial.
Widget _lxAvatar(BuildContext context, ApiClient api, Map<String, dynamic>? sender, String name) {
  final url = sender?['avatar_url'] as String?;
  final initial = chatInitials(name).isEmpty ? '?' : chatInitials(name).substring(0, 1);
  return Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF262626),
      border: Border.all(color: Lx.line2),
      image: url != null ? DecorationImage(image: NetworkImage(api.resolveFileUrl(url)), fit: BoxFit.cover) : null,
    ),
    child: url == null ? Text(initial, style: Lx.display(context, size: 12).copyWith(fontStyle: FontStyle.italic)) : null,
  );
}

String _monthName(int month, AppLocalizations l10n) {
  final names = ['', l10n.monthJanuary, l10n.monthFebruary, l10n.monthMarch, l10n.monthApril, l10n.monthMay, l10n.monthJune, l10n.monthJuly, l10n.monthAugust, l10n.monthSeptember, l10n.monthOctober, l10n.monthNovember, l10n.monthDecember];
  return month >= 1 && month <= 12 ? names[month] : '';
}

Widget _contractBubble(BuildContext context, dynamic m, Map<String, dynamic> contract, bool isClient) {
  return Column(
    crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      if (m['message'] != null && m['message'].toString().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(m['message'], style: Lx.text(context, size: 13, color: Lx.muted)),
        ),
      ChatContractCard(
        contract: contract,
        isClient: isClient,
        onViewClauses: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Lx.sheet,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet))),
            builder: (_) => ClausesSheet(clauses: contract['clauses'] as List<dynamic>? ?? []),
          );
        },
      ),
    ],
  );
}

Widget _textBubble(
  BuildContext context,
  State state,
  ApiClient api,
  dynamic m,
  bool isClient,
  bool isPending, [
  Map<String, dynamic>? replyTo,
  bool isConsecutive = false,
]) {
  final l10n = AppLocalizations.of(context)!;
  final isMine = !isClient; // staff side
  final bubble = Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isMine ? const Color(0x59941414) : Lx.line),
      color: isMine ? null : const Color(0x05FFFFFF),
      gradient: isMine
          ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x38941414), Color(0x1F941414)])
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (replyTo != null)
          Container(
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
              border: const BorderDirectional(start: BorderSide(color: Lx.crimsonInk, width: 2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(replyTo['sender']?['name'] ?? '', style: Lx.text(context, size: 10, color: Lx.crimsonInk, weight: FontWeight.w500)),
              Text(replyTo['message'] ?? '', style: Lx.text(context, size: 11, color: Lx.ink2), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        if (m['type'] == 'file' && m['file_url'] != null)
          chatFileAttachment(
            api: api,
            m: m,
            fallbackFileName: l10n.attachment,
          ),
        Text(m['message'] ?? '', style: Lx.text(context, size: 13.5, height: 1.65)),
        if (m['edited_at'] != null || (isMine && m['id'] != null))
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (m['edited_at'] != null) Text('(${l10n.chatEdited})', style: Lx.text(context, size: 10, color: Lx.faint)),
              if (m['edited_at'] != null && isMine && m['id'] != null) const SizedBox(width: 4),
              if (isMine && m['id'] != null) Text(m['read_at'] != null ? '✓✓' : '✓', style: Lx.text(context, size: 10, color: Lx.ink2)),
            ]),
          ),
      ],
    ),
  );

  if (!isPending && m['action_taken'] != true && m['approval']?['certificate']?['pdf_url'] == null) {
    return bubble;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!isPending) bubble,
      if (isPending)
        // Mockup `.mc.ap`: label + awaiting status, serif title.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x59941414)),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x1A941414), Color(0x08941414)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(l10n.chatNewApproval.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2))),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const LuxeStatusDot(status: LxStatus.wait),
                const SizedBox(width: 6),
                Text(l10n.chatAwaitingClientApproval, style: Lx.text(context, size: 11, color: Lx.ink2)),
              ]),
            ]),
            const SizedBox(height: 6),
            Text(m['message'] ?? '', style: Lx.display(context, size: 18)),
          ]),
        ),
      if (m['action_taken'] == true)
        Padding(
          padding: EdgeInsets.only(top: isPending ? 0 : 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            LuxeStatusDot(status: m['action_result'] == 'approved' ? LxStatus.ok : LxStatus.bad),
            const SizedBox(width: 7),
            Text(
              m['action_result'] == 'approved' ? l10n.chatApprovedStatus : m['action_result'] == 'rejected' ? l10n.chatRejectedStatus : l10n.chatRequestedEditStatus,
              style: Lx.text(context, size: 12, color: m['action_result'] == 'approved' ? Lx.ok : Lx.danger),
            ),
          ]),
        ),
      if (m['approval']?['certificate']?['pdf_url'] != null)
        chatCertificateDownloadButton(
          state: state,
          api: api,
          m: m,
          label: l10n.chatDownloadCertificate,
          fileOpenFailedMessage: l10n.chatFileOpenFailed,
        ),
    ],
  );
}

class ContractsSheet extends StatelessWidget {
  final List<dynamic> contracts;
  const ContractsSheet({super.key, required this.contracts});

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
            Text(AppLocalizations.of(context)!.chatContracts, style: Lx.display(context, size: 18)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const Divider(),
          Expanded(
            child: contracts.isEmpty
                ? Center(child: Text(AppLocalizations.of(context)!.chatNoContracts, style: Lx.text(context, size: 13, color: Lx.muted)))
                : ListView.separated(
                    controller: scrollController,
                    itemCount: contracts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = contracts[i];
                      final status = c['status'] as String? ?? '';
                                            final statusLabel = statusLabels(AppLocalizations.of(context)!)[status] ?? status;
                      return ListTile(
                        leading: const LxIcon('doc', size: 22, color: Lx.ink2),
                        title: Text(c['title'] ?? '', style: Lx.text(context, size: 14)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          LuxeStatusDot(status: (status == 'company_approved' || status == 'completed') ? LxStatus.ok : status == 'sent' ? LxStatus.wait : LxStatus.off),
                          const SizedBox(width: 6),
                          Text(statusLabel, style: Lx.text(context, size: 11, color: Lx.ink2)),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class ClausesSheet extends StatelessWidget {
  final List<dynamic> clauses;
  const ClausesSheet({super.key, required this.clauses});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(AppLocalizations.of(context)!.contractClauses, style: Lx.display(context, size: 18)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 12),
          if (clauses.isEmpty)
            Text(AppLocalizations.of(context)!.noClauses, style: Lx.text(context, size: 13, color: Lx.muted))
          else
            ...clauses.map((cl) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.circle, size: 6, color: Lx.faint),
                const SizedBox(width: 8),
                Expanded(child: Text(cl['content'] ?? '', style: Lx.text(context, size: 13.5, height: 1.6))),
              ]),
            )),
        ],
      ),
    );
  }
}
