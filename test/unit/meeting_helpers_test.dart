import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/helpers/meeting_helpers.dart';
import 'package:shadapp_client/generated/app_localizations_en.dart';
import 'package:shadapp_client/generated/app_localizations_ar.dart';

void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  String iso(Duration offset) => DateTime.now().add(offset).toIso8601String();

  group('getMeetingJoinStatus', () {
    // getMeetingJoinStatus() calls DateTime.now() itself, a moment after
    // iso() above already called it once — the gap is normally microseconds,
    // but landing an offset exactly on a whole-minute/hour/day boundary
    // means even that tiny gap truncates down to the unit below (10:00.000
    // becomes 9:59.99x, and inMinutes floors to 9). Every offset below adds
    // a small buffer past the boundary so the assertion isn't racing the
    // clock.
    test('allows joining up to 15 minutes before the scheduled time', () {
      final status = getMeetingJoinStatus(iso(const Duration(minutes: 10, seconds: 30)), en);
      expect(status.canJoin, isTrue);
      expect(status.label, '10 min left');
    });

    test('blocks joining more than 15 minutes out', () {
      final status = getMeetingJoinStatus(iso(const Duration(minutes: 20)), en);
      expect(status.canJoin, isFalse);
    });

    test('allows joining up to 15 minutes after the scheduled time', () {
      final status = getMeetingJoinStatus(iso(const Duration(minutes: -10)), en);
      expect(status.canJoin, isTrue);
      expect(status.label, en.meetings_joinNow);
    });

    test('reports Ended more than 15 minutes after the scheduled time', () {
      final status = getMeetingJoinStatus(iso(const Duration(minutes: -20)), en);
      expect(status.canJoin, isFalse);
      expect(status.label, en.meetings_ended);
    });

    test('reports hours left, then days left, further out', () {
      final inTwoHours = getMeetingJoinStatus(iso(const Duration(hours: 2, minutes: 5)), en);
      expect(inTwoHours.label, en.meetings_hoursLeft(2));

      final inThreeDays = getMeetingJoinStatus(iso(const Duration(days: 3, hours: 1)), en);
      expect(inThreeDays.label, en.meetings_daysLeft(3));
    });

    test('uses the Arabic localizations when passed', () {
      final status = getMeetingJoinStatus(iso(const Duration(minutes: -5)), ar);
      expect(status.label, ar.meetings_joinNow);
    });
  });
}
