import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/meeting_chip.dart';
import '../helpers/pump_app.dart';

// The client answers about a meeting's time from its chat card: accept, or
// "not suitable" with an optional note. The company sees the answer as a
// status line on the same card.

String iso(Duration offset) => DateTime.now().toUtc().add(offset).toIso8601String();

Map<String, dynamic> meta({String response = 'pending', String? note, String status = 'scheduled'}) => {
      'meeting_id': 7,
      'title': 'Kickoff',
      'scheduled_at': iso(const Duration(days: 2)),
      'status': status,
      'client_response': response,
      'client_response_note': note,
    };

void main() {
  group('client side', () {
    testWidgets('asks the question with accept and not suitable', (tester) async {
      await pumpWithLocalizations(
        tester,
        SingleChildScrollView(
          child: MeetingChip(metadata: meta(), onRespond: (id, r, n) async {}, canAnswer: true),
        ),
      );

      expect(find.text('Does this time work for you?'), findsOneWidget);
      expect(find.byKey(const ValueKey('meeting-answer-accept')), findsOneWidget);
      expect(find.byKey(const ValueKey('meeting-answer-decline')), findsOneWidget);
    });

    testWidgets('accepting sends accepted with no note', (tester) async {
      final calls = <List<Object?>>[];
      await pumpWithLocalizations(
        tester,
        SingleChildScrollView(
          child: MeetingChip(
            metadata: meta(),
            onRespond: (id, r, n) async => calls.add([id, r, n]),
            canAnswer: true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('meeting-answer-accept')));
      await tester.pumpAndSettle();

      expect(calls, [
        [7, 'accepted', null]
      ]);
    });

    testWidgets('not suitable asks for a note first, then sends it', (tester) async {
      final calls = <List<Object?>>[];
      await pumpWithLocalizations(
        tester,
        SingleChildScrollView(
          child: MeetingChip(
            metadata: meta(),
            onRespond: (id, r, n) async => calls.add([id, r, n]),
            canAnswer: true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('meeting-answer-decline')));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('meeting-answer-note')), 'Sunday after 3pm');
      await tester.tap(find.byKey(const ValueKey('meeting-answer-send')));
      await tester.pumpAndSettle();

      expect(calls, [
        [7, 'declined', 'Sunday after 3pm']
      ]);
    });

    testWidgets('shows the answer already given, with a way to change it', (tester) async {
      await pumpWithLocalizations(
        tester,
        SingleChildScrollView(
          child: MeetingChip(
            metadata: meta(response: 'declined', note: 'Sunday'),
            onRespond: (id, r, n) async {},
            canAnswer: true,
          ),
        ),
      );

      expect(find.textContaining('You said this time is not suitable'), findsOneWidget);
      expect(find.byKey(const ValueKey('meeting-answer-accept')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('meeting-answer-change')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('meeting-answer-accept')), findsOneWidget);
    });

    testWidgets('an old card or a finished meeting shows no buttons', (tester) async {
      await pumpWithLocalizations(
        tester,
        SingleChildScrollView(
          child: MeetingChip(metadata: meta(), onRespond: (id, r, n) async {}, canAnswer: false),
        ),
      );
      expect(find.byKey(const ValueKey('meeting-answer-accept')), findsNothing);
      expect(find.text('Does this time work for you?'), findsNothing);

      await pumpWithLocalizations(
        tester,
        SingleChildScrollView(
          child: MeetingChip(metadata: meta(status: 'cancelled'), onRespond: (id, r, n) async {}, canAnswer: true),
        ),
      );
      expect(find.byKey(const ValueKey('meeting-answer-accept')), findsNothing);
    });
  });

  group('company side', () {
    testWidgets('shows waiting, accepted and asked for another time', (tester) async {
      for (final (response, label) in [
        ('pending', "Waiting for the client's answer"),
        ('accepted', 'Client accepted this time'),
        ('declined', 'Client asked for another time'),
      ]) {
        await pumpWithLocalizations(tester, SingleChildScrollView(child: MeetingChip(metadata: meta(response: response))));
        expect(find.text(label), findsOneWidget, reason: response);
        expect(find.byKey(ValueKey('meeting-response-$response')), findsOneWidget);
      }
    });

    testWidgets('shows the note of a declined answer', (tester) async {
      await pumpWithLocalizations(
        tester,
        SingleChildScrollView(child: MeetingChip(metadata: meta(response: 'declined', note: 'Sunday'))),
      );

      expect(find.text('Note: Sunday'), findsOneWidget);
    });

    testWidgets('a card from before this feature counts as waiting, and a cancelled meeting shows nothing', (tester) async {
      final old = meta()..remove('client_response');
      await pumpWithLocalizations(tester, SingleChildScrollView(child: MeetingChip(metadata: old)));
      expect(find.byKey(const ValueKey('meeting-response-pending')), findsOneWidget);

      await pumpWithLocalizations(
        tester,
        SingleChildScrollView(child: MeetingChip(metadata: meta(response: 'accepted', status: 'cancelled'))),
      );
      expect(find.byKey(const ValueKey('meeting-response-accepted')), findsNothing);
    });
  });
}
