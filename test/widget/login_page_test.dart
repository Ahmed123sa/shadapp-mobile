import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadapp_client/core/api_client.dart';
import 'package:shadapp_client/features/auth/login_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

// LoginPage used to hard-code the app-wide ApiClient() singleton — an
// optional `api` constructor param was added specifically so this screen
// could be pumped with a mocked http client instead of hitting the network.
void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    // A successful login calls ApiClient.setRole()/setUserData(), both of
    // which touch SharedPreferences.getInstance() — unmocked, that throws
    // inside _login()'s try block, which is silently swallowed by its own
    // catch-all, so the symptom is "navigation never happens" rather than a
    // visible test error.
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLogin(WidgetTester tester, ApiClient api) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => LoginPage(api: api)),
        GoRoute(path: '/forgot-password', builder: (_, __) => const Scaffold(body: Text('FORGOT_PAGE'))),
        GoRoute(path: '/am/dashboard', builder: (_, __) => const Scaffold(body: Text('AM_DASHBOARD'))),
        GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('CLIENT_DASHBOARD'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    // LoginPage schedules Future.delayed(600ms)/(800ms) animation starts and
    // runs two `..repeat()` AnimationControllers (particles, breathing) that
    // never settle — a bounded pump, never pumpAndSettle, or the test hangs.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows a validation message and does not call the API when a field is empty', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    await pumpLogin(tester, api);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.text('Please enter your email and password'), findsOneWidget);
    verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
  });

  testWidgets('logs a staff account in and navigates to /am/dashboard', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"token":"tok-1","user":{"id":1,"name":"Ahmed","role":"account_manager"}}'),
    );
    await pumpLogin(tester, api);

    await tester.enterText(find.byType(TextField).at(0), 'a@a.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('AM_DASHBOARD'), findsOneWidget);
  });

  testWidgets('falls back to the client login endpoint when the staff endpoint rejects credentials', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    var call = 0;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      call++;
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.contains('/auth/login')) {
        return jsonResponse('{"message":"Unauthenticated"}', 401);
      }
      expect(uri.path, contains('/auth/client/login'));
      return jsonResponse(
        '{"token":"tok-2","login_type":"client","client":{"id":9,"company_name":"Acme"},"workspace_id":5}',
      );
    });
    await pumpLogin(tester, api);

    await tester.enterText(find.byType(TextField).at(0), 'c@a.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('CLIENT_DASHBOARD'), findsOneWidget);
    expect(call, 2);
  });

  testWidgets('shows the rate-limit message distinctly from a credentials error', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{"message":"Too Many Attempts."}', 429));
    await pumpLogin(tester, api);

    await tester.enterText(find.byType(TextField).at(0), 'a@a.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Too many login attempts. Please wait a minute and try again.'), findsOneWidget);
  });

  testWidgets('tapping "Forgot Password?" navigates to the forgot-password screen', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    await pumpLogin(tester, api);

    await tester.tap(find.text('Forgot Password?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('FORGOT_PAGE'), findsOneWidget);
  });
}
