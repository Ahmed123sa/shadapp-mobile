class MeetingJoinStatus {
  final bool canJoin;
  final String label;
  const MeetingJoinStatus(this.canJoin, this.label);
}

MeetingJoinStatus getMeetingJoinStatus(String scheduledAt) {
  final now = DateTime.now();
  final start = DateTime.parse(scheduledAt).toLocal();
  final diffMin = start.difference(now).inMinutes;

  if (diffMin <= 0) {
    if (diffMin >= -15) return const MeetingJoinStatus(true, 'انضم الآن');
    return const MeetingJoinStatus(false, 'انتهى');
  }
  if (diffMin <= 15) return MeetingJoinStatus(true, 'متبقي $diffMin دقيقة');
  if (diffMin < 60) return MeetingJoinStatus(false, 'متبقي $diffMin دقيقة');
  final diffHrs = (diffMin / 60).floor();
  if (diffHrs < 24) return MeetingJoinStatus(false, 'متبقي $diffHrs ساعة');
  return MeetingJoinStatus(false, 'متبقي ${(diffHrs / 24).floor()} يوم');
}
