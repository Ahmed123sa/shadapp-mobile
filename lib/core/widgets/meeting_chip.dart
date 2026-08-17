import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../theme.dart';
import '../helpers/meeting_helpers.dart';

class MeetingChip extends StatelessWidget {
  final Map<String, dynamic> metadata;
  const MeetingChip({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = metadata['title'] as String? ?? l10n.meetingChipLabel;
    final link = metadata['link'] as String?;
    final scheduledAt = metadata['scheduled_at'] as String?;
    final duration = metadata['duration_minutes'] as int?;
    final status = metadata['status'] as String? ?? 'scheduled';

    String timeText = '';
    if (scheduledAt != null) {
      try {
        final hasTz = scheduledAt.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(scheduledAt);
        final dt = hasTz ? DateTime.parse(scheduledAt).toLocal() : DateTime.parse(scheduledAt);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dtDay = DateTime(dt.year, dt.month, dt.day);
        final diff = dtDay.difference(today);
        String dayLabel;
        if (diff.inDays == 0) {
          dayLabel = 'Today';
        } else if (diff.inDays == 1) {
          dayLabel = 'Tomorrow';
        } else if (diff.inDays < 0) {
          dayLabel = '${-diff.inDays}d ago';
        } else {
          dayLabel = '${dt.day}/${dt.month}/${dt.year}';
        }
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        timeText = '$dayLabel — $hour:$minute';
      } catch (_) {
        timeText = scheduledAt;
      }
    }

    if (duration != null && timeText.isNotEmpty) {
      timeText += ' • ${duration}m';
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShadColors.chatBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.meetingBlueBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ShadColors.meetingBlueBg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: ShadColors.meetingBlueBorder, width: 0.5),
            ),
            child: const Icon(Icons.videocam, size: 16, color: ShadColors.meetingBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
                if (timeText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(timeText, style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (scheduledAt != null && link != null && status == 'scheduled') ...[
            const SizedBox(width: 10),
            Builder(
              builder: (ctx) {
                final joinStatus = getMeetingJoinStatus(scheduledAt, l10n);
                if (joinStatus.canJoin) {
                  return GestureDetector(
                    onTap: () async {
                      final uri = Uri.tryParse(link);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ShadColors.success,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(joinStatus.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  );
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ShadColors.meetingBlueBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ShadColors.meetingBlueBorder, width: 0.5),
                  ),
                  child: Text(joinStatus.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ShadColors.meetingBlue)),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
