import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/meeting_chip.dart';

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
