import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/theme.dart';
import '../../core/widgets/meeting_chip.dart';
import '../../providers/chat_provider.dart';

// Shared, byte-identical helpers used by both chat_page.dart (client-facing
// chat) and am/workspace/chat_tab.dart (account-manager-facing chat).
// Extracted during the chat de-duplication pass — see
// docs/state-layer-migration-plan.md, "المرحلة التالية" > بند ٥.
//
// Only pieces that were verified truly identical between the two screens
// live here. Role-specific logic (approval workflow, SA read-only gating,
// localized date separators, workspace-active source, etc.) stays in each
// screen — see the plan doc for why those were deliberately NOT merged.

String chatInitials(String? name) {
  if (name == null || name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name[0].toUpperCase();
}

bool chatIsOnline(Map<String, dynamic>? user) {
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

String chatFormatTime(String? iso) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  } catch (_) {
    return '';
  }
}

String? chatDateKey(String? iso) {
  if (iso == null) return null;
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.year}-${dt.month}-${dt.day}';
  } catch (_) {
    return null;
  }
}

Widget chatSenderAvatar(ApiClient api, Map<String, dynamic> m) {
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
    backgroundImage: avatarUrl != null ? NetworkImage(api.resolveFileUrl(avatarUrl)) : null,
    child: avatarUrl == null
        ? Text(chatInitials(name), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor))
        : null,
  );
}

Widget chatMeetingBubble(Map<String, dynamic> metadata, Map<String, dynamic> m) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MeetingChip(metadata: metadata),
      if (m['created_at'] != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 3, start: 2),
          child: Text(chatFormatTime(m['created_at'] as String?),
            style: const TextStyle(fontSize: 9, color: ShadColors.textDisabled)),
        ),
    ],
  );
}

Widget chatHeaderIconBtn(IconData icon, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: ShadColors.overlayFaint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShadColors.cardBorder, width: 0.5),
      ),
      child: Icon(icon, size: 14, color: ShadColors.textSecondary),
    ),
  );
}

// Builds the `reverb.onMessageReceived` / `.onMessageUpdated` handlers —
// identical shape in both screens. These closures get stored once in
// `initState` and invoked later, whenever a socket event arrives, so
// `state.mounted` is read live inside the returned closure rather than
// captured up front. `addMessage`/`updateMessage` are themselves plain
// closures the caller defines against its own `_messages` field — since
// they close over `this` (not a copied List value), they always mutate
// the CURRENT `_messages`, even if the field gets reassigned by `_load()`
// between when this handler was built and when it fires.
void Function(Map<String, dynamic> payload) chatOnMessageReceived({
  required State state,
  required void Function(void Function() fn) setState,
  required void Function(Map<String, dynamic> msg) addMessage,
  required VoidCallback scrollToBottom,
}) {
  return (payload) {
    final msg = payload['message'] as Map<String, dynamic>?;
    if (msg != null && state.mounted) {
      setState(() => addMessage(msg));
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    }
  };
}

void Function(Map<String, dynamic> payload) chatOnMessageUpdated({
  required State state,
  required void Function(void Function() fn) setState,
  required void Function(Map<String, dynamic> msg) updateMessage,
}) {
  return (payload) {
    final msg = payload['message'] as Map<String, dynamic>?;
    if (msg != null && state.mounted) {
      setState(() => updateMessage(msg));
    }
  };
}

// _send in both screens has the exact same control-flow shape; the one
// real role difference is that chat_tab.dart can flag a message as
// `requiresAction` via its AM-only "request client approval" toggle,
// chat_page.dart never does. `consumeRequiresAction` is a lazily-invoked
// callback (not a plain bool) specifically so it fires at the same point
// in the sequence as the original code — AFTER the early-return on an
// empty message — otherwise chat_tab's approval toggle would get silently
// reset even when nothing was sent. `wsId`/`replyTo` are read fresh by
// each screen's thin wrapper right before calling in, so passing them as
// plain arguments here is safe — unlike a long-lived reverb closure
// stored in initState, this call happens synchronously each time the user
// taps send, not once and reused later. `load`/`markRead` intentionally
// are NOT awaited, matching the original fire-and-forget behavior in both
// screens.
Future<void> chatSend({
  required TextEditingController controller,
  required int? wsId,
  required Map<String, dynamic>? replyTo,
  required ChatProvider chatProvider,
  required void Function(VoidCallback fn) setState,
  required VoidCallback clearReplyTo,
  required VoidCallback load,
  required VoidCallback markRead,
  required bool Function() consumeRequiresAction,
  required String logTag,
}) async {
  final text = controller.text.trim();
  if (text.isEmpty || wsId == null) return;
  controller.clear();
  final requiresAction = consumeRequiresAction();
  final replyId = replyTo?['id'];
  setState(clearReplyTo);
  try {
    await chatProvider.sendMessage(wsId, text, requiresAction: requiresAction, replyToId: replyId as int?);
    load();
    markRead();
  } catch (e, s) {
    AppLog.error('$logTag._send', e, s);
  }
}

// Same control-flow shape in both screens; only the error snackbar's
// message composition differs (a localized template call vs a
// string-concatenated fallback), and both are resolved by the caller —
// same "caller resolves its own l10n" pattern used elsewhere in this
// file, so no .arb changes were needed. Takes the owning State for the
// same live-mounted-check reason as chatCertificateDownloadButton above.
// `load` intentionally is NOT awaited, matching the original
// fire-and-forget behavior.
Future<void> chatSaveEdit({
  required TextEditingController controller,
  required Map<String, dynamic>? editingMessage,
  required ChatProvider chatProvider,
  required State state,
  required void Function(VoidCallback fn) setState,
  required VoidCallback clearEditingMessage,
  required VoidCallback load,
  required String Function(Object error) editFailedMessage,
  required String logTag,
}) async {
  if (editingMessage == null) return;
  final text = controller.text.trim();
  if (text.isEmpty) return;
  try {
    await chatProvider.editMessage(editingMessage['id'] as int, text);
    setState(() {
      clearEditingMessage();
      controller.clear();
    });
    load();
  } catch (e, s) {
    AppLog.error('$logTag._saveEdit', e, s);
    if (state.mounted) ScaffoldMessenger.of(state.context).showSnackBar(SnackBar(content: Text(editFailedMessage(e))));
  }
}

// Identical logic in both screens (only the l10n key names differed —
// same displayed text). Takes the owning State so it can read `mounted`
// and `context` live at the moment the async gap resolves, rather than a
// snapshot captured when the button was built — a stale-mounted check
// here would be the same class of bug the state-layer migration plan's
// P2-2 attempt ran into with disposed controllers.
Widget chatCertificateDownloadButton({
  required State state,
  required ApiClient api,
  required Map<String, dynamic> m,
  required String label,
  required String fileOpenFailedMessage,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: ElevatedButton.icon(
      onPressed: () async {
        final url = api.resolveFileUrl(m['approval']['certificate']['pdf_url'] as String);
        final uri = Uri.tryParse(url);
        final canLaunch = uri != null && await canLaunchUrl(uri);
        if (canLaunch) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!state.mounted) return;
          ScaffoldMessenger.of(state.context).showSnackBar(SnackBar(content: Text(fileOpenFailedMessage)));
        }
      },
      icon: const Icon(Icons.picture_as_pdf, size: 14),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: ShadColors.crimson,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    ),
  );
}

// Identical in both screens except for the container's background/border
// colors (chat_page used ShadColors.chatBg/chatBorder, chat_tab used
// ShadColors.card/cardBorder — both pre-existing valid tokens, just a
// different choice) and chat_page.dart carried an unused `isClient`
// parameter that never affected the body. Callers pass their own colors
// and the fallback file name string (both screens used the same l10n key
// here, so no .arb changes were needed).
Widget chatFileAttachment({
  required ApiClient api,
  required Map<String, dynamic> m,
  required String fallbackFileName,
  required Color backgroundColor,
  required Color borderColor,
}) {
  final fileName = m['file_name'] as String? ?? fallbackFileName;
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
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: borderColor, width: 0.5),
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
            final url = api.resolveFileUrl(m['file_url'] as String);
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

// chat_page.dart and chat_tab.dart both build this banner identically —
// the only difference was which l10n keys they read (two separate but
// textually-equivalent key sets). Rather than touching the .arb files to
// unify the keys (a bigger, separate risk), each screen resolves its own
// localized strings and passes them in here, so the displayed text is
// byte-for-byte unchanged from before this extraction.
Widget chatUpcomingMeetingBanner({
  required Map<String, dynamic> meeting,
  required String fallbackTitle,
  required String Function(int) inMinutesLabel,
  required String Function(int) inHoursLabel,
  required String Function(int) inDaysLabel,
  required String joinLabel,
}) {
  final title = meeting['title'] as String? ?? fallbackTitle;
  final link = meeting['link'] as String?;
  String timeLabel = '';
  try {
    final scheduledAt = DateTime.parse(meeting['scheduled_at']).toLocal();
    final diff = scheduledAt.difference(DateTime.now());
    if (diff.inMinutes < 60) {
      timeLabel = inMinutesLabel(diff.inMinutes);
    } else if (diff.inHours < 24) {
      timeLabel = inHoursLabel(diff.inHours);
    } else {
      timeLabel = inDaysLabel(diff.inDays);
    }
  } catch (_) {
    // An unparseable/missing date just leaves the relative label off.
    // Runs inside build(), so reporting it would fire on every frame.
  }
  return GestureDetector(
    onTap: link != null ? () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication) : null,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ShadColors.meetingBlueSoft,
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
            child: Text(joinLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
      ]),
    ),
  );
}
