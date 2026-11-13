import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/remote_config_service.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/api_client.dart';
import 'package:shadapp_client/core/reverb_service.dart';
import 'package:shadapp_client/features/settings/delete_account_button.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    // The delete-account section is gated by Remote Config; tests run with it on.
    RemoteConfigService.deleteAccountEnabled.value = true;
  });

  // clearToken() on a successful delete goes through SharedPreferences.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpButton(WidgetTester tester, ApiClient api, {String? warning}) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: DeleteAccountButton(
              authProvider: AuthProvider(api: api),
              warning: warning,
              reverb: ReverbService.forTesting(),
            ),
          ),
        ),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('LOGIN_PAGE'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
  }

  Finder confirmButton() => find.widgetWithText(ElevatedButton, 'Delete permanently');

  testWidgets('hidden when the delete_account Remote Config flag is false', (tester) async {
    RemoteConfigService.deleteAccountEnabled.value = false;
    addTearDown(() => RemoteConfigService.deleteAccountEnabled.value = true);
    final api = buildTestApiClient(client: MockHttpClient());
    await pumpButton(tester, api);

    expect(find.byKey(const ValueKey('delete-account')), findsNothing);

    RemoteConfigService.deleteAccountEnabled.value = true;
    await tester.pump();
    expect(find.byKey(const ValueKey('delete-account')), findsOneWidget);
  });

  testWidgets('the confirm button stays disabled until a password is entered', (tester) async {
    final api = buildTestApiClient(client: MockHttpClient());
    await pumpButton(tester, api, warning: 'Team members you added will lose access too.');

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.text('Team members you added will lose access too.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(confirmButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'secret');
    await tester.pump();

    expect(tester.widget<ElevatedButton>(confirmButton()).onPressed, isNotNull);
  });

  testWidgets('cancel closes the dialog without calling the server', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    await pumpButton(tester, api);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsNothing);
    verifyNever(() => httpClient.delete(any(), headers: any(named: 'headers'), body: any(named: 'body')));
  });

  testWidgets('a wrong password keeps the dialog open with an error and the session intact', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.delete(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
        (_) async => jsonResponse('{"message":"The password is incorrect.","errors":{"password":["The password is incorrect."]}}', 422));
    await pumpButton(tester, api);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.pump();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(find.text('Incorrect password'), findsOneWidget);
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.text('LOGIN_PAGE'), findsNothing);
    expect(await api.getToken(), 'test-token');
  });

  testWidgets('a server refusal shows its message inside the dialog', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.delete(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{"message":"The last super admin cannot be deleted."}', 403));
    await pumpButton(tester, api);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.pump();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(find.text('The last super admin cannot be deleted.'), findsOneWidget);
    expect(find.text('LOGIN_PAGE'), findsNothing);
  });

  testWidgets('success deletes with the password, clears the session and lands on /login with a confirmation', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    String? sentBody;
    when(() => httpClient.delete(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = inv.namedArguments[#body] as String?;
      return jsonResponse('', 204);
    });
    await pumpButton(tester, api);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.pump();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(jsonDecode(sentBody!), {'password': 'secret'});
    expect(find.text('LOGIN_PAGE'), findsOneWidget);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(await api.getToken(), isNull);
  });
}
