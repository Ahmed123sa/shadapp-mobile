import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/staff_repository.dart';
import 'package:shadapp_client/features/am/workspace/team_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

class MockStaffRepository extends Mock implements StaffRepository {}

void main() {
  late MockStaffRepository repo;
  late dynamic api;

  setUp(() {
    repo = MockStaffRepository();
    api = buildTestApiClient(client: MockHttpClient());
  });

  Future<void> pumpTab(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: TeamTab(workspaceId: 22, repository: repo, api: api)),
    ));
    await tester.pumpAndSettle();
  }

  List<Map<String, dynamic>> rows() => [
        {'id': 30, 'name': 'Nour Staff', 'email': 'nour@example.com', 'avatar_url': null, 'assigned': true},
        {'id': 31, 'name': 'Omar Staff', 'email': 'omar@example.com', 'avatar_url': null, 'assigned': false},
      ];

  testWidgets('lists every active staff member with assign / remove buttons', (tester) async {
    when(() => repo.forWorkspace(22)).thenAnswer((_) async => rows());

    await pumpTab(tester);

    expect(find.text('Nour Staff'), findsOneWidget);
    expect(find.text('Omar Staff'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('team-toggle-30')), matching: find.text('Remove')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('team-toggle-31')), matching: find.text('Assign')), findsOneWidget);
  });

  testWidgets('assigning calls the repository and flips the button', (tester) async {
    when(() => repo.forWorkspace(22)).thenAnswer((_) async => rows());
    when(() => repo.assign(22, 31)).thenAnswer((_) async {});

    await pumpTab(tester);
    await tester.tap(find.byKey(const ValueKey('team-toggle-31')));
    await tester.pumpAndSettle();

    verify(() => repo.assign(22, 31)).called(1);
    expect(find.descendant(of: find.byKey(const ValueKey('team-toggle-31')), matching: find.text('Remove')), findsOneWidget);
  });

  testWidgets('removing calls unassign and flips the button', (tester) async {
    when(() => repo.forWorkspace(22)).thenAnswer((_) async => rows());
    when(() => repo.unassign(22, 30)).thenAnswer((_) async {});

    await pumpTab(tester);
    await tester.tap(find.byKey(const ValueKey('team-toggle-30')));
    await tester.pumpAndSettle();

    verify(() => repo.unassign(22, 30)).called(1);
    expect(find.descendant(of: find.byKey(const ValueKey('team-toggle-30')), matching: find.text('Assign')), findsOneWidget);
  });

  testWidgets('a refused change keeps the button as it was and shows an error', (tester) async {
    when(() => repo.forWorkspace(22)).thenAnswer((_) async => rows());
    when(() => repo.assign(22, 31)).thenThrow(Exception('boom'));

    await pumpTab(tester);
    await tester.tap(find.byKey(const ValueKey('team-toggle-31')));
    await tester.pumpAndSettle();

    expect(find.text('Could not update the team.'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('team-toggle-31')), matching: find.text('Assign')), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no active staff', (tester) async {
    when(() => repo.forWorkspace(22)).thenAnswer((_) async => []);

    await pumpTab(tester);

    expect(find.textContaining('no active staff members'), findsOneWidget);
  });

  testWidgets('shows a load error', (tester) async {
    when(() => repo.forWorkspace(22)).thenThrow(Exception('403'));

    await pumpTab(tester);

    expect(find.text('Could not load the team.'), findsOneWidget);
  });
}
