import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/meeting_chip.dart';
import '../helpers/pump_app.dart';

String iso(Duration offset) => DateTime.now().toUtc().add(offset).toIso8601String();

void main() {
  testWidgets('falls back to the default title when none is given', (tester) async {
    await pumpWithLocalizations(tester, const MeetingChip(metadata: {}));
    expect(find.text('Meeting'), findsOneWidget);
  });

  // "Join Now" is the literal label only once the meeting has actually
  // started (getMeetingJoinStatus's diffMin <= 0 branch) — while it's still
  // upcoming but within the 15-minute join window, canJoin is already true
  // but the chip shows the countdown text itself, not "Join Now".
  testWidgets('shows the literal "Join Now" label once the meeting has started', (tester) async {
    await pumpWithLocalizations(
      tester,
      MeetingChip(metadata: {
        'title': 'Kickoff',
        'scheduled_at': iso(const Duration(minutes: -5)),
        'link': 'https://meet.example.com/x',
        'status': 'scheduled',
      }),
    );
    expect(find.text('Join Now'), findsOneWidget);
  });

  testWidgets('shows a countdown label (not "Join Now") for a meeting starting soon but not yet', (tester) async {
    await pumpWithLocalizations(
      tester,
      MeetingChip(metadata: {
        'title': 'Kickoff',
        'scheduled_at': iso(const Duration(minutes: 10, seconds: 30)),
        'link': 'https://meet.example.com/x',
        'status': 'scheduled',
      }),
    );
    expect(find.text('Join Now'), findsNothing);
    expect(find.textContaining('min left'), findsOneWidget);
  });

  testWidgets('shows a countdown label well before the join window too', (tester) async {
    await pumpWithLocalizations(
      tester,
      MeetingChip(metadata: {
        'title': 'Kickoff',
        'scheduled_at': iso(const Duration(hours: 3, minutes: 5)),
        'link': 'https://meet.example.com/x',
        'status': 'scheduled',
      }),
    );
    expect(find.text('Join Now'), findsNothing);
    expect(find.textContaining('h left'), findsOneWidget);
  });

  testWidgets('shows nothing joinable when there is no link', (tester) async {
    await pumpWithLocalizations(
      tester,
      MeetingChip(metadata: {
        'title': 'Kickoff',
        'scheduled_at': iso(const Duration(minutes: -5)),
        'status': 'scheduled',
      }),
    );
    expect(find.text('Join Now'), findsNothing);
  });

  testWidgets('shows nothing joinable for a cancelled meeting', (tester) async {
    await pumpWithLocalizations(
      tester,
      MeetingChip(metadata: {
        'title': 'Kickoff',
        'scheduled_at': iso(const Duration(minutes: -5)),
        'link': 'https://meet.example.com/x',
        'status': 'cancelled',
      }),
    );
    expect(find.text('Join Now'), findsNothing);
  });
}
