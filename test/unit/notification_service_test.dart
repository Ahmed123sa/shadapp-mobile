import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/notification_service.dart';
import '../helpers/mock_http_client.dart';

// plans/notifications-badges-toasts-plan.md ن1 — NotificationService.init()
// registers the device's FCM token once at app startup, before the user is
// necessarily logged in, so that first attempt 401s and is silently
// swallowed. registerCurrentToken() is what AuthProvider calls right after a
// successful login to resend the (by-then cached) token now that there's a
// session for it to attach to.
//
// NotificationService() itself is a real, Firebase-backed singleton with no
// injection point — NotificationService.forTesting() is a separate instance
// with only its ApiClient swapped out, so these tests never touch Firebase or
// the app-wide singleton's state.
void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  group('registerCurrentToken', () {
    test('does nothing when no token is cached and none is passed explicitly', () async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      final service = NotificationService.forTesting(api: api);

      await service.registerCurrentToken();

      verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
    });

    test('posts an explicitly given token to /notifications/register-token', () async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      final service = NotificationService.forTesting(api: api);
      Map<String, dynamic>? sentBody;
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
        sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
        return jsonResponse('{}');
      });

      await service.registerCurrentToken(token: 'explicit-token');

      expect(sentBody?['token'], 'explicit-token');
      expect(sentBody?['device_type'], isNotNull);
      verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/notifications/register-token'))),
          headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    });

    test('falls back to the cached token (set via fcmTokenForTesting) when none is passed', () async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      final service = NotificationService.forTesting(api: api)..fcmTokenForTesting = 'cached-token';
      Map<String, dynamic>? sentBody;
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
        sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
        return jsonResponse('{}');
      });

      await service.registerCurrentToken();

      expect(sentBody?['token'], 'cached-token');
    });

    test('a failed request is swallowed silently, matching the rest of push registration', () async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      final service = NotificationService.forTesting(api: api);
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenThrow(Exception('network down'));

      await expectLater(service.registerCurrentToken(token: 'x'), completes);
    });
  });
}
