import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/manager_repository.dart';
import 'package:shadapp_client/features/am/managers/create_manager_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/manager_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<GoRouter> pumpPage(WidgetTester tester, ManagerProvider provider, {int? managerId}) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
        GoRoute(path: '/edit', builder: (_, __) => CreateManagerPage(managerId: managerId, managerProvider: provider)),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    router.push('/edit');
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('create mode: submitting a valid form posts and shows the credentials dialog', (tester) async {
    final httpClient = MockHttpClient();
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"manager":{"id":9,"name":"New Mgr"},"credentials":{"email":"new@x.com","password":"pw123"}}');
    });
    final provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    await tester.enterText(find.byType(TextFormField).at(0), 'New Mgr');
    await tester.enterText(find.byType(TextFormField).at(1), 'new@x.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Manager'));
    // Not pumpAndSettle: the credentials dialog is only dismissed by tapping
    // OK, which this test doesn't do, and the submit button keeps an
    // indeterminate CircularProgressIndicator animating the whole time (the
    // awaited showDialog() call hasn't returned yet) — pumpAndSettle would
    // wait forever for that spinner to stop. A few bounded pumps are enough
    // to flush the mocked POST response and let the dialog's open animation
    // finish.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sentBody!['name'], 'New Mgr');
    expect(sentBody!['email'], 'new@x.com');
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/account-managers'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.text('Manager created successfully'), findsOneWidget);
    expect(find.text('pw123'), findsOneWidget);
  });

  testWidgets('create mode: shows a validation error when name is left empty', (tester) async {
    final httpClient = MockHttpClient();
    final provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    await tester.enterText(find.byType(TextFormField).at(1), 'new@x.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Manager'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
  });

  testWidgets('edit mode: loads the existing manager name into the form', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"manager":{"id":9,"name":"Existing Mgr","email":"existing@x.com","phone":"0500000000"}}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider, managerId: 9);

    final nameField = tester.widget<TextFormField>(find.byType(TextFormField).at(0));
    expect(nameField.controller?.text, 'Existing Mgr');
    final emailField = tester.widget<TextFormField>(find.byType(TextFormField).at(1));
    expect(emailField.controller?.text, 'existing@x.com');
  });

  testWidgets('edit mode: submitting PUTs to /account-managers/:id and shows the update confirmation', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"manager":{"id":9,"name":"Existing Mgr","email":"existing@x.com"}}'),
    );
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"manager":{"id":9,"name":"Updated Mgr"}}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider, managerId: 9);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
    await tester.pumpAndSettle();

    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/account-managers/9'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.text('Manager updated successfully'), findsOneWidget);
  });
}
