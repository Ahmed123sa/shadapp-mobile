import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/client_repository.dart';
import 'package:shadapp_client/data/manager_repository.dart';
import 'package:shadapp_client/data/report_repository.dart';
import 'package:shadapp_client/features/am/workspace/reports_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/client_provider.dart';
import 'package:shadapp_client/providers/manager_provider.dart';
import 'package:shadapp_client/providers/report_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpTab(WidgetTester tester, MockHttpClient httpClient) async {
    final api = buildTestApiClient(client: httpClient);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReportsTab(
          clientProvider: ClientProvider(repository: ClientRepository(api: api)),
          managerProvider: ManagerProvider(repository: ManagerRepository(api: api)),
          reportProvider: ReportProvider(repository: ReportRepository(api: api)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads and shows KPI values from /reports', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/clients')) return jsonResponse('{"clients":[]}');
      if (uri.path.endsWith('/account-managers')) return jsonResponse('{"managers":[]}');
      return jsonResponse(
        '{"total_clients":12,"payments_by_month":{},"contracts_by_status":{"draft":2},"pending_approvals":3,"active_workspaces":5}',
      );
    });

    await pumpTab(tester, httpClient);

    expect(find.text('Clients'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('shows the /reports error message with a retry button on failure', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/clients')) return jsonResponse('{"clients":[]}');
      if (uri.path.endsWith('/account-managers')) return jsonResponse('{"managers":[]}');
      return jsonResponse('{"message":"Server Error"}', 500);
    });

    await pumpTab(tester, httpClient);

    expect(find.text('Server Error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping "This Month" refetches /reports with a date_from/date_to filter', (tester) async {
    final httpClient = MockHttpClient();
    final reportQueries = <Uri>[];
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/clients')) return jsonResponse('{"clients":[]}');
      if (uri.path.endsWith('/account-managers')) return jsonResponse('{"managers":[]}');
      reportQueries.add(uri);
      return jsonResponse(
        '{"total_clients":0,"payments_by_month":{},"contracts_by_status":{"draft":1},"pending_approvals":0,"active_workspaces":0}',
      );
    });

    await pumpTab(tester, httpClient);
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();

    expect(reportQueries.last.queryParameters.containsKey('date_from'), true);
    expect(reportQueries.last.queryParameters.containsKey('date_to'), true);
  });

  // 21 Sept 2026 — the leaderboard used to fabricate a revenue figure
  // whenever manager_stats was empty (which was always, since the backend
  // never sent it): total revenue divided by a rank-based number. Now that
  // the backend sends real manager_stats, this asserts the real figure is
  // shown rather than a guess.
  testWidgets('shows a real per-manager revenue figure from manager_stats', (tester) async {
    // The AM leaderboard sits near the bottom of this tab's ListView, after
    // the KPI scroll and three charts — same "never gets Elements built
    // without scrolling" issue as client_detail_page_test.dart on the
    // default 800x600 test surface. A tall surface avoids scrolling between
    // assertions. Width stays at the default 800 (not 400 like
    // client_detail_page_test.dart) — a narrower width overflows the
    // section-header Row (title + subtitle + Spacer) that every chart
    // section in this tab shares, which is a pre-existing layout issue
    // unrelated to this fix.
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/clients')) return jsonResponse('{"clients":[]}');
      if (uri.path.endsWith('/account-managers')) return jsonResponse('{"managers":[]}');
      // contracts_by_status must be non-empty: _buildKpiScroll() does
      // contracts.values.map(...).reduce(...), and reduce() throws on an
      // empty iterable — same reason every other mock in this file
      // includes at least one status.
      return jsonResponse(
        '{"total_clients":1,"payments_by_month":{},"contracts_by_status":{"draft":1},"pending_approvals":0,'
        '"active_workspaces":0,"manager_stats":[{"name":"Sara","revenue":1500,"clients":3,"contracts":2}]}',
      );
    });

    await pumpTab(tester, httpClient);

    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('1500'), findsOneWidget);
  });

  // When manager_stats is genuinely empty (no account managers on file), the
  // leaderboard falls back to the plain /account-managers list for names —
  // but must show "no data" for revenue, not invent one.
  testWidgets('falls back to "—" for revenue when manager_stats is empty', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/clients')) return jsonResponse('{"clients":[]}');
      if (uri.path.endsWith('/account-managers')) {
        return jsonResponse('{"managers":[{"id":1,"name":"Ali"}]}');
      }
      return jsonResponse(
        '{"total_clients":1,"payments_by_month":{"2026-09":50000},"contracts_by_status":{"draft":1},'
        '"pending_approvals":0,"active_workspaces":0,"manager_stats":[]}',
      );
    });

    await pumpTab(tester, httpClient);

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    // The old bug: 50000 (the total) divided down into a fake per-row
    // number. Assert that math isn't happening anymore.
    expect(find.text('50000'), findsNothing);
    expect(find.text('16666'), findsNothing);
  });
}
