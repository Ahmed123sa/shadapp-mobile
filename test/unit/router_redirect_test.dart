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
  group('manager assistant', () {
    test('goes to the staff dashboard from a public route', () async {
      final api = buildClient(token: 't', role: 'manager_assistant');
      expect(await resolveAuthRedirect(api, '/login'), '/am/dashboard');
    });

    test('can open the normal staff routes', () async {
      final api = buildClient(token: 't', role: 'manager_assistant');
      expect(await resolveAuthRedirect(api, '/am/dashboard'), null);
      expect(await resolveAuthRedirect(api, '/am/workspace/7'), null);
      expect(await resolveAuthRedirect(api, '/am/settings'), null);
    });

    test('is bounced from reports, audit, managers and client creation', () async {
      final api = buildClient(token: 't', role: 'manager_assistant');
      for (final path in ['/am/reports', '/am/audit-logs', '/am/managers', '/am/clients/create']) {
        expect(await resolveAuthRedirect(api, path), '/am/dashboard', reason: path);
      }
    });

    test('a manager is not bounced from those routes', () async {
      final api = buildClient(token: 't', role: 'account_manager');
      expect(await resolveAuthRedirect(api, '/am/reports'), null);
      expect(await resolveAuthRedirect(api, '/am/clients/create'), null);
    });
  });

  group('company staff member', () {
    test('lands on the staff dashboard from a public route', () async {
      final api = buildClient(token: 't', role: 'staff_member');
      expect(await resolveAuthRedirect(api, '/login'), '/staff/dashboard');
    });

    test('can open their dashboard, a client workspace, notifications and profile', () async {
      final api = buildClient(token: 't', role: 'staff_member');
      for (final path in ['/staff/dashboard', '/am/workspace/7', '/notifications', '/profile']) {
        expect(await resolveAuthRedirect(api, path), null, reason: path);
      }
    });

    test('is bounced from every other staff screen', () async {
      final api = buildClient(token: 't', role: 'staff_member');
      for (final path in [
        '/am/dashboard',
        '/am/reports',
        '/am/audit-logs',
        '/am/managers',
        '/am/clients/create',
        '/am/clients/5',
        '/am/settings',
        '/am/staff',
        '/dashboard',
        '/settings',
        '/signature',
      ]) {
        expect(await resolveAuthRedirect(api, path), '/staff/dashboard', reason: path);
      }
    });

    test('their dashboard is closed to everyone else', () async {
      expect(await resolveAuthRedirect(buildClient(token: 't', role: 'client'), '/staff/dashboard'), '/dashboard');
      expect(await resolveAuthRedirect(buildClient(token: 't', role: 'account_manager'), '/staff/dashboard'), '/am/dashboard');
      expect(await resolveAuthRedirect(buildClient(token: 't', role: 'manager_assistant'), '/staff/dashboard'), '/am/dashboard');
    });

    test('the staff management screen is the super admin\'s alone', () async {
      expect(await resolveAuthRedirect(buildClient(token: 't', role: 'super_admin'), '/am/staff'), null);
      expect(await resolveAuthRedirect(buildClient(token: 't', role: 'account_manager'), '/am/staff'), '/am/dashboard');
      expect(await resolveAuthRedirect(buildClient(token: 't', role: 'manager_assistant'), '/am/staff'), '/am/dashboard');
      expect(await resolveAuthRedirect(buildClient(token: 't', role: 'client'), '/am/staff'), '/dashboard');
    });
  });

  group('homeLocationForRole', () {
    test('maps every role to its home', () {
      expect(homeLocationForRole('client'), '/dashboard');
      expect(homeLocationForRole('sub_user'), '/dashboard');
      expect(homeLocationForRole('staff_member'), '/staff/dashboard');
      expect(homeLocationForRole('super_admin'), '/am/dashboard');
      expect(homeLocationForRole('account_manager'), '/am/dashboard');
      expect(homeLocationForRole('manager_assistant'), '/am/dashboard');
      expect(homeLocationForRole(null), '/am/dashboard');
    });
  });
}
