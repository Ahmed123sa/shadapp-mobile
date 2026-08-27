import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/sub_user_repository.dart';
import 'package:shadapp_client/features/subusers/subusers_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/sub_user_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, SubUserProvider provider, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SubUsersPage(subUserProvider: provider, api: api)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the sub-users list and count once loaded', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'client';
    api.userId = 9;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"sub_users":[{"id":1,"name":"Sub One","email":"sub1@x.com","permissions":{}}]}'),
    );
    final provider = SubUserProvider(repository: SubUserRepository(api: api));

    await pumpPage(tester, provider, api);

    expect(find.text('Sub-Users (1)'), findsOneWidget);
    expect(find.text('Sub One'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no sub-users', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'client';
    api.userId = 9;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"sub_users":[]}'),
    );
    final provider = SubUserProvider(repository: SubUserRepository(api: api));

    await pumpPage(tester, provider, api);

    expect(find.text('No sub-users'), findsOneWidget);
  });

  testWidgets('creating a sub-user posts to /clients/:id/sub-users and adds it to the list', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'client';
    api.userId = 9;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"sub_users":[]}'),
    );
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"sub_user":{"id":5,"name":"New Sub","email":"new@x.com","permissions":{}}}');
    });
    final provider = SubUserProvider(repository: SubUserRepository(api: api));

    await pumpPage(tester, provider, api);
    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'New Sub');
    await tester.enterText(find.byType(TextField).at(1), 'new@x.com');
    // The password field is a PasswordField, which renders a TextFormField
    // internally rather than a plain TextField.
    await tester.enterText(find.byType(TextFormField), 'pw123456');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Sub-User'));
    await tester.pumpAndSettle();

    expect(sentBody!['name'], 'New Sub');
    expect(sentBody!['email'], 'new@x.com');
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/sub-users'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.text('New Sub'), findsOneWidget);
  });

  testWidgets('deleting a sub-user calls DELETE and removes it from the list', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'client';
    api.userId = 9;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"sub_users":[{"id":1,"name":"Sub One","email":"sub1@x.com","permissions":{}}]}'),
    );
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );
    final provider = SubUserProvider(repository: SubUserRepository(api: api));

    await pumpPage(tester, provider, api);
    expect(find.text('Sub One'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/sub-users/1'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('No sub-users'), findsOneWidget);
  });

  testWidgets('toggling a permission PATCHes /sub-users/:id/permissions with the updated map', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'client';
    api.userId = 9;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"sub_users":[{"id":1,"name":"Sub One","email":"sub1@x.com","permissions":{"can_chat":false}}]}'),
    );
    Map<String, dynamic>? sentBody;
    when(() => httpClient.patch(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"sub_user":{"id":1,"permissions":{"can_chat":true}}}');
    });
    final provider = SubUserProvider(repository: SubUserRepository(api: api));

    await pumpPage(tester, provider, api);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Chat'));
    await tester.pumpAndSettle();

    expect(sentBody!['permissions']['can_chat'], true);
    verify(() => httpClient.patch(any(that: predicate<Uri>((u) => u.path.endsWith('/sub-users/1/permissions'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
