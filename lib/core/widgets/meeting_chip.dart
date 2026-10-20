import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:intl/intl.dart';
import '../luxe/lx_icons.dart';
import '../luxe/tokens.dart';
import '../theme.dart';
import '../helpers/meeting_helpers.dart';
import 'luxe/luxe_widgets.dart';

class MeetingChip extends StatelessWidget {
  final Map<String, dynamic> metadata;
  /// Staff entry: when set, tapping calls this instead of opening
  /// metadata['link'] (the participant join_url), so the backend can make
  /// the manager/super admin the host. Clients leave it null.
  final Future<void> Function(int meetingId)? onEnter;
  final bool? isHost;
  const MeetingChip({super.key, required this.metadata, this.onEnter, this.isHost});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = metadata['title'] as String? ?? l10n.meetingChipLabel;
    final link = metadata['link'] as String?;
    final scheduledAt = metadata['scheduled_at'] as String?;
    final duration = metadata['duration_minutes'] as int?;
    final status = metadata['status'] as String? ?? 'scheduled';
    final rescheduled = metadata['rescheduled'] == true;

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

    // Mockup `.mc` meeting card: calendar block + serif title + sub + join.
    DateTime? when;
    if (scheduledAt != null) {
      try {
        final hasTz = scheduledAt.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(scheduledAt);
        when = hasTz ? DateTime.parse(scheduledAt).toLocal() : DateTime.parse(scheduledAt);
      } catch (_) {}
    }
    final locale = Localizations.localeOf(context).toString();
    final dim = status != 'scheduled';

    Widget? action;
    if (scheduledAt != null && link != null && status == 'scheduled') {
      final joinStatus = getMeetingJoinStatus(scheduledAt, l10n);
      final buttonLabel = onEnter != null
          ? ((isHost ?? true) ? l10n.meeting_startAsHost : l10n.meeting_join)
          : joinStatus.label;
      action = joinStatus.canJoin
          ? GestureDetector(
              onTap: () async {
                final meetingId = metadata['meeting_id'] as int?;
                if (onEnter != null && meetingId != null) {
                  await onEnter!(meetingId);
                  return;
                }
                final uri = Uri.tryParse(link);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const LxIcon('video', size: 15, color: Lx.ink),
                  const SizedBox(width: 7),
                  Text(buttonLabel, style: Lx.text(context, size: 12.5)),
                ]),
              ),
            )
          : Row(mainAxisSize: MainAxisSize.min, children: [
              const LuxeStatusDot(status: LxStatus.wait),
              const SizedBox(width: 7),
              Text(joinStatus.label, style: Lx.text(context, size: 12, color: Lx.ink2)),
            ]);
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: Lx.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Lx.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (when != null)
              Container(
                width: 58,
                padding: const EdgeInsetsDirectional.only(end: 12),
                decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: Lx.line))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(DateFormat.MMM(locale).format(when).toUpperCase(), style: Lx.text(context, size: 9.5, color: dim ? Lx.faint : Lx.crimsonInk).copyWith(letterSpacing: 1.9)),
                  Text('${when.day}', style: Lx.display(context, size: 26).copyWith(height: 1.1)),
                ]),
              ),
            if (when != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 23 Sept 2026 — a completed/cancelled meeting used to look
                  // exactly like an upcoming one here (only the Join pill
                  // below checked status). Now it shows its status and its
                  // time line is dimmed. The backend keeps metadata.status
                  // in sync (Meeting::booted()).
                  Text(title, style: Lx.display(context, size: 17, color: dim ? Lx.ink2 : Lx.ink)),
                  if (timeText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(timeText, style: Lx.text(context, size: 12.5, color: dim ? Lx.faint : Lx.muted)),
                  ],
                  if (status != 'scheduled') ...[
                    const SizedBox(height: 6),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      LuxeStatusDot(status: status == 'cancelled' ? LxStatus.bad : LxStatus.off),
                      const SizedBox(width: 7),
                      Text(statusLabels(l10n)[status] ?? status, style: Lx.text(context, size: 12, color: Lx.ink2)),
                    ]),
                  ] else if (rescheduled) ...[
                    // 23 Sept 2026 — the backend posts a fresh card (with
                    // metadata.rescheduled) when a meeting's time changes,
                    // so the client notices; this pill says why it's there.
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
                      child: Text(l10n.meetingChipRescheduled, style: Lx.text(context, size: 10, color: Lx.crimsonInk)),
                    ),
                  ],
                ],
              ),
            ),
          ]),
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(alignment: AlignmentDirectional.centerStart, child: action),
          ],
        ],
      ),
    );
  }
}
