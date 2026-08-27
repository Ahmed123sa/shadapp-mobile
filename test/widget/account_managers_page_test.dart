import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/manager_repository.dart';
import 'package:shadapp_client/features/am/managers/account_managers_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/manager_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, ManagerProvider provider) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => AccountManagersPage(managerProvider: provider)),
        GoRoute(path: '/am/managers/create', builder: (_, __) => const Scaffold(body: Text('CREATE_PAGE'))),
        GoRoute(path: '/am/managers/:id/edit', builder: (_, __) => const Scaffold(body: Text('EDIT_PAGE'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the manager list once loaded', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"managers":[{"id":1,"name":"Ahmed","email":"ahmed@shad.com","managed_clients_count":3}]}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    expect(find.text('Ahmed'), findsOneWidget);
    expect(find.text('ahmed@shad.com'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no managers', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"managers":[]}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    expect(find.text('No managers yet'), findsOneWidget);
  });

  testWidgets('shows the error state and retry reloads', (tester) async {
    final httpClient = MockHttpClient();
    var call = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      call++;
      if (call == 1) return jsonResponse('{"message":"Server error"}', 500);
      return jsonResponse('{"managers":[{"id":1,"name":"Ahmed"}]}');
    });
    final provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    expect(find.text('Failed to load managers'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Ahmed'), findsOneWidget);
    expect(call, 2);
  });

  testWidgets('deleting a manager: confirming calls DELETE then reloads the list', (tester) async {
    final httpClient = MockHttpClient();
    var getCalls = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      getCalls++;
      if (getCalls == 1) {
        return jsonResponse('{"managers":[{"id":1,"name":"Ahmed"}]}');
      }
      return jsonResponse('{"managers":[]}');
    });
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);
    expect(find.text('Ahmed'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/account-managers/1'))),
        headers: any(named: 'headers'))).called(1);
    expect(getCalls, 2);
    expect(find.text('No managers yet'), findsOneWidget);
  });

  testWidgets('deleting a manager: cancelling sends no DELETE request', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"managers":[{"id":1,"name":"Ahmed"}]}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => httpClient.delete(any(), headers: any(named: 'headers')));
    expect(find.text('Ahmed'), findsOneWidget);
  });

  testWidgets('tapping the add button navigates to the create page', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"managers":[{"id":1,"name":"Ahmed"}]}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('CREATE_PAGE'), findsOneWidget);
  });
}
