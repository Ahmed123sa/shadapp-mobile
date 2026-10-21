import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
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

Widget chatMeetingBubble(
  Map<String, dynamic> metadata,
  Map<String, dynamic> m, {
  Future<void> Function(int meetingId)? onEnter,
  bool? isHost,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MeetingChip(metadata: metadata, onEnter: onEnter, isHost: isHost),
      if (m['created_at'] != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 3, start: 2),
          child: Builder(
            builder: (context) => Text(chatFormatTime(m['created_at'] as String?), style: Lx.text(context, size: 11, color: Lx.faint)),
          ),
        ),
    ],
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

void Function(Map<String, dynamic> payload) chatOnMessageDeleted({
  required State state,
  required void Function(void Function() fn) setState,
  required void Function(int messageId) deleteMessage,
}) {
  return (payload) {
    final messageId = payload['message_id'] as int?;
    if (messageId != null && state.mounted) {
      setState(() => deleteMessage(messageId));
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
  // Mockup `.btn.sm` with the download icon.
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: LuxeButton(
      key: const ValueKey('chat-certificate'),
      label: label,
      lxIcon: 'down',
      size: LuxeButtonSize.sm,
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
    ),
  );
}

// Mockup `.fcard`: 34×42 file box with the extension, name, size, download
// icon. Shared by chat_page and chat_tab; tap opens the file.
Widget chatFileAttachment({
  required ApiClient api,
  required Map<String, dynamic> m,
  required String fallbackFileName,
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
  final dot = fileName.lastIndexOf('.');
  final ext = dot > 0 && dot < fileName.length - 1 ? fileName.substring(dot + 1).toUpperCase() : 'FILE';
  Future<void> open() async {
    final url = api.resolveFileUrl(m['file_url'] as String);
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Mockup `.fcard`: line-2 border r12, padding 10 12, gap 12 — `.fic`
  // (34×42, r6, extension at the bottom, 8.5px .1em muted), `.fn` 12.5 /
  // `.fs` 11 faint, then the download link.
  return Builder(
    builder: (context) => GestureDetector(
      onTap: open,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Lx.line2)),
        child: Row(children: [
          Container(
            width: 34,
            height: 42,
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Lx.line2)),
            child: Text(ext.length > 4 ? ext.substring(0, 4) : ext, style: Lx.text(context, size: 8.5, color: Lx.muted).copyWith(letterSpacing: 0.85)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fileName, style: Lx.text(context, size: 12.5), overflow: TextOverflow.ellipsis, maxLines: 1),
              if (sizeText.isNotEmpty) Text(sizeText, style: Lx.text(context, size: 11, color: Lx.faint)),
            ]),
          ),
          const SizedBox(width: 8),
          const LxIcon('down', size: 16, color: Lx.ink2),
        ]),
      ),
    ),
  );
}
