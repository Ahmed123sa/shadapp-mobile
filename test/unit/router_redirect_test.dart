import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadapp_client/core/api_client.dart';
import 'package:shadapp_client/core/router.dart';

// resolveAuthRedirect used to live inline as createRouter's redirect:
// closure, which meant it had zero test coverage despite running on every
// navigation in the app. Pulled out as a plain function of (api, location)
// specifically so these tests don't need a BuildContext/GoRouterState. See
// docs/mobile-review-2026-08-round2.md, #4/#5.

class MockHttpClient extends Mock implements http.Client {}

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient client;
  late MockSecureStorage secureStorage;

  setUp(() {
    client = MockHttpClient();
    secureStorage = MockSecureStorage();
    when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    SharedPreferences.setMockInitialValues({});
  });

  ApiClient buildClient({String? token, String? role}) {
    final api = ApiClient.forTesting(client: client, secureStorage: secureStorage, token: token);
    api.role = role;
    return api;
  }

  group('logged out', () {
    test('a protected location redirects to /login', () async {
      final api = buildClient(token: null);
      expect(await resolveAuthRedirect(api, '/am/settings'), '/login');
      expect(await resolveAuthRedirect(api, '/dashboard'), '/login');
    });

    test('/login and /forgot-password are left alone (no redirect loop)', () async {
      final api = buildClient(token: null);
      expect(await resolveAuthRedirect(api, '/login'), null);
      expect(await resolveAuthRedirect(api, '/forgot-password'), null);
    });
  });

  group('logged in, landing on a public route', () {
    test('client role goes to /dashboard', () async {
      final api = buildClient(token: 't', role: 'client');
      expect(await resolveAuthRedirect(api, '/login'), '/dashboard');
    });

    test('sub_user role goes to /dashboard, same as client', () async {
      final api = buildClient(token: 't', role: 'sub_user');
      expect(await resolveAuthRedirect(api, '/forgot-password'), '/dashboard');
    });

    test('staff role goes to /am/dashboard', () async {
      final api = buildClient(token: 't', role: 'account_manager');
      expect(await resolveAuthRedirect(api, '/login'), '/am/dashboard');
    });
  });

  group('logged in, landing on a protected route', () {
    test('a shared route (not under /am/) is never redirected', () async {
      for (final role in ['client', 'sub_user', 'account_manager']) {
        final api = buildClient(token: 't', role: role);
        expect(await resolveAuthRedirect(api, '/dashboard'), null, reason: 'role=$role');
        expect(await resolveAuthRedirect(api, '/settings'), null, reason: 'role=$role');
        expect(await resolveAuthRedirect(api, '/notifications'), null, reason: 'role=$role');
      }
    });

    test('staff can open /am/* routes', () async {
      final api = buildClient(token: 't', role: 'account_manager');
      expect(await resolveAuthRedirect(api, '/am/dashboard'), null);
      expect(await resolveAuthRedirect(api, '/am/settings'), null);
      expect(await resolveAuthRedirect(api, '/am/audit-logs'), null);
    });

    // Regression coverage for the second half of P0 #1 that the first pass
    // fixed only partially (session-expiry redirect, not role guarding) —
    // see docs/mobile-review-2026-08.md, P0 #1 and round2.md, #4.
    test('client role opening an /am/* deep link is redirected to /dashboard', () async {
      final api = buildClient(token: 't', role: 'client');
      expect(await resolveAuthRedirect(api, '/am/settings'), '/dashboard');
      expect(await resolveAuthRedirect(api, '/am/audit-logs'), '/dashboard');
    });

    test('sub_user role opening an /am/* deep link is redirected to /dashboard', () async {
      final api = buildClient(token: 't', role: 'sub_user');
      expect(await resolveAuthRedirect(api, '/am/workspace/7'), '/dashboard');
    });
  });
}
