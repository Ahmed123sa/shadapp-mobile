/// Data shape for a meeting, as returned by `/workspaces/:id/meetings` and
/// `/all-meetings`. Covers the read-only display fields used by
/// meetings_page.dart today. The create/update/cancel/complete flows in
/// am/workspace/meetings_tab.dart work with raw request payloads (not this
/// model) and are left for that screen's own future migration.
class Meeting {
  final int id;
  final String title;
  final String status;
  final String? scheduledAt;
  final int? durationMinutes;
  final String? link;
  final String? passcode;

  const Meeting({
    required this.id,
    this.title = '',
    this.status = 'scheduled',
    this.scheduledAt,
    this.durationMinutes,
    this.link,
    this.passcode,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
        id: _int(json['id']) ?? 0,
        title: _str(json['title']) ?? '',
        status: _str(json['status']) ?? 'scheduled',
        scheduledAt: _str(json['scheduled_at']),
        durationMinutes: _int(json['duration_minutes']),
        link: _str(json['link']),
        passcode: _str(json['passcode']),
      );
}

String? _str(dynamic value) => value is String ? value : null;

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
