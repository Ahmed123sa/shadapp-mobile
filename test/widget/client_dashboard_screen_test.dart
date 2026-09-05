// Characterization test for dashboard/client_dashboard_screen.dart, written
// BEFORE any behavior migration (see docs/state-layer-migration-plan.md,
// Path D). Locks in the screen's CURRENT behavior so later commits that move
// its own domains (client load, notifications badge, sub-user permissions)
// onto Client/Notification/Dashboard/SubUserProvider can prove they changed
// nothing.
//
// This screen embeds EIGHT other screens in an IndexedStack (which mounts
// every tab eagerly, not lazily), so all eight had to already be seamed
// (ApiClient?/provider params) before this screen could be pumped at all —
// contracts_page.dart was the one gap (Path B, still deferred for its own
// domain migration) and got the same minimal mechanical seam used for
// admin_settings_page.dart in am_dashboard_page.dart's baseline commit.
//
// FirebaseMessaging.onMessage/.onMessageOpenedApp require a real
// Firebase.initializeApp() call this test never makes, so `enableFcm: false`
// (a new Step-0-style seam) is required on every pump here — without it every
// test in this file would crash in initState.
//
// `enablePolling: false` is required too — the embedded ChatPage tab's
// RealtimePoller checks the real ReverbService() singleton's isConnected
// (not the injected `reverb`), so under a mocked ApiClient it fires its 5s
// safety refresh on every tick forever, which alone was enough to make
// pumpAndSettle time out on every test in this file before this was added.
//
// Not covered here: Reverb realtime (ReverbService.forTesting() never
// fires), FCM foreground/opened-app messages (see enableFcm above), and the
// individual embedded screens' own behavior beyond "it loads without
// crashing" — each of those already has its own characterization/unit test
// suite.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/reverb_service.dart';
import 'package:shadapp_client/features/dashboard/client_dashboard_screen.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  // _loadClientData() calls ApiClient.setUserData() (to persist the newly
  // learned workspace id), which hits SharedPreferences.getInstance() — needs
  // mock init values under plain `flutter test`, same as
  // am_dashboard_page_test.dart.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void stubCommon(MockHttpClient httpClient, {
    String clientJson = '{"client":{"id":10,"signed_at":"2026-01-01T00:00:00Z","workspace":{"id":5,"status":"active","contracts":[],"payments":[]}}}',
    String subUserJson = '{"sub_user":{"id":1,"permissions":{}}}',
    int unreadNotifs = 0,
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients/10') return jsonResponse(clientJson);
      if (path == '/notifications') return jsonResponse('{"unread_count":"$unreadNotifs"}');
      if (path == '/badge-counts') return jsonResponse('{"contracts":"0","payments":"0","approvals":"0","files":"0"}');
      if (path == '/sub-users/1') return jsonResponse(subUserJson);
      if (path == '/workspaces/5/chat') return jsonResponse('{"messages":[]}');
      if (path == '/workspaces/5/contracts') return jsonResponse('{"contracts":[]}');
      if (path == '/workspaces/5/payments') return jsonResponse('{"payments":[],"available_methods":[],"tax_summary":null}');
      if (path == '/workspaces/5/approvals') return jsonResponse('{"approvals":[]}');
      if (path == '/workspaces/5/files') return jsonResponse('{"files":[],"definitions":[],"paymentFiles":[]}');
      if (path == '/workspaces/5/meetings') return jsonResponse('{"meetings":[]}');
      if (path == '/clients/10/sub-users') return jsonResponse('{"sub_users":[]}');
      if (path == '/workspaces/5') return jsonResponse('{"workspace":{"status":"active"},"nextMeeting":null,"nextPayment":null}');
      return jsonResponse('{}');
    });
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/mark-read'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((_) async => jsonResponse('{}'));
  }

  // Avoid pumpAndSettle() on this screen: payments_page.dart's own
  // Timer.periodic(30s) refresh has no test seam at all (Path A, not this
  // slice), and pumpAndSettle's unbounded time-walk eventually crosses that
  // interval, refires it, and never stabilizes within its timeout. Every
  // mocked HTTP response here resolves within a microtask, so a handful of
  // short, bounded pumps is more than enough for all eight embedded screens'
  // initial loads (and a dialog's open/close transition) to settle.
  Future<void> pumpBriefly(WidgetTester tester) async {
    // A few quick pumps let the mocked (near-instant) HTTP responses across
    // all eight embedded screens resolve...
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ...then one longer pump crosses this screen's own 2s
    // `Future.delayed` (initState/_hasInitialTabOverride), so it fires
    // instead of being left as a "pending timer" at test teardown — while
    // staying safely under payments_page.dart's 30s refresh interval.
    await tester.pump(const Duration(seconds: 3));
  }

  // Returns the ReverbService.forTesting() instance the screen was built
  // with, so a test can fire a fake realtime event on it afterward — same
  // approach chat_page_test.dart uses for its own "reverb event reloads
  // data" regression test. Existing call sites that don't need this just
  // discard the return value, so nothing else here changes behavior.
  Future<ReverbService> pumpPage(WidgetTester tester, dynamic api, {int initialTab = 2, ReverbService? reverb}) async {
    final reverbInstance = reverb ?? ReverbService.forTesting();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => ClientDashboardScreen(api: api, initialTab: initialTab, reverb: reverbInstance, enableFcm: false, enablePolling: false)),
        GoRoute(path: '/notifications', builder: (_, __) => const Scaffold(body: Text('NOTIFS_PAGE'))),
        GoRoute(path: '/settings', builder: (_, __) => const Scaffold(body: Text('SETTINGS_PAGE'))),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('LOGIN_PAGE'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await pumpBriefly(tester);
    return reverbInstance;
  }

  testWidgets('loads client + workspace data and renders the dashboard for an active workspace', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.role = 'client';
    stubCommon(httpClient);

    await pumpPage(tester, api);

    // Called twice: once by this screen's own _loadClientData(), once more
    // by the embedded SignatureTab's _loadExisting() (both read the same
    // client id) — a pre-existing quirk, not something introduced here.
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients/10')), headers: any(named: 'headers'))).called(2);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('shows the unread notifications badge from /notifications', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.role = 'client';
    stubCommon(httpClient, unreadNotifs: 3);

    await pumpPage(tester, api);

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('sub-user role loads its own permissions via /sub-users/:id', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.role = 'sub_user';
    api.subUserId = 1;
    stubCommon(httpClient, subUserJson: '{"sub_user":{"id":1,"permissions":{"can_view_contracts":true,"can_view_payments":true}}}');

    await pumpPage(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/sub-users/1')), headers: any(named: 'headers'))).called(1);
  });

  testWidgets('logout confirmation clears the token and navigates to /login', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.role = 'client';
    stubCommon(httpClient);

    await pumpPage(tester, api);
    await tester.tap(find.byIcon(Icons.logout_rounded));
    await pumpBriefly(tester);
    // The confirmation dialog's title and its confirm button both read
    // "Logout" (dashboard_logout / dashboard_logoutAction) — target the
    // button specifically, not the title.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
    await pumpBriefly(tester);

    expect(find.text('LOGIN_PAGE'), findsOneWidget);
  });

  testWidgets('a workspace status change over reverb reloads the client data', (tester) async {
    // REALTIME_PLAN.md Stage 5 — mirrors chat_page_test.dart's own
    // "a contract status change over reverb reloads the messages" regression
    // test. onWorkspaceStatusChanged/onPaymentStatusChanged are wired to the
    // same _loadClientData() reload as the existing onContractStatusChanged.
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.role = 'client';
    stubCommon(httpClient);

    final reverb = await pumpPage(tester, api);
    // Called twice already (this screen's own load + the embedded
    // SignatureTab's), same as the first test in this file.
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients/10')), headers: any(named: 'headers'))).called(2);

    reverb.onWorkspaceStatusChanged?.call({'status': 'active'});
    await pumpBriefly(tester);

    // Confirmed empirically in chat_page_test.dart: mocktail's verify()
    // consumes the interactions it checks, so this only counts calls that
    // happened after the one above.
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients/10')), headers: any(named: 'headers'))).called(1);
  });

  testWidgets('a payment status change over reverb reloads the client data', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.role = 'client';
    stubCommon(httpClient);

    final reverb = await pumpPage(tester, api);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients/10')), headers: any(named: 'headers'))).called(2);

    reverb.onPaymentStatusChanged?.call({'status': 'approved'});
    await pumpBriefly(tester);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients/10')), headers: any(named: 'headers'))).called(1);
  });
}
