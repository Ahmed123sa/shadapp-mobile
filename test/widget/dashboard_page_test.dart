// Characterization test for dashboard/dashboard_page.dart, written BEFORE any
// behavior migration (see docs/state-layer-migration-plan.md, Path D). Locks
// in the screen's CURRENT behavior so a later commit that moves its one
// domain (_loadClientData) onto ClientProvider.fetchClientRaw can prove it
// changed nothing.
//
// This screen renders EITHER ClientDashboardScreen (active workspace) OR
// ClientOnboardingScreen (no workspace / inactive) — never both at once,
// unlike the IndexedStack screens elsewhere in this migration. Only the
// active-workspace branch is exercised here: ClientOnboardingScreen has no
// testability seam yet (Path C, still deferred — task list item #153), so
// every stub below keeps the workspace active to avoid that branch. Its own
// seam/characterization work belongs to that screen's own slice, not this
// one.
//
// `enableFcm: false` avoids the same FirebaseMessaging.onMessage problem
// documented in client_dashboard_screen_test.dart. `enablePolling: false` is
// threaded through to the embedded ClientDashboardScreen for the same
// RealtimePoller reason documented there too.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/reverb_service.dart';
import 'package:shadapp_client/features/dashboard/client_dashboard_screen.dart';
import 'package:shadapp_client/features/dashboard/dashboard_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  // ClientDashboardScreen's own _loadClientData() calls
  // ApiClient.setUserData(), which hits SharedPreferences.getInstance() —
  // needs mock init values under plain `flutter test`, same as
  // client_dashboard_screen_test.dart.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void stubActiveWorkspace(MockHttpClient httpClient, {
    String clientJson = '{"client":{"id":10,"workspace":{"id":5,"status":"active"}}}',
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients/10') return jsonResponse(clientJson);
      if (path == '/notifications') return jsonResponse('{"unread_count":"0"}');
      if (path == '/badge-counts') return jsonResponse('{"contracts":"0","payments":"0","approvals":"0","files":"0"}');
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

  Future<void> pumpBriefly(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Crosses ClientDashboardScreen's own 2s Future.delayed
    // (_hasInitialTabOverride) — see client_dashboard_screen_test.dart.
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> pumpPage(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DashboardPage(api: api, reverb: ReverbService.forTesting(), enableFcm: false, enablePolling: false),
    ));
    await pumpBriefly(tester);
  }

  testWidgets('loads client data and renders ClientDashboardScreen for an active workspace', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.role = 'client';
    stubActiveWorkspace(httpClient);

    await pumpPage(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients/10')), headers: any(named: 'headers'))).called(greaterThanOrEqualTo(1));
    expect(find.byType(ClientDashboardScreen), findsOneWidget);
  });

  testWidgets('a failed fetch shows an error state that a retry does not clear (pre-existing quirk)', (tester) async {
    // _loadClientData() sets `_error` in its catch block but never resets it
    // to null on a later successful fetch — so once a load fails, the error
    // screen is shown forever, even if a subsequent retry actually succeeds
    // (build() checks `_error != null` before `_isActiveWorkspace`). This is
    // a genuine pre-existing bug in dashboard_page.dart, not something this
    // seam introduces — documented here rather than fixed, per the
    // migration's policy of not repairing incidental bugs while migrating.
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.role = 'client';
    var shouldFail = true;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      if (shouldFail) throw Exception('Server error');
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients/10') return jsonResponse('{"client":{"id":10,"workspace":{"id":5,"status":"active"}}}');
      return jsonResponse('{}');
    });

    await pumpPage(tester, api);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    shouldFail = false;
    stubActiveWorkspace(httpClient);
    await tester.tap(find.byType(ElevatedButton));
    await pumpBriefly(tester);

    // Still stuck on the error screen despite the retry succeeding — see the
    // comment above.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byType(ClientDashboardScreen), findsNothing);
  });
}
