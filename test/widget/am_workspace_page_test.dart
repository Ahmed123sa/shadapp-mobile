// Characterization test for am/workspace/am_workspace_page.dart, written
// BEFORE any behavior migration (see docs/state-layer-migration-plan.md,
// Path D). Locks in the screen's CURRENT behavior so a later commit that
// moves its one domain (_fetchWorkspace) onto ChatProvider.fetchWorkspace
// can prove it changed nothing.
//
// This screen embeds EIGHT tabs in a TabBar-driven IndexedStack (which mounts
// every tab eagerly, not lazily), so all eight had to already be seamed
// (ApiClient?/provider params) before this screen could be pumped at all —
// contracts_tab.dart was the one gap (Path B, still deferred for its own
// domain migration) and got the same minimal mechanical seam used for
// contracts_page.dart/admin_settings_page.dart elsewhere in this migration.
// meetings_tab.dart has no `api` param (only provider params) — its internal
// `_api` field stays hardcoded to the real singleton, but it's only read for
// a local `.role` check, never for a network call, so it doesn't block
// testing this screen (see the `tearDown` below, which resets it defensively
// so that read doesn't leak state into other test files).
//
// `enablePolling: false` on ChatTab avoids the same RealtimePoller problem
// documented in client_dashboard_screen_test.dart.
//
// Not covered here: each embedded tab's own behavior beyond "it loads
// without crashing" — every one of them already has its own
// characterization/unit test suite. Also not covered: the back-arrow ->
// Navigator.pop() interaction — pushing this screen with a real
// MaterialPageRoute triggers a pre-existing Hero-tag conflict ("multiple
// heroes share the same tag: <default FloatingActionButton tag>"), because
// three of the eight embedded tabs (payments_tab.dart, meetings_tab.dart,
// files_tab.dart) each nest their own Scaffold with an untagged
// FloatingActionButton, and IndexedStack keeps all eight mounted at once.
// That's a real, pre-existing characteristic of this screen, not something
// introduced by this seam — left undisturbed per the plan's policy of not
// fixing incidental bugs while migrating.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/api_client.dart';
import 'package:shadapp_client/core/reverb_service.dart';
import 'package:shadapp_client/features/am/workspace/am_workspace_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  tearDown(() {
    ApiClient().role = null;
  });

  void stubCommon(MockHttpClient httpClient, {
    String workspaceJson = '{"workspace":{"id":5,"status":"active","client":{"id":20,"company_name":"Acme","contact_person":"Ali","client_type":"company"}}}',
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/workspaces/5') return jsonResponse(workspaceJson);
      if (path == '/workspaces/5/contracts') return jsonResponse('{"contracts":[]}');
      if (path == '/workspaces/5/chat') return jsonResponse('{"messages":[]}');
      if (path == '/workspaces/5/payments') return jsonResponse('{"payments":[],"tax_summary":null}');
      if (path == '/workspaces/5/approvals') return jsonResponse('{"approvals":[]}');
      if (path == '/workspaces/5/meetings') return jsonResponse('{"meetings":[]}');
      if (path == '/workspaces/5/files') return jsonResponse('{"files":[],"definitions":[]}');
      if (path == '/clients/20/profile') return jsonResponse('{"client":{},"stats":{},"location":{}}');
      return jsonResponse('{}');
    });
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/mark-read'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((_) async => jsonResponse('{}'));
  }

  // Avoid pumpAndSettle(): several embedded tabs share the same "safe under a
  // handful of bounded pumps" reasoning documented in
  // client_dashboard_screen_test.dart — a fixed pump budget is simpler than
  // re-auditing eight screens' timers on every future change here.
  Future<void> pumpBriefly(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpPage(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AmWorkspacePage(workspaceId: 5, api: api, reverb: ReverbService.forTesting()),
    ));
    await pumpBriefly(tester);
  }

  testWidgets('loads the workspace header from /workspaces/:id', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    stubCommon(httpClient);

    await pumpPage(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/workspaces/5')), headers: any(named: 'headers'))).called(greaterThanOrEqualTo(1));
    expect(find.text('Acme'), findsOneWidget);
    // "Ali" (the contact person) is rendered both in this screen's own
    // header and inside at least one embedded tab that shows the same
    // client info — a pre-existing duplication, not asserting an exact
    // count here.
    expect(find.text('Ali'), findsWidgets);
    expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
  });
}
