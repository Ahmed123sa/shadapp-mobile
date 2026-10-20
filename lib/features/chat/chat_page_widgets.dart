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
import 'package:url_launcher/url_launcher.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/theme.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
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
      widgets.add(_dateSeparator(context, dateKey, createdAt));
      lastDate = dateKey;
      lastSenderKey = null;
    }

    final senderType = m['sender_type'] as String?;
    final isClient = senderType == 'App\\Models\\Client' || senderType == 'App\\Models\\SubUser';
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
      bubble = _buildContractBubble(context, m, contract, isClient, api, onApprove, onGoToPayments);
    } else {
      bubble = _buildTextBubble(context, state, api, m, isClient, isPending, replyTo, isConsecutive, onRespondToMessage);
    }

    lastSenderKey = senderKey;

    // Mockup `.msg`: 32px avatar + (who line, bubble). Mine are mirrored.
    final sender = m['sender'] as Map<String, dynamic>?;
    final senderName = sender?['name'] as String? ?? '';
    final isMine = isClient;
    final timeStr = chatFormatTime(createdAt);
    final fullWidth = type == 'meeting' || hasContract || isPending;

    widgets.add(
      GestureDetector(
        key: ValueKey('chat-msg-${m['id']}'),
        onLongPress: () => onLongPressMessage(m),
        child: Padding(
          padding: EdgeInsets.only(bottom: isConsecutive ? 6 : 16),
          child: Row(
            // `.msg.mine` is row-reverse in the mockup: flip the logical
            // order only, so Arabic (RTL) mirrors it correctly too.
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine) ...[
                if (!isConsecutive) _lxAvatar(context, api, sender, senderName) else const SizedBox(width: 32),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (fullWidth ? 0.96 : 0.88)),
                  child: Column(
                    crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (!isConsecutive)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (senderName.isNotEmpty)
                              Text(senderName, style: Lx.text(context, size: 11, color: Lx.ink2, weight: FontWeight.w500)),
                            if (!isClient && senderName.isNotEmpty) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
                                child: Text(AppLocalizations.of(context)!.accountManager, style: Lx.text(context, size: 9.5, color: Lx.muted)),
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
              if (isMine) ...[
                const SizedBox(width: 10),
                if (!isConsecutive) _lxAvatar(context, api, sender, senderName) else const SizedBox(width: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
  return widgets;
}

Widget _dateSeparator(BuildContext context, String dateKey, String? iso) {
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
        label = AppLocalizations.of(context)!.today;
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
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      const Expanded(child: Divider(color: Lx.line, thickness: 1, height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.4)),
      ),
      const Expanded(child: Divider(color: Lx.line, thickness: 1, height: 1)),
    ]),
  );
}

/// Mockup `.av`: 32px dark circle, serif-italic initial.
Widget _lxAvatar(BuildContext context, ApiClient api, Map<String, dynamic>? sender, String name) {
  final url = sender?['avatar_url'] as String?;
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
    child: url == null
        ? Text(
            chatInitials(name).isEmpty ? '?' : chatInitials(name).substring(0, 1),
            style: Lx.display(context, size: 12).copyWith(fontStyle: FontStyle.italic),
          )
        : null,
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
  ApiClient api,
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
        // subuser-review-plan.md م٦ — approving a contract from its inline
        // chat card maps to can_approve_contracts, same as the contracts tab.
        // canApprove hides the button entirely (via ChatContractCard) rather
        // than leaving it visible-but-disabled.
        onApprove: isClient && contract['status'] == 'sent' ? () => onApprove(contract['id']) : null,
        onGoToPayments: isClient && contract['status'] == 'company_approved' ? onGoToPayments : null,
        canApprove: api.canDo('can_approve_contracts'),
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
  final l10n = AppLocalizations.of(context)!;
  final extras = <Widget>[
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
        backgroundColor: Lx.surface,
        borderColor: Lx.line2,
      ),
  ];

  final bubble = Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isClient ? const Color(0x59941414) : Lx.line),
      color: isClient ? null : const Color(0x05FFFFFF),
      gradient: isClient
          ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x38941414), Color(0x1F941414)])
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...extras,
        Text(m['message'] ?? '', style: Lx.text(context, size: 13.5, height: 1.65)),
        if (m['edited_at'] != null || (isClient && m['id'] != null))
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (m['edited_at'] != null) Text(l10n.edited, style: Lx.text(context, size: 10, color: Lx.faint)),
              if (m['edited_at'] != null && isClient && m['id'] != null) const SizedBox(width: 4),
              if (isClient && m['id'] != null)
                Text(m['read_at'] != null ? '✓✓' : '✓', style: Lx.text(context, size: 10, color: Lx.ink2)),
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
        // Mockup `.mc.ap`: label + pending status, serif title, actions.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x59941414)),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x1A941414), Color(0x08941414)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(l10n.newApproval.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2))),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const LuxeStatusDot(status: LxStatus.wait),
                const SizedBox(width: 6),
                Text(l10n.needsYourApproval, style: Lx.text(context, size: 11, color: Lx.ink2)),
              ]),
            ]),
            const SizedBox(height: 6),
            Text(m['message'] ?? '', style: Lx.display(context, size: 18)),
            // subuser-review-plan.md م٦ — responding to an approval
            // request maps to can_respond_approvals, per the plan's
            // action table (same key as the approvals tab).
            const SizedBox(height: 14),
            if (api.canDo('can_respond_approvals'))
              Row(children: [
                Expanded(
                  child: LuxeButton(
                    key: ValueKey('chat-approve-${m['id']}'),
                    label: l10n.approve,
                    kind: LuxeButtonKind.primary,
                    size: LuxeButtonSize.sm,
                    onPressed: () => onRespondToMessage(m['id'], 'approved'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LuxeButton(
                    key: ValueKey('chat-request-edit-${m['id']}'),
                    label: l10n.requestEdit,
                    size: LuxeButtonSize.sm,
                    onPressed: () => onRespondToMessage(m['id'], 'edit_requested'),
                  ),
                ),
              ])
            else
              LuxeHint(l10n.subuserActionNeedsOwner),
          ]),
        ),
      if (m['action_taken'] == true)
        Padding(
          padding: EdgeInsets.only(top: isPending ? 0 : 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            LuxeStatusDot(status: m['action_result'] == 'approved' ? LxStatus.ok : LxStatus.bad),
            const SizedBox(width: 7),
            Text(
              m['action_result'] == 'approved' ? l10n.approvedLabel : m['action_result'] == 'rejected' ? l10n.rejectedLabel : l10n.editRequestedLabel,
              style: Lx.text(context, size: 12, color: m['action_result'] == 'approved' ? Lx.ok : Lx.danger),
            ),
          ]),
        ),
      if (m['approval']?['certificate']?['pdf_url'] != null)
        chatCertificateDownloadButton(
          state: state,
          api: api,
          m: m,
          label: l10n.downloadApprovalCert,
          fileOpenFailedMessage: l10n.fileOpenFailed,
        ),
    ],
  );
}

/// Mockup `.ban` for the next meeting.
class LxMeetingBanner extends StatelessWidget {
  final Map<String, dynamic> meeting;
  final bool canJoin;
  /// Staff enter through the backend (so the manager becomes host) instead of
  /// opening the participant link; null falls back to opening the link.
  final VoidCallback? onTap;
  const LxMeetingBanner({super.key, required this.meeting, required this.canJoin, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = meeting['title'] as String? ?? l10n.upcomingMeeting;
    final link = meeting['link'] as String?;
    var timeLabel = '';
    try {
      final diff = DateTime.parse(meeting['scheduled_at']).toLocal().difference(DateTime.now());
      timeLabel = diff.inMinutes < 60
          ? l10n.inMinutes(diff.inMinutes)
          : diff.inHours < 24
              ? l10n.inHours(diff.inHours)
              : l10n.inDays(diff.inDays);
    } catch (_) {}
    return GestureDetector(
      key: const ValueKey('chat-meeting-banner'),
      onTap: onTap ?? (link != null ? () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication) : null),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0x1485B7EB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x5985B7EB)),
        ),
        child: Row(children: [
          const LxIcon('video', size: 16, color: Color(0xFF85B7EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 12, weight: FontWeight.w500)),
              if (timeLabel.isNotEmpty) Text(timeLabel, style: Lx.text(context, size: 11, color: Lx.muted)),
            ]),
          ),
          if (link != null && canJoin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
              child: Text(l10n.join, style: Lx.text(context, size: 11.5)),
            ),
        ]),
      ),
    );
  }
}

/// Mockup `.ban.pay` for the next payment.
class LxPaymentBanner extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback? onTap;
  const LxPaymentBanner({super.key, required this.payment, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final amount = payment['amount']?.toString() ?? '0';
    final currency = payment['currency']?.toString() ?? 'SAR';
    final dueDate = payment['due_date']?.toString();
    final installment = payment['installment_label']?.toString();
    final status = payment['status']?.toString() ?? 'scheduled';
    final direct = dueDate == null || dueDate.isEmpty;

    String title;
    String? sub = installment;
    var c = Lx.wait;
    if (direct) {
      title = l10n.paymentRequestTitle(amount, currency);
    } else if (status == 'overdue') {
      title = l10n.overduePaymentTitle(amount, currency);
      c = Lx.crimsonInk;
      sub = installment ?? _when(dueDate, l10n);
    } else if (status == 'scheduled') {
      title = l10n.scheduledPaymentTitle(amount, currency);
      sub = installment ?? _when(dueDate, l10n);
    } else if (status == 'pending') {
      title = l10n.pendingPaymentTitle(amount, currency);
    } else {
      title = l10n.paidPaymentTitle(amount, currency);
      c = Lx.ok;
    }

    return GestureDetector(
      key: const ValueKey('chat-payment-banner'),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: c.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withAlpha(102)),
        ),
        child: Row(children: [
          LxIcon('wallet', size: 16, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 12, weight: FontWeight.w500)),
              if (sub != null && sub.isNotEmpty) Text(sub, style: Lx.text(context, size: 11, color: Lx.muted)),
            ]),
          ),
        ]),
      ),
    );
  }

  String _when(String dateStr, AppLocalizations l10n) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = dt.difference(DateTime(now.year, now.month, now.day));
      if (diff.inDays == 0) return l10n.today;
      if (diff.inDays == 1) return l10n.tomorrow;
      if (diff.inDays < 0) return l10n.daysLate(-diff.inDays);
      return l10n.inDays(diff.inDays);
    } catch (_) {
      return dateStr;
    }
  }
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
