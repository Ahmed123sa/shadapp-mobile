import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shadapp_client/core/api_client.dart';
import 'package:shadapp_client/core/locale_provider.dart';
import 'package:shadapp_client/features/staff/staff_dashboard_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  const clientsJson =
      '{"clients":{"data":[{"id":9,"company_name":"Acme Corp","contact_person":"Ali","client_type":"business","workspace":{"id":22,"status":"active"}}],"current_page":1,"last_page":1}}';

  Future<GoRouter> pumpPage(WidgetTester tester, ApiClient api) async {
    final router = GoRouter(
      initialLocation: '/staff/dashboard',
      routes: [
        GoRoute(path: '/staff/dashboard', builder: (_, __) => StaffDashboardPage(api: api, enablePolling: false)),
        GoRoute(path: '/am/workspace/:id', builder: (_, state) => Scaffold(body: Text('WORKSPACE ${state.pathParameters['id']}'))),
        GoRoute(path: '/notifications', builder: (_, __) => const Scaffold(body: Text('NOTIFICATIONS'))),
        GoRoute(path: '/profile', builder: (_, __) => const Scaffold(body: Text('PROFILE'))),
      ],
    );
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    return router;
  }

  void stub(MockHttpClient httpClient, {String clients = clientsJson, int unread = 3}) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path == '/clients') return jsonResponse(clients);
      if (uri.path == '/notifications') return jsonResponse('{"notifications":[],"unread_count":$unread}');
      return jsonResponse('{}');
    });
  }

  testWidgets('lists the assigned clients and the unread count', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'staff_member';
    stub(httpClient);

    await pumpPage(tester, api);

    expect(find.text('Acme Corp'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping a client opens that client\'s workspace', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'staff_member';
    stub(httpClient);

    await pumpPage(tester, api);
    await tester.tap(find.byKey(const ValueKey('staff-client-9')));
    await tester.pumpAndSettle();

    expect(find.text('WORKSPACE 22'), findsOneWidget);
  });

  testWidgets('shows the empty state when nobody is assigned', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'staff_member';
    stub(httpClient, clients: '{"clients":{"data":[],"current_page":1,"last_page":1}}', unread: 0);

    await pumpPage(tester, api);

    expect(find.text('No clients are assigned to you yet.'), findsOneWidget);
  });

  testWidgets('searching sends the term as q', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'staff_member';
    stub(httpClient);

    await pumpPage(tester, api);
    await tester.enterText(find.byKey(const ValueKey('staff-search')), 'acme');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    verify(() => httpClient.get(
          any(that: predicate<Uri>((u) => u.path == '/clients' && u.queryParameters['q'] == 'acme')),
          headers: any(named: 'headers'),
        )).called(1);
  });

  testWidgets('the bell and the profile button open their screens', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'staff_member';
    stub(httpClient);

    await pumpPage(tester, api);
    await tester.tap(find.byKey(const ValueKey('staff-profile')));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE'), findsOneWidget);
  });

  testWidgets('a failed load shows an error state', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'staff_member';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path == '/clients') return jsonResponse('{"message":"no"}', 500);
      return jsonResponse('{"unread_count":0}');
    });

    await pumpPage(tester, api);

    expect(find.text('Could not load your clients.'), findsOneWidget);
  });
}
