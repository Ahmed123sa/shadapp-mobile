import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadapp_client/core/api_client.dart';
import 'package:shadapp_client/providers/auth_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ApiClient api;
  late AuthProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    api = buildTestApiClient(client: httpClient);
    provider = AuthProvider(api: api);
    SharedPreferences.setMockInitialValues({});
  });

  group('login', () {
    test('on success: stores the token/role/name and reports logged in', () async {
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse(
                '{"token":"tok-1","user":{"id":1,"name":"Ahmed","role":"account_manager"}}',
              ));

      final ok = await provider.login('a@a.com', 'secret');

      expect(ok, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.role, 'account_manager');
      expect(provider.userName, 'Ahmed');
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
      expect(await api.getToken(), 'tok-1');
    });

    test('on failure: reports the error and does not mark logged in', () async {
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{"message":"Invalid credentials"}', 401));

      final ok = await provider.login('a@a.com', 'wrong');

      expect(ok, isFalse);
      expect(provider.isLoggedIn, isFalse);
      expect(provider.error, isNotNull);
    });

    test('notifies listeners on start and on completion', () async {
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{"token":"t","user":{"id":1,"name":"A","role":"account_manager"}}'));

      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.login('a@a.com', 'secret');

      expect(notifications, greaterThanOrEqualTo(2)); // once when isLoading flips true, once when it flips back
    });
  });

  group('clientLogin', () {
    test('on success: sets role to client and stores the workspace id', () async {
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{"token":"tok-2","client":{"id":9},"workspace_id":5}'));

      final ok = await provider.clientLogin('c@a.com', 'secret');

      expect(ok, isTrue);
      expect(provider.role, 'client');
      expect(provider.isLoggedIn, isTrue);
      expect(await api.getToken(), 'tok-2');
    });
  });

  group('authenticate', () {
    test('staff success: stores token/role/name and logs in without a fallback call', () async {
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse(
                '{"token":"tok-1","user":{"id":1,"name":"Ahmed","role":"account_manager"}}',
              ));

      await provider.authenticate('a@a.com', 'secret');

      expect(provider.isLoggedIn, isTrue);
      expect(provider.role, 'account_manager');
      expect(provider.userName, 'Ahmed');
      expect(await api.getToken(), 'tok-1');
      verify(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    });

    test('falls back to the client endpoint when the staff endpoint rejects credentials', () async {
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

      await provider.authenticate('c@a.com', 'secret');

      expect(call, 2);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.role, 'client');
      expect(provider.userName, 'Acme');
      expect(await api.getToken(), 'tok-2');
    });

    test('falls back to the client endpoint and resolves a sub_user login', () async {
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
        final uri = inv.positionalArguments[0] as Uri;
        if (uri.path.contains('/auth/login')) {
          return jsonResponse('{"message":"Invalid data"}', 422);
        }
        return jsonResponse(
          '{"token":"tok-3","login_type":"sub_user","sub_user":{"id":2,"name":"Sara"},'
          '"client":{"id":9,"company_name":"Acme"},"workspace_id":5}',
        );
      });

      await provider.authenticate('s@a.com', 'secret');

      expect(provider.isLoggedIn, isTrue);
      expect(provider.role, 'sub_user');
      expect(provider.userName, 'Sara');
      expect(await api.getToken(), 'tok-3');
    });

    test('a rate limit on the staff endpoint is rethrown without trying the client endpoint', () async {
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{"message":"Too Many Attempts."}', 429));

      await expectLater(
        () => provider.authenticate('a@a.com', 'secret'),
        throwsA(isA<RateLimitException>()),
      );

      expect(provider.isLoggedIn, isFalse);
      verify(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    });

    test('rejection on both endpoints rethrows the second exception', () async {
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{"message":"Unauthenticated"}', 401));

      await expectLater(
        () => provider.authenticate('a@a.com', 'wrong'),
        throwsA(isA<AuthException>()),
      );

      expect(provider.isLoggedIn, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('logout', () {
    test('clears local state and the token even if the server call fails', () async {
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{"token":"tok-1","user":{"id":1,"name":"Ahmed","role":"account_manager"}}'));
      await provider.login('a@a.com', 'secret');

      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenThrow(Exception('network down'));

      await provider.logout();

      expect(provider.isLoggedIn, isFalse);
      expect(provider.role, isNull);
      expect(provider.userName, isNull);
      expect(await api.getToken(), isNull);
    });
  });
}
