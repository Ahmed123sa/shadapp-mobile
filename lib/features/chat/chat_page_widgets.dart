// Extracted from chat_page.dart as part of بند ٨ (file splitting).
// The message-list rendering (date separators, contract bubbles, text
// bubbles) plus the two small bottom sheets it opens (contracts list,
// contract clauses). The owning page still owns all state (_messages) and
// every side-effecting action (approve, respond, reply/edit) — passed in as
// params/callbacks. `state` is accepted as a plain `State` (not typed to
// _ChatPageState) because it's only ever forwarded to
// chatCertificateDownloadButton, which itself only needs `state.mounted`/
// `state.context` — same reasoning as that shared helper's own signature.
//
// NOT merged with chat_tab.dart's near-identical bubble-building code — same
// precedent as بند ٥'s chat dedup work: these two screens' bubbles look
// similar but have real per-screen differences that must stay separate.

import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/chat_contract_card.dart';
import 'chat_shared.dart';

List<Widget> buildChatMessageList({
  required BuildContext context,
  required State state,
  required List<dynamic> messages,
  required ApiClient api,
  required void Function(int contractId) onApprove,
  required void Function(int msgId, String action) onRespondToMessage,
  required VoidCallback? onGoToPayments,
  required void Function(Map<String, dynamic> msg) onLongPressMessage,
}) {
  final widgets = <Widget>[];
  String? lastDate;
  String? lastSenderKey;

  for (int i = 0; i < messages.length; i++) {
    final m = messages[i];
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
      bubble = _buildContractBubble(context, m, contract, isClient, onApprove, onGoToPayments);
    } else {
      bubble = _buildTextBubble(context, state, api, m, isClient, isPending, replyTo, isConsecutive, onRespondToMessage);
    }

    lastSenderKey = senderKey;

    widgets.add(
      GestureDetector(
        onLongPress: () => onLongPressMessage(m),
        child: Padding(
          padding: EdgeInsets.only(bottom: isConsecutive ? 2 : 9),
          child: Row(
            mainAxisAlignment: isClient ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isClient) ...[
                if (!isConsecutive)
                  chatSenderAvatar(api, m)
                else
                  SizedBox(width: 28),
                const SizedBox(width: 6),
              ],
              Flexible(child: bubble),
              if (isClient && isSubUserSender && !isConsecutive) ...[
                const SizedBox(width: 6),
                chatSenderAvatar(api, m),
              ],
              if (isClient && !isSubUserSender && !isConsecutive) ...[
                const SizedBox(width: 6),
                chatSenderAvatar(api, m),
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

Widget _buildContractBubble(
  BuildContext context,
  Map<String, dynamic> m,
  Map<String, dynamic> contract,
  bool isClient,
  void Function(int contractId) onApprove,
  VoidCallback? onGoToPayments,
) {
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
            builder: (_) => ClausesSheet(clauses: contract['clauses'] as List<dynamic>? ?? []),
          );
        },
        onApprove: isClient && contract['status'] == 'sent' ? () => onApprove(contract['id']) : null,
        onGoToPayments: isClient && contract['status'] == 'company_approved' ? onGoToPayments : null,
      ),
    ],
  );
}

Widget _buildTextBubble(
  BuildContext context,
  State state,
  ApiClient api,
  Map<String, dynamic> m,
  bool isClient,
  bool isPending,
  Map<String, dynamic>? replyTo,
  bool isConsecutive,
  void Function(int msgId, String action) onRespondToMessage,
) {
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
              api: api,
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
                            onTap: () => onRespondToMessage(m['id'], 'edit_requested'),
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
                            onTap: () => onRespondToMessage(m['id'], 'approved'),
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
              state: state,
              api: api,
              m: m,
              label: AppLocalizations.of(context)!.downloadApprovalCert,
              fileOpenFailedMessage: AppLocalizations.of(context)!.fileOpenFailed,
            ),
        ],
      ),
    ),
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
