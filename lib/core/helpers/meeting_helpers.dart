import 'package:shadapp_client/generated/app_localizations.dart';

class MeetingJoinStatus {
  final bool canJoin;
  final String label;
  const MeetingJoinStatus(this.canJoin, this.label);
}

/// Length used when a meeting does not say how long it runs.
const int kMeetingDefaultMinutes = 30;

/// One join rule everywhere: from 15 minutes before the start until the meeting
/// ends (start + duration, [kMeetingDefaultMinutes] when unknown).
MeetingJoinStatus getMeetingJoinStatus(String scheduledAt, AppLocalizations l10n, {int? durationMinutes}) {
  final now = DateTime.now();
  final start = DateTime.parse(scheduledAt).toLocal();
  final diffMin = start.difference(now).inMinutes;
  final length = (durationMinutes != null && durationMinutes > 0) ? durationMinutes : kMeetingDefaultMinutes;

  if (diffMin <= 0) {
    if (diffMin >= -length) return MeetingJoinStatus(true, l10n.meetings_joinNow);
    return MeetingJoinStatus(false, l10n.meetings_ended);
  }
  if (diffMin <= 15) return MeetingJoinStatus(true, l10n.meetings_minutesLeft(diffMin));
  if (diffMin < 60) return MeetingJoinStatus(false, l10n.meetings_minutesLeft(diffMin));
  final diffHrs = (diffMin / 60).floor();
  if (diffHrs < 24) return MeetingJoinStatus(false, l10n.meetings_hoursLeft(diffHrs));
  return MeetingJoinStatus(false, l10n.meetings_daysLeft((diffHrs / 24).floor()));
}
