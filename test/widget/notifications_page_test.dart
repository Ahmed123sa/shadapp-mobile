import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/notification_repository.dart';
import 'package:shadapp_client/features/notifications/notifications_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/notification_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, NotificationProvider provider, {String role = 'account_manager'}) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = role;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => NotificationsPage(notificationProvider: provider, api: api)),
        GoRoute(path: '/am/workspace/:id', builder: (_, __) => const Scaffold(body: Text('WORKSPACE_PAGE'))),
        GoRoute(path: '/am/clients/:id', builder: (_, __) => const Scaffold(body: Text('CLIENT_PAGE'))),
        GoRoute(path: '/am/dashboard', builder: (_, __) => const Scaffold(body: Text('AM_DASHBOARD'))),
        GoRoute(path: '/dashboard', builder: (context, state) => Scaffold(body: Text(state.uri.toString()))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the notification list once loaded', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"notifications":[{"id":"n1","read_at":null,"created_at":"2026-01-01T00:00:00Z",'
        '"data":{"type":"contract_sent","title":"New contract","message":"hi"}}],"unread_count":1}',
      ),
    );
    final provider = NotificationProvider(repository: NotificationRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    expect(find.text('New contract'), findsOneWidget);
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no notifications', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"notifications":[],"unread_count":0}'),
    );
    final provider = NotificationProvider(repository: NotificationRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    expect(find.text('No notifications'), findsOneWidget);
  });

  testWidgets('the "mark all read" action only appears when there is an unread count', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"notifications":[{"id":"n1","read_at":"2026-01-01T00:00:00Z"}],"unread_count":0}'),
    );
    final provider = NotificationProvider(repository: NotificationRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    expect(find.text('Mark All Read'), findsNothing);
  });

  testWidgets('tapping an unread notification marks it read then navigates using workspace_id', (tester) async {
    final httpClient = MockHttpClient();
    var getCalls = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      getCalls++;
      return jsonResponse(
        '{"notifications":[{"id":"n1","read_at":null,"created_at":"2026-01-01T00:00:00Z",'
        '"data":{"type":"contract_sent","title":"New contract","message":"hi","workspace_id":5}}],"unread_count":1}',
      );
    });
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );
    final provider = NotificationProvider(repository: NotificationRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider, role: 'account_manager');
    await tester.tap(find.text('New contract'));
    await tester.pumpAndSettle();

    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/notifications/n1/read'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(getCalls, 2); // initial load + reload after markRead
    expect(find.text('WORKSPACE_PAGE'), findsOneWidget);
  });

  testWidgets('tapping a payment notification as a client opens the payments tab', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"notifications":[{"id":"n2","read_at":null,"created_at":"2026-01-01T00:00:00Z",'
        '"data":{"type":"payment_created","title":"New payment","message":"hi"}}],"unread_count":1}',
      ),
    );
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );
    final provider = NotificationProvider(repository: NotificationRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider, role: 'client');
    await tester.tap(find.text('New payment'));
    await tester.pumpAndSettle();

    expect(find.text('/dashboard?tab=1'), findsOneWidget);
  });

  testWidgets('swiping a notification away deletes it', (tester) async {
    final httpClient = MockHttpClient();
    var getCalls = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      getCalls++;
      if (getCalls == 1) {
        return jsonResponse(
          '{"notifications":[{"id":"n1","read_at":"2026-01-01T00:00:00Z","data":{"title":"Old one"}}],"unread_count":0}',
        );
      }
      return jsonResponse('{"notifications":[],"unread_count":0}');
    });
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );
    final provider = NotificationProvider(repository: NotificationRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);
    expect(find.text('Old one'), findsOneWidget);

    await tester.drag(find.text('Old one'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/notifications/n1'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('No notifications'), findsOneWidget);
  });
}
