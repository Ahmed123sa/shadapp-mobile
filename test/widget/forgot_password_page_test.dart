import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/api_client.dart';
import 'package:shadapp_client/features/auth/forgot_password_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpForgot(WidgetTester tester, ApiClient api) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => ForgotPasswordPage(api: api)),
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

  testWidgets('rejects an empty email without calling the API', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    await pumpForgot(tester, api);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.text('Please enter your email address.'), findsOneWidget);
    verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
  });

  testWidgets('calls both the staff and client endpoints and shows the sent confirmation if either succeeds', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    final calledPaths = <String>[];
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      calledPaths.add(uri.path);
      if (uri.path.contains('/client/')) {
        return jsonResponse('{"message":"not found"}', 422);
      }
      return jsonResponse('{}');
    });
    await pumpForgot(tester, api);

    await tester.enterText(find.byType(TextField), 'a@a.com');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(calledPaths, containsAll(['/auth/forgot-password', '/auth/client/forgot-password']));
    expect(
      find.text(
        'The reset link has been sent to your email. Open it and set a new password, then come back and sign in.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a generic server error only when both endpoints fail', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{"message":"nope"}', 500));
    await pumpForgot(tester, api);

    await tester.enterText(find.byType(TextField), 'a@a.com');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('A server error occurred. Please try again later.'), findsOneWidget);
  });

  testWidgets('"Back to sign in" navigates to /login', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    await pumpForgot(tester, api);

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_PAGE'), findsOneWidget);
  });
}
