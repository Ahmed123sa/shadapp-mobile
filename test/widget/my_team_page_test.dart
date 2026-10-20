import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/staff_repository.dart';
import 'package:shadapp_client/features/am/staff/my_team_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

class MockStaffRepository extends Mock implements StaffRepository {}

void main() {
  late MockStaffRepository repo;
  late dynamic api;

  setUp(() {
    repo = MockStaffRepository();
    api = buildTestApiClient(client: MockHttpClient());
    api.role = 'account_manager';
  });

  Map<String, dynamic> data() => {
        'team': [
          {
            'id': 30, 'name': 'Nour Staff', 'email': 'nour@example.com', 'avatar_url': null,
            'other_teams': [{'manager_id': 9, 'name': 'Maryam'}],
            'assignments': [
              {'workspace_id': 22, 'client_id': 5, 'name': 'Acme', 'permissions': {'can_send_chat': false}},
            ],
          },
          {'id': 31, 'name': 'Omar Staff', 'email': 'omar@example.com', 'avatar_url': null, 'other_teams': [], 'assignments': []},
        ],
        'others': [
          {'id': 40, 'name': 'Taha Staff', 'email': 'taha@example.com', 'other_teams': [{'manager_id': 8, 'name': 'Mona'}]},
          {'id': 41, 'name': 'Sara Staff', 'email': 'sara@example.com', 'other_teams': []},
        ],
      };

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyTeamPage(repository: repo, api: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows my team with each member\'s clients and permission chips', (tester) async {
    when(() => repo.myTeam()).thenAnswer((_) async => data());
    await pumpPage(tester);

    expect(find.byKey(const ValueKey('mt-member-30')), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.byKey(const ValueKey('chip-on-chat')), findsOneWidget);
    expect(find.text('Chat · view'), findsOneWidget); // send is off
    expect(find.text('Chat · view + send'), findsNothing);
    expect(find.text('In team: Maryam'), findsOneWidget);
    expect(find.byKey(const ValueKey('mt-no-links-31')), findsOneWidget);
    expect(find.byKey(const ValueKey('mt-company-panel')), findsNothing);
  });

  testWidgets('company staff list opens, picks several and adds them', (tester) async {
    when(() => repo.myTeam()).thenAnswer((_) async => data());
    when(() => repo.addToTeam(any())).thenAnswer((_) async {});
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('mt-toggle-company')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mt-company-panel')), findsOneWidget);
    expect(find.text('In team: Mona'), findsOneWidget);
    expect(find.text('Not in any team'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mt-pick-40')));
    await tester.tap(find.byKey(const ValueKey('mt-pick-41')));
    await tester.pumpAndSettle();
    expect(find.text('Add 2 to my team'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mt-add-selected')));
    await tester.pumpAndSettle();

    verify(() => repo.addToTeam(40)).called(1);
    verify(() => repo.addToTeam(41)).called(1);
    expect(find.byKey(const ValueKey('mt-company-panel')), findsNothing);
  });

  testWidgets('removing asks first, showing the count and client names', (tester) async {
    when(() => repo.myTeam()).thenAnswer((_) async => data());
    when(() => repo.removalImpact(30)).thenAnswer((_) async => {'count': 1, 'clients': ['Acme']});
    when(() => repo.removeFromTeam(30)).thenAnswer((_) async {});
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('mt-remove-30')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mt-remove-dialog')), findsOneWidget);
    expect(find.textContaining('1 of your clients: Acme'), findsOneWidget);
    verifyNever(() => repo.removeFromTeam(30));

    await tester.tap(find.byKey(const ValueKey('mt-remove-confirm')));
    await tester.pumpAndSettle();
    verify(() => repo.removeFromTeam(30)).called(1);
  });

  testWidgets('cancelling the remove dialog changes nothing', (tester) async {
    when(() => repo.myTeam()).thenAnswer((_) async => data());
    when(() => repo.removalImpact(30)).thenAnswer((_) async => {'count': 1, 'clients': ['Acme']});
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('mt-remove-30')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mt-remove-cancel')));
    await tester.pumpAndSettle();

    verifyNever(() => repo.removeFromTeam(any()));
    expect(find.byKey(const ValueKey('mt-remove-dialog')), findsNothing);
  });

  testWidgets('linking a client sends the chosen permissions, and "see" off locks its action', (tester) async {
    when(() => repo.myTeam()).thenAnswer((_) async => data());
    when(() => repo.workspaceChoices()).thenAnswer((_) async => [
          {'workspace_id': 22, 'name': 'Acme'},
          {'workspace_id': 23, 'name': 'Beta'},
        ]);
    when(() => repo.assign(any(), any(), permissions: any(named: 'permissions'))).thenAnswer((_) async {});
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('mt-link-31')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mt-client-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta').last);
    await tester.pumpAndSettle();

    // Turn "see approvals" off → "request approvals" becomes off and disabled.
    await tester.tap(find.byKey(const ValueKey('mt-sw-can_view_approvals')));
    await tester.pumpAndSettle();
    final act = tester.widget<SwitchListTile>(find.byKey(const ValueKey('mt-sw-can_request_approvals')));
    expect(act.value, isFalse);
    expect(act.onChanged, isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('mt-save')));
    await tester.tap(find.byKey(const ValueKey('mt-save')));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.assign(23, 31, permissions: captureAny(named: 'permissions'))).captured.single as Map<String, bool>;
    expect(captured['can_view_approvals'], isFalse);
    expect(captured['can_request_approvals'], isFalse);
    expect(captured['can_view_chat'], isTrue);
  });

  testWidgets('unlinking calls unassign for that client', (tester) async {
    when(() => repo.myTeam()).thenAnswer((_) async => data());
    when(() => repo.unassign(22, 30)).thenAnswer((_) async {});
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('mt-unlink-30-22')));
    await tester.pumpAndSettle();

    verify(() => repo.unassign(22, 30)).called(1);
  });

  testWidgets('shows a load error with a retry', (tester) async {
    when(() => repo.myTeam()).thenThrow(Exception('boom'));
    await pumpPage(tester);
    expect(find.text('Could not load the team.'), findsOneWidget);
  });
}
