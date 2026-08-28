// Characterization test for am/dashboard/am_dashboard_page.dart, written
// BEFORE any behavior migration (see docs/state-layer-migration-plan.md,
// Path D). Locks in the screen's CURRENT behavior so later commits that move
// it onto Client/Manager/Contract/Payment/Notification/Dashboard/Meeting
// Providers can prove they changed nothing.
//
// A few pre-existing quirks are preserved deliberately, not "fixed":
//  - `_isSA` used to read the real `ApiClient()` singleton directly, bypassing
//    the injected `_api` entirely — the seam commit changed this to read
//    `_api.role` instead, which is identical in production (widget.api
//    defaults to that same singleton) but makes it controllable from a test.
//  - `_load()`'s non-SA branch calls `GET /clients` twice: once directly,
//    once again inside `_fetchAllContracts`. Both call sites are stubbed
//    identically here rather than "deduplicated".
//  - A workspace-less client's `/all-meetings`/`/account-managers/:id` sheets
//    aren't covered — those are exercised in the manager-clients/meetings
//    tests below instead.
//
// Not covered here: the 60s notification/refresh Timer (disabled via
// enablePolling: false, see reverb_service_test.dart / Step 0), Reverb
// realtime notifications (ReverbService.forTesting() never fires), and the
// `_CreateMeetingSheet` form UI (DropdownButtonFormField/date/time pickers
// are impractical to drive under plain `flutter test`) — its `_save()` call
// is covered at the repository/provider level by meeting_provider_test.dart
// instead (MeetingProvider.createMeeting is already used, unchanged, by
// chat_tab.dart's Zoom domain).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/api_client.dart';
import 'package:shadapp_client/core/reverb_service.dart';
import 'package:shadapp_client/features/am/dashboard/am_dashboard_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  // _openClient() calls ApiClient.setUserData(), which hits
  // SharedPreferences.getInstance() — needs mock init values under plain
  // `flutter test`, same as auth_provider_test.dart/login_page_test.dart.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // See the file-level comment: `_isSA` reads `_api.role`, and `_api`
  // defaults to the real `ApiClient()` singleton whenever a test doesn't
  // inject its own `api`. Every test here does inject one, but resetting the
  // singleton's role afterward keeps this file from leaking state into
  // other test files that share the same process.
  tearDown(() {
    ApiClient().role = null;
  });

  void stubCommon(MockHttpClient httpClient, {
    String clientsJson = '{"clients":[]}',
    String contractsPerWorkspaceJson = '{"contracts":[]}',
    String pendingPaymentsJson = '{"payments":[]}',
    String allContractsJson = '{"contracts":[]}',
    String managersJson = '{"managers":[]}',
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients') return jsonResponse(clientsJson);
      if (path.contains('/workspaces/') && path.endsWith('/contracts')) return jsonResponse(contractsPerWorkspaceJson);
      if (path == '/payments/pending') return jsonResponse(pendingPaymentsJson);
      if (path == '/all-contracts') return jsonResponse(allContractsJson);
      if (path == '/account-managers') return jsonResponse(managersJson);
      if (path == '/notifications') return jsonResponse('{"unread_count":"0"}');
      if (path == '/badge-counts') return jsonResponse('{"approvals":"0","chat":"0"}');
      if (path == '/all-meetings') return jsonResponse('{"meetings":[]}');
      return jsonResponse('{}');
    });
  }

  Future<void> pumpPage(WidgetTester tester, dynamic api) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => AmDashboardPage(api: api, enablePolling: false, reverb: ReverbService.forTesting())),
        GoRoute(path: '/am/workspace/:id', builder: (_, __) => const Scaffold(body: Text('WORKSPACE_PAGE'))),
        GoRoute(path: '/notifications', builder: (_, __) => const Scaffold(body: Text('NOTIFS_PAGE'))),
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

  testWidgets('AM (non-SA) branch loads clients, contracts and pending payments', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    stubCommon(
      httpClient,
      clientsJson: '{"clients":[{"id":1,"company_name":"Acme","contact_person":"Ali","workspace":{"id":5,"status":"active"}}]}',
      contractsPerWorkspaceJson: '{"contracts":[{"id":9,"title":"MSA","status":"company_approved","value":1000,"currency":"SAR"}]}',
      pendingPaymentsJson: '{"payments":[{"id":2,"amount":"500","currency":"SAR","workspace":{"client":{"company_name":"Acme"}}}]}',
    );

    await pumpPage(tester, api);

    expect(find.text('Acme'), findsWidgets); // client card on the AM home tab
    expect(find.text('1'), findsWidgets); // Total Clients stat
  });

  testWidgets('SA branch loads account managers instead of a raw client list', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(
      httpClient,
      managersJson: '{"managers":[{"id":1,"name":"Sara Manager","email":"sara@x.com","managed_clients_count":4}]}',
    );

    await pumpPage(tester, api);

    expect(find.text('Sara Manager'), findsOneWidget);
    expect(find.text('sara@x.com'), findsOneWidget);
  });

  testWidgets('opening a client with an existing workspace navigates without creating one', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    stubCommon(
      httpClient,
      clientsJson: '{"clients":[{"id":1,"company_name":"Acme","contact_person":"Ali","workspace":{"id":5,"status":"active"}}]}',
    );

    await pumpPage(tester, api);
    await tester.tap(find.text('Acme').first);
    await tester.pumpAndSettle();

    expect(find.text('WORKSPACE_PAGE'), findsOneWidget);
    verifyNever(() => httpClient.post(any(that: predicate<Uri>((u) => u.path == '/workspaces')),
        headers: any(named: 'headers'), body: any(named: 'body')));
  });

  testWidgets('opening a client with no workspace creates one first, then navigates', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    stubCommon(
      httpClient,
      clientsJson: '{"clients":[{"id":1,"company_name":"NewCo","contact_person":"Sam"}]}',
    );
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path == '/workspaces')),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"workspace":{"id":42}}'),
    );

    await pumpPage(tester, api);
    await tester.tap(find.text('NewCo').first);
    await tester.pumpAndSettle();

    expect(find.text('WORKSPACE_PAGE'), findsOneWidget);
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path == '/workspaces')),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  testWidgets('show all meetings sheet lists meetings from /all-meetings', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    stubCommon(httpClient);
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/all-meetings')), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse(
              '{"meetings":[{"id":1,"title":"Kickoff","status":"scheduled","scheduled_at":"2026-02-01T10:00:00Z","workspace":{"id":5,"client":{"company_name":"Acme"}}}]}',
            ));

    await pumpPage(tester, api);
    await tester.tap(find.byIcon(Icons.videocam));
    await tester.pumpAndSettle();

    expect(find.text('Kickoff'), findsOneWidget);
  });

  testWidgets('tapping a manager (SA) opens their clients via /account-managers/:id', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(
      httpClient,
      managersJson: '{"managers":[{"id":7,"name":"Sara Manager","email":"sara@x.com","managed_clients_count":1}]}',
    );
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/account-managers/7')), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{"manager":{"id":7,"name":"Sara Manager"},"clients":[{"id":3,"company_name":"Beta Co","contact_person":"Nora"}]}'));

    await pumpPage(tester, api);
    await tester.tap(find.text('Sara Manager'));
    await tester.pumpAndSettle();

    expect(find.text('Beta Co'), findsOneWidget);
  });
}
