// The next-meeting banner above the chat follows the one join rule: the Join
// pill shows from 15 minutes before the start until the meeting ends, and a tap
// before that never opens the link.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/features/chat/chat_page_widgets.dart';
import '../helpers/pump_app.dart';

String iso(Duration offset) => DateTime.now().toUtc().add(offset).toIso8601String();

Map<String, dynamic> meeting(Duration offset, {int? duration, String? link = 'https://meet.example.com/x'}) => {
      'title': 'Kickoff',
      'scheduled_at': iso(offset),
      'duration_minutes': duration,
      'link': link,
    };

void main() {
  const join = ValueKey('chat-meeting-join');

  testWidgets('shows only the time, no Join, an hour before the start', (tester) async {
    await pumpWithLocalizations(
      tester,
      LxMeetingBanner(meeting: meeting(const Duration(hours: 1, minutes: 5)), canJoin: true),
    );

    expect(find.text('Kickoff'), findsOneWidget);
    expect(find.byKey(join), findsNothing);
  });

  testWidgets('a tap before the window does nothing', (tester) async {
    var taps = 0;
    await pumpWithLocalizations(
      tester,
      LxMeetingBanner(meeting: meeting(const Duration(hours: 1, minutes: 5)), canJoin: true, onTap: () => taps++),
    );

    await tester.tap(find.byKey(const ValueKey('chat-meeting-banner')));
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('shows Join 10 minutes before the start and a tap enters', (tester) async {
    var taps = 0;
    await pumpWithLocalizations(
      tester,
      LxMeetingBanner(meeting: meeting(const Duration(minutes: 10, seconds: 30)), canJoin: true, onTap: () => taps++),
    );

    expect(find.byKey(join), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-meeting-banner')));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('keeps Join while a 60-minute meeting is still running', (tester) async {
    await pumpWithLocalizations(
      tester,
      LxMeetingBanner(meeting: meeting(const Duration(minutes: -40), duration: 60), canJoin: true),
    );

    expect(find.byKey(join), findsOneWidget);
    expect(find.text('Join Now'), findsOneWidget);
  });

  testWidgets('drops Join once the meeting is over', (tester) async {
    await pumpWithLocalizations(
      tester,
      LxMeetingBanner(meeting: meeting(const Duration(minutes: -70), duration: 60), canJoin: true),
    );

    expect(find.byKey(join), findsNothing);
  });

  testWidgets('no Join without permission or without a link', (tester) async {
    await pumpWithLocalizations(
      tester,
      LxMeetingBanner(meeting: meeting(const Duration(minutes: 5)), canJoin: false),
    );
    expect(find.byKey(join), findsNothing);

    await pumpWithLocalizations(
      tester,
      LxMeetingBanner(meeting: meeting(const Duration(minutes: 5), link: null), canJoin: true),
    );
    expect(find.byKey(join), findsNothing);
  });
}
