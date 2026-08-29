import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/api_client.dart';
import 'package:shadapp_client/core/notification_routing.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fcmTabIndex', () {
    group('client (isClient: true)', () {
      test('defaults to the chat tab for null or "chat"', () {
        expect(fcmTabIndex(null, isClient: true), 2);
        expect(fcmTabIndex('chat', isClient: true), 2);
      });

      test('routes contract*/payment*/approval* to their tabs', () {
        expect(fcmTabIndex('contract_sent', isClient: true), 0);
        expect(fcmTabIndex('payment_due', isClient: true), 1);
        expect(fcmTabIndex('approval_requested', isClient: true), 3);
      });

      test('falls back to tab 0 for an unrecognized type', () {
        expect(fcmTabIndex('something_else', isClient: true), 0);
      });
    });

    group('AM workspace (isClient: false)', () {
      test('defaults to the chat tab for null or "chat"', () {
        expect(fcmTabIndex(null), 0);
        expect(fcmTabIndex('chat'), 0);
      });

      test('routes contract*/payment*/approval*/meeting* to their tabs', () {
        expect(fcmTabIndex('contract_sent'), 2);
        expect(fcmTabIndex('payment_due'), 3);
        expect(fcmTabIndex('approval_requested'), 4);
        expect(fcmTabIndex('meeting_scheduled'), 5);
      });

      test('falls back to tab 0 for an unrecognized type', () {
        expect(fcmTabIndex('something_else'), 0);
      });
    });
  });

  group('notificationTarget', () {
    late MockHttpClient client;

    setUp(() {
      client = MockHttpClient();
    });

    ApiClient buildClient(String role) {
      final api = ApiClient.forTesting(client: client, token: 'test-token');
      api.role = role;
      return api;
    }

    test('client role goes to the client dashboard on the chat tab by default', () async {
      final api = buildClient('client');
      final target = await notificationTarget({'type': 'chat'}, api: api);
      expect(target, '/dashboard?tab=2');
    });

    // This is the regression test for P0 #2: main.dart:144 used to check
    // only `role == 'client'`, so a sub_user tapping a notification landed
    // on the AM workspace instead of their own dashboard. See
    // docs/mobile-review-2026-08.md, P0 #2.
    test('sub_user role goes to the client dashboard, same as client', () async {
      final api = buildClient('sub_user');
      final target = await notificationTarget({'type': 'payment_due'}, api: api);
      expect(target, '/dashboard?tab=1');
    });

    test('staff role with a workspace_id goes to that AM workspace', () async {
      final api = buildClient('account_manager');
      final target = await notificationTarget(
        {'type': 'contract_sent', 'workspace_id': '42'},
        api: api,
      );
      expect(target, '/am/workspace/42?tab=2');
    });

    test('staff role without a workspace_id falls back to the AM dashboard', () async {
      final api = buildClient('account_manager');
      final target = await notificationTarget({'type': 'chat'}, api: api);
      expect(target, '/am/dashboard');
    });

    test('super_admin (any non-client, non-sub_user role) is treated as staff', () async {
      final api = buildClient('super_admin');
      final target = await notificationTarget(
        {'type': 'meeting_scheduled', 'workspace_id': '7'},
        api: api,
      );
      expect(target, '/am/workspace/7?tab=5');
    });
  });
}
