import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/models/meeting.dart';

void main() {
  group('Meeting.fromJson', () {
    test('parses a full record', () {
      final m = Meeting.fromJson({
        'id': 1,
        'title': 'Kickoff',
        'status': 'scheduled',
        'scheduled_at': '2026-02-01T10:00:00Z',
        'duration_minutes': 30,
        'link': 'https://meet.example.com/x',
        'passcode': '1234',
      });

      expect(m.id, 1);
      expect(m.title, 'Kickoff');
      expect(m.durationMinutes, 30);
    });

    test('missing fields fall back to safe defaults', () {
      final m = Meeting.fromJson({'id': 2});

      expect(m.status, 'scheduled');
      expect(m.title, '');
      expect(m.link, isNull);
    });

    test('a stringified duration is parsed instead of thrown', () {
      final m = Meeting.fromJson({'id': 3, 'duration_minutes': '45'});
      expect(m.durationMinutes, 45);
    });
  });
}
