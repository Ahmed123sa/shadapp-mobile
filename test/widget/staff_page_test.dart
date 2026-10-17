import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/staff_repository.dart';
import 'package:shadapp_client/features/am/staff/staff_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class MockStaffRepository extends Mock implements StaffRepository {}

void main() {
  late MockStaffRepository repo;

  setUp(() {
    repo = MockStaffRepository();
  });

  Map<String, dynamic> nour() => {
        'id': 30, 'name': 'Nour Staff', 'email': 'nour@example.com', 'phone': null, 'date_of_birth': null,
        'avatar_url': null, 'is_active': true, 'archived_at': null, 'assigned_clients_count': 2,
      };

  Future<void> pumpPage(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
        GoRoute(path: '/am/staff', builder: (_, __) => StaffPage(repository: repo)),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    router.push('/am/staff');
    await tester.pumpAndSettle();
  }

  testWidgets('lists staff with their client counts', (tester) async {
    when(() => repo.fetchAll(includeArchived: false)).thenAnswer((_) async => [nour()]);

    await pumpPage(tester);

    expect(find.text('Nour Staff'), findsOneWidget);
    expect(find.text('nour@example.com'), findsOneWidget);
    expect(find.text('Clients: 2'), findsOneWidget);
  });

  testWidgets('shows the empty state', (tester) async {
    when(() => repo.fetchAll(includeArchived: false)).thenAnswer((_) async => []);

    await pumpPage(tester);

    expect(find.text('No staff members yet.'), findsOneWidget);
  });

  testWidgets('the archived switch reloads with include_archived', (tester) async {
    when(() => repo.fetchAll(includeArchived: false)).thenAnswer((_) async => [nour()]);
    when(() => repo.fetchAll(includeArchived: true)).thenAnswer((_) async => [
          nour(),
          {...nour(), 'id': 31, 'name': 'Old Timer', 'archived_at': '2026-10-01T10:00:00Z'},
        ]);

    await pumpPage(tester);
    expect(find.text('Old Timer'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('staff-show-archived')));
    await tester.pumpAndSettle();

    expect(find.text('Old Timer'), findsOneWidget);
    verify(() => repo.fetchAll(includeArchived: true)).called(1);
  });

  testWidgets('adding a staff member sends the typed fields', (tester) async {
    when(() => repo.fetchAll(includeArchived: false)).thenAnswer((_) async => []);
    when(() => repo.create(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          phone: any(named: 'phone'),
          dateOfBirth: any(named: 'dateOfBirth'),
          sendEmail: any(named: 'sendEmail'),
        )).thenAnswer((_) async {});

    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('staff-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('staff-form-name')), 'Nour Staff');
    await tester.enterText(find.byKey(const ValueKey('staff-form-email')), 'nour@example.com');
    await tester.enterText(find.byKey(const ValueKey('staff-form-password')), 'Secret123');
    await tester.tap(find.byKey(const ValueKey('staff-form-save')));
    await tester.pumpAndSettle();

    verify(() => repo.create(
          name: 'Nour Staff',
          email: 'nour@example.com',
          password: 'Secret123',
          phone: null,
          dateOfBirth: null,
          sendEmail: true,
        )).called(1);
    expect(find.text('Staff member added.'), findsOneWidget);
  });

  testWidgets('archiving asks first, then calls the repository', (tester) async {
    when(() => repo.fetchAll(includeArchived: false)).thenAnswer((_) async => [nour()]);
    when(() => repo.archive(30)).thenAnswer((_) async {});

    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('staff-archive-30')));
    await tester.pumpAndSettle();
    verifyNever(() => repo.archive(30));

    await tester.tap(find.byKey(const ValueKey('staff-confirm')));
    await tester.pumpAndSettle();

    verify(() => repo.archive(30)).called(1);
    expect(find.text('Staff member archived.'), findsOneWidget);
  });

  testWidgets('declining the confirmation archives nobody', (tester) async {
    when(() => repo.fetchAll(includeArchived: false)).thenAnswer((_) async => [nour()]);

    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('staff-archive-30')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.archive(any()));
  });

  testWidgets('shows the clients a member is assigned to', (tester) async {
    when(() => repo.fetchAll(includeArchived: false)).thenAnswer((_) async => [nour()]);
    when(() => repo.clientsOf(30)).thenAnswer((_) async => [
          {'workspace_id': 4, 'client_id': 9, 'name': 'Acme Corp', 'manager': {'id': 2, 'name': 'Mona Manager'}},
        ]);

    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('staff-clients-30')));
    await tester.pumpAndSettle();

    expect(find.text('Acme Corp'), findsOneWidget);
    expect(find.text('Mona Manager'), findsOneWidget);
  });

  testWidgets('shows a load error with a retry', (tester) async {
    when(() => repo.fetchAll(includeArchived: false)).thenThrow(Exception('boom'));

    await pumpPage(tester);

    expect(find.text('Could not load the staff list.'), findsOneWidget);
  });
}
