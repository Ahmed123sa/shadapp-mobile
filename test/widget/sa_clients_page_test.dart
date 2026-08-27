import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/client_repository.dart';
import 'package:shadapp_client/data/manager_repository.dart';
import 'package:shadapp_client/features/am/dashboard/sa_clients_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/client_provider.dart';
import 'package:shadapp_client/providers/manager_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, ClientProvider clientProvider, ManagerProvider managerProvider) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(body: SaClientsPage(clientProvider: clientProvider, managerProvider: managerProvider)),
        ),
        GoRoute(path: '/am/workspace/:id', builder: (_, __) => const Scaffold(body: Text('WORKSPACE_PAGE'))),
        GoRoute(path: '/am/clients/:id', builder: (_, __) => const Scaffold(body: Text('EDIT_PAGE'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the client list and count once loaded', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/account-managers')), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{"managers":[]}'));
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients')), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse(
            '{"clients":[{"id":1,"company_name":"Acme Co","contact_person":"Sara","phone":"0500000000"}]}'));
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final managerProvider = ManagerProvider(repository: ManagerRepository(api: api));

    await pumpPage(tester, clientProvider, managerProvider);

    expect(find.text('Acme Co'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no clients', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/account-managers')), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{"managers":[]}'));
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients')), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{"clients":[]}'));
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final managerProvider = ManagerProvider(repository: ManagerRepository(api: api));

    await pumpPage(tester, clientProvider, managerProvider);

    expect(find.text('No clients'), findsOneWidget);
  });

  testWidgets('deleting a client: confirming calls DELETE then reloads the list', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/account-managers')), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{"managers":[]}'));
    var getCalls = 0;
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients')), headers: any(named: 'headers')))
        .thenAnswer((_) async {
      getCalls++;
      if (getCalls == 1) {
        return jsonResponse('{"clients":[{"id":7,"company_name":"Acme Co","contact_person":"Sara"}]}');
      }
      return jsonResponse('{"clients":[]}');
    });
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer((_) async => jsonResponse('{}'));
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final managerProvider = ManagerProvider(repository: ManagerRepository(api: api));

    await pumpPage(tester, clientProvider, managerProvider);
    expect(find.text('Acme Co'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Client'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/7'))),
        headers: any(named: 'headers'))).called(1);
    expect(getCalls, 2);
    expect(find.text('No clients'), findsOneWidget);
  });
}
