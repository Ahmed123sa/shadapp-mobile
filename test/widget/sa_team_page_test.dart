import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/manager_repository.dart';
import 'package:shadapp_client/features/am/dashboard/sa_team_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/manager_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, ManagerProvider provider, dynamic api) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => Scaffold(body: SaTeamPage(managerProvider: provider, api: api))),
        GoRoute(path: '/am/managers', builder: (_, __) => const Scaffold(body: Text('MANAGERS_PAGE'))),
        GoRoute(path: '/am/managers/:id/detail', builder: (_, __) => const Scaffold(body: Text('MANAGER_DETAIL'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the manager list and count once loaded', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"managers":[{"id":1,"name":"Sara Ali","email":"sara@x.com","managed_clients_count":3}]}',
      ),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: api));

    await pumpPage(tester, provider, api);

    expect(find.text('Sara Ali'), findsOneWidget);
    expect(find.text('sara@x.com'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no managers', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"managers":[]}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: api));

    await pumpPage(tester, provider, api);

    expect(find.text('No managers'), findsOneWidget);
  });

  testWidgets('search filters the list by name or email', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"managers":[{"id":1,"name":"Sara Ali","email":"sara@x.com"},{"id":2,"name":"Omar Ahmed","email":"omar@x.com"}]}',
      ),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: api));

    await pumpPage(tester, provider, api);
    expect(find.text('Sara Ali'), findsOneWidget);
    expect(find.text('Omar Ahmed'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'omar');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Omar Ahmed'), findsOneWidget);
    expect(find.text('Sara Ali'), findsNothing);
  });

  testWidgets('tapping a manager card navigates to its detail route', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"managers":[{"id":7,"name":"Sara Ali","email":"sara@x.com"}]}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: api));

    await pumpPage(tester, provider, api);
    await tester.tap(find.text('Sara Ali'));
    await tester.pumpAndSettle();

    expect(find.text('MANAGER_DETAIL'), findsOneWidget);
  });
}
