import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/dashboard_stats_repository.dart';
import 'package:shadapp_client/features/am/dashboard/sa_approvals_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/dashboard_stats_provider.dart';
import '../helpers/mock_http_client.dart';

// 26 Sept 2026 — pending-approvals-plan.md ك5. This screen used to build its
// list from a per-client-workspace N+1 loop (fetch every client, then that
// client's workspace's contracts, one request each) plus two more
// full-pagination loops for payments and approvals. It now makes a single
// GET /dashboard/pending-approvals call (already scoped server-side to this
// user, same DashboardScope the SA/AM stat cards and badge use) via
// DashboardStatsProvider — see DashboardController::pendingApprovals(). This
// file replaces the old per-endpoint mocks (/clients, /workspaces/:id/
// contracts, /payments/pending, /approvals/pending) with a single
// /dashboard/pending-approvals mock per test.
void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, DashboardStatsProvider provider) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(body: SaApprovalsPage(dashboardStatsProvider: provider)),
        ),
        GoRoute(path: '/am/workspace/:id', builder: (_, __) => const Scaffold(body: Text('WORKSPACE_PAGE'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> emptyResponse() => {
        'awaiting_you': {'contracts': [], 'payments': []},
        'awaiting_client': {'contracts': [], 'approvals': []},
      };

  testWidgets('shows sent/client_approved contracts and pending payments together', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/dashboard/pending-approvals') {
        return jsonResponse('''
        {
          "awaiting_you": {
            "contracts": [{"id": 1, "type": "contract", "title": "MSA", "value": 1000, "currency": "SAR", "status": "client_approved", "workspace_id": 5, "client": {"id": 1, "uuid": "u1", "company_name": "Acme", "client_type": "business"}}],
            "payments": [{"id": 9, "type": "payment", "amount": 500, "currency": "SAR", "status": "pending", "workspace_id": 5, "client": {"id": 1, "uuid": "u1", "company_name": "Acme", "client_type": "business"}}]
          },
          "awaiting_client": {"contracts": [], "approvals": []}
        }
        ''');
      }
      return jsonResponse('{}');
    });
    final provider = DashboardStatsProvider(repository: DashboardStatsRepository(api: api));

    await pumpPage(tester, provider);

    expect(find.text('2'), findsOneWidget); // total badge
    expect(find.textContaining('Approve Contract'), findsOneWidget);
    expect(find.textContaining('Approve Payment'), findsOneWidget);
    // client_type travelled through from the endpoint (pending-approvals-plan.md
    // ك5's backend prerequisite) and renders the same badge every other
    // client-linked list item shows.
    expect(find.text('Company'), findsWidgets);
  });

  testWidgets('shows the empty state when nothing is pending', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{}'));
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/dashboard/pending-approvals')),
            headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse(jsonEncode(emptyResponse())));
    final provider = DashboardStatsProvider(repository: DashboardStatsRepository(api: api));

    await pumpPage(tester, provider);

    expect(find.text('No pending approvals'), findsOneWidget);
  });

  testWidgets('shows the empty state instead of crashing when the request fails', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{"message":"Server error"}', 500));
    final provider = DashboardStatsProvider(repository: DashboardStatsRepository(api: api));

    await pumpPage(tester, provider);

    expect(find.text('No pending approvals'), findsOneWidget);
    expect(find.text('0'), findsOneWidget); // total badge
  });

  testWidgets('tapping a contract navigates to its workspace route', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/dashboard/pending-approvals') {
        return jsonResponse('''
        {
          "awaiting_you": {"contracts": [], "payments": []},
          "awaiting_client": {
            "contracts": [{"id": 1, "type": "contract", "title": "MSA", "value": 1000, "currency": "SAR", "status": "sent", "workspace_id": 5, "client": {"id": 1, "uuid": "u1", "company_name": "Acme"}}],
            "approvals": []
          }
        }
        ''');
      }
      return jsonResponse('{}');
    });
    final provider = DashboardStatsProvider(repository: DashboardStatsRepository(api: api));

    await pumpPage(tester, provider);
    await tester.tap(find.textContaining('Approve Contract'));
    await tester.pumpAndSettle();

    expect(find.text('WORKSPACE_PAGE'), findsOneWidget);
  });

  // 23 Sept 2026 — the "Approvals" badge on the AM dashboard
  // (DashboardController::amCounts()) counts pending Approval records
  // (workspace-level approval requests the AM raised for a client) alongside
  // pending contracts; this screen's Approvals filter must match.
  const pendingApprovalBlock =
      '{"id": 5, "type": "approval", "title": "Design Mockup", "status": "pending", "workspace_id": 9, '
      '"client": {"id": 1, "uuid": "u1", "company_name": "Acme"}}';

  testWidgets('lists a pending Approval request alongside the Approvals filter count', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/dashboard/pending-approvals') {
        return jsonResponse('''
        {
          "awaiting_you": {"contracts": [], "payments": []},
          "awaiting_client": {"contracts": [], "approvals": [$pendingApprovalBlock]}
        }
        ''');
      }
      return jsonResponse('{}');
    });
    final provider = DashboardStatsProvider(repository: DashboardStatsRepository(api: api));

    await pumpPage(tester, provider);

    expect(find.textContaining('Approvals (1)'), findsOneWidget);
    expect(find.textContaining('Awaiting Client'), findsOneWidget);
    expect(find.textContaining('Design Mockup'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget); // company from the nested client
  });

  testWidgets('fetches pending approvals in a single request with the uncapped limit', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse(jsonEncode(emptyResponse())));
    final provider = DashboardStatsProvider(repository: DashboardStatsRepository(api: api));

    await pumpPage(tester, provider);

    verify(() => httpClient.get(
          any(that: predicate<Uri>((u) => u.path == '/dashboard/pending-approvals' && u.queryParameters['limit'] == '200')),
          headers: any(named: 'headers'),
        )).called(1);
    // No more per-client/per-workspace fan-out.
    verifyNever(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients')), headers: any(named: 'headers')));
  });

  testWidgets('the total sums contracts and approvals (matches the badge when nothing else is pending)', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/dashboard/pending-approvals') {
        return jsonResponse('''
        {
          "awaiting_you": {"contracts": [], "payments": []},
          "awaiting_client": {
            "contracts": [{"id": 2, "type": "contract", "title": "Retainer", "value": 1000, "currency": "SAR", "status": "sent", "workspace_id": 9, "client": {"id": 1, "uuid": "u1", "company_name": "Acme"}}],
            "approvals": [$pendingApprovalBlock]
          }
        }
        ''');
      }
      return jsonResponse('{}');
    });
    final provider = DashboardStatsProvider(repository: DashboardStatsRepository(api: api));

    await pumpPage(tester, provider);

    // 1 pending contract + 1 pending approval = 2 — what amCounts()/counts.total
    // report for the same data.
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('tapping an approval navigates to its workspace route', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/dashboard/pending-approvals') {
        return jsonResponse('''
        {
          "awaiting_you": {"contracts": [], "payments": []},
          "awaiting_client": {"contracts": [], "approvals": [$pendingApprovalBlock]}
        }
        ''');
      }
      return jsonResponse('{}');
    });
    final provider = DashboardStatsProvider(repository: DashboardStatsRepository(api: api));

    await pumpPage(tester, provider);
    await tester.tap(find.textContaining('Awaiting Client'));
    await tester.pumpAndSettle();

    expect(find.text('WORKSPACE_PAGE'), findsOneWidget);
  });
}
