import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/api_client.dart';

/// Shared across provider/api_client tests. Each test file registers its own
/// fallback value for Uri in setUpAll — mocktail fallback registration is
/// global per type, but harmless to repeat across files.
class MockHttpClient extends Mock implements http.Client {}

/// ApiClient.clearToken() (401 responses, explicit logout) goes through
/// secure storage, which has no plugin registered under plain `flutter
/// test`. Stubbed here so any test that exercises that path doesn't have to
/// remember to wire it up itself.
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// Builds an ApiClient wired to a mocked http client and a mocked secure
/// storage (delete/read stubbed to no-op/null), which is what almost every
/// provider test needs — only the token and base URL usually vary.
ApiClient buildTestApiClient({
  required MockHttpClient client,
  String? token = 'test-token',
  String baseUrl = 'https://api.test',
}) {
  final secureStorage = MockSecureStorage();
  // mocktail throws MissingStubError for any invoked-but-unstubbed method
  // (unlike Mockito, which defaults to null) — write() has to be stubbed
  // here too, not just read/delete, or ApiClient.setToken() throws and every
  // successful-login test fails as if the login itself had failed.
  when(() => secureStorage.write(key: any(named: 'key'), value: any(named: 'value'))).thenAnswer((_) async {});
  when(() => secureStorage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
  return ApiClient.forTesting(
    client: client,
    secureStorage: secureStorage,
    token: token,
    baseUrlOverride: baseUrl,
  );
}

/// A ready-to-stub JSON response, since almost every provider test needs one
/// and `http.Response('{"...":...}', 200)` at every call site is noise.
///
/// The explicit charset matters: http.Response picks its encoding from the
/// content-type header and falls back to latin1 when none is given, which
/// throws ArgumentError the moment the body contains non-Latin1 text — and
/// this app's error/validation messages are Arabic.
http.Response jsonResponse(String body, [int statusCode = 200]) => http.Response(
      body,
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
