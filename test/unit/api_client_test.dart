import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadapp_client/core/api_client.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient client;
  late MockSecureStorage secureStorage;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() async {
    client = MockHttpClient();
    secureStorage = MockSecureStorage();
    // clearToken() (triggered by a 401 response) deletes the persisted token
    // via secure storage and reads it back on the next getToken() call — a
    // real device does this through a platform channel that plain
    // `flutter test` has no plugin registered for, so it's injected here too.
    when(() => secureStorage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    // clearToken() also touches SharedPreferences directly — this is the
    // officially supported in-memory fake for that static call in tests.
    SharedPreferences.setMockInitialValues({});
  });

  ApiClient buildClient({String? token = 'test-token', String baseUrl = 'https://api.test'}) {
    return ApiClient.forTesting(
      client: client,
      secureStorage: secureStorage,
      token: token,
      baseUrlOverride: baseUrl,
    );
  }

  group('resolveFileUrl', () {
    test('passes absolute http(s) URLs through unchanged', () {
      final api = buildClient();
      expect(api.resolveFileUrl('https://cdn.example.com/x.png'), 'https://cdn.example.com/x.png');
      expect(api.resolveFileUrl('http://cdn.example.com/x.png'), 'http://cdn.example.com/x.png');
    });

    test('rewrites a storage/ relative path to files/ under the API origin', () {
      final api = buildClient(baseUrl: 'https://api.test/api');
      expect(api.resolveFileUrl('storage/signatures/1.png'), 'https://api.test/files/signatures/1.png');
      expect(api.resolveFileUrl('/storage/signatures/1.png'), 'https://api.test/files/signatures/1.png');
    });

    test('falls back to files/<path> for anything else', () {
      final api = buildClient(baseUrl: 'https://api.test/api');
      expect(api.resolveFileUrl('avatars/2.png'), 'https://api.test/files/avatars/2.png');
    });
  });

  group('get()', () {
    test('sends Accept and Authorization headers built from the stored token', () async {
      final api = buildClient(token: 'abc123');
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response('{"ok":true}', 200),
      );

      final result = await api.get('/ping');

      expect(result, {'ok': true});
      final captured = verify(() => client.get(any(), headers: captureAny(named: 'headers'))).captured;
      final headers = captured.single as Map<String, String>;
      expect(headers['Authorization'], 'Bearer abc123');
      expect(headers['Accept'], 'application/json');
    });

    test('omits Authorization when there is no token', () async {
      final api = buildClient(token: null);
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response('{}', 200),
      );

      await api.get('/ping');

      final captured = verify(() => client.get(any(), headers: captureAny(named: 'headers'))).captured;
      final headers = captured.single as Map<String, String>;
      expect(headers.containsKey('Authorization'), isFalse);
    });
  });

  group('status code handling', () {
    test('401 throws AuthException and clears the token', () async {
      final api = buildClient(token: 'abc123');
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response('{"message":"Unauthenticated"}', 401),
      );

      await expectLater(api.get('/me'), throwsA(isA<AuthException>()));
      expect(await api.getToken(), isNull);
    });

    test('422 throws ValidationException with the first field error', () async {
      final api = buildClient();
      when(() => client.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
        // http.Response picks its encoding from the content-type header and
        // falls back to latin1 when none is given, which throws
        // ArgumentError on non-Latin1 text — the Arabic message below needs
        // an explicit utf-8 charset, same as the real API responses send.
        (_) async => http.Response(
          '{"message":"The given data was invalid.","errors":{"email":["البريد الإلكتروني غير صالح"]}}',
          422,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await expectLater(
        api.post('/clients', {}),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'البريد الإلكتروني غير صالح')),
      );
    });

    test('429 throws RateLimitException, distinct from a generic server error', () async {
      final api = buildClient();
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response('{"message":"Too Many Attempts."}', 429),
      );

      await expectLater(api.get('/anything'), throwsA(isA<RateLimitException>()));
    });

    test('other 4xx/5xx throws ServerException', () async {
      final api = buildClient();
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response('{"message":"Boom"}', 500),
      );

      await expectLater(
        api.get('/anything'),
        throwsA(isA<ServerException>().having((e) => e.message, 'message', 'Boom')),
      );
    });

    test('a non-JSON error body does not crash — falls back to a generic message', () async {
      final api = buildClient();
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response('<html>502 Bad Gateway</html>', 502),
      );

      await expectLater(api.get('/anything'), throwsA(isA<ServerException>()));
    });

    test('2xx returns the decoded body', () async {
      final api = buildClient();
      when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response('{"id":1,"name":"Acme"}', 200),
      );

      expect(await api.get('/clients/1'), {'id': 1, 'name': 'Acme'});
    });
  });

  group('network failures', () {
    test('a client exception is wrapped as ConnectionException, not left raw', () async {
      final api = buildClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenThrow(http.ClientException('Failed to connect'));

      await expectLater(api.get('/anything'), throwsA(isA<ConnectionException>()));
    });
  });
}
