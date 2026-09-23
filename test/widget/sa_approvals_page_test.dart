import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/approval_repository.dart';
import 'package:shadapp_client/data/client_repository.dart';
import 'package:shadapp_client/data/payment_repository.dart';
import 'package:shadapp_client/features/am/dashboard/sa_approvals_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/approval_provider.dart';
import 'package:shadapp_client/providers/client_provider.dart';
import 'package:shadapp_client/providers/contract_provider.dart';
import 'package:shadapp_client/providers/payment_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(
    WidgetTester tester,
    ClientProvider clientProvider,
    ContractProvider contractProvider,
    PaymentProvider paymentProvider,
    ApprovalProvider approvalProvider,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SaApprovalsPage(
              clientProvider: clientProvider,
              contractProvider: contractProvider,
              paymentProvider: paymentProvider,
              approvalProvider: approvalProvider,
            ),
          ),
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

  testWidgets('shows sent/client_approved contracts and pending payments together', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients') {
        return jsonResponse('{"clients":[{"id":1,"company_name":"Acme","workspace":{"id":5}}]}');
      }
      if (path.endsWith('/workspaces/5/contracts')) {
        return jsonResponse('{"contracts":[{"id":1,"title":"MSA","status":"sent","value":1000,"currency":"SAR"}]}');
      }
      if (path == '/payments/pending') {
        return jsonResponse('{"payments":[{"id":9,"amount":500,"currency":"SAR","workspace_id":5}]}');
      }
      return jsonResponse('{}');
    });
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final contractProvider = ContractProvider(api: api);
    final paymentProvider = PaymentProvider(repository: PaymentRepository(api: api));
    final approvalProvider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider, approvalProvider);

    expect(find.text('2'), findsOneWidget); // total badge
    expect(find.textContaining('Approve Contract'), findsOneWidget);
    expect(find.textContaining('Approve Payment'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing is pending', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients":[],"payments":[]}'),
    );
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final contractProvider = ContractProvider(api: api);
    final paymentProvider = PaymentProvider(repository: PaymentRepository(api: api));
    final approvalProvider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider, approvalProvider);

    expect(find.text('No pending approvals'), findsOneWidget);
  });

  testWidgets('a workspace whose contracts fail to load does not drop the rest of the list', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients') {
        return jsonResponse(
          '{"clients":[{"id":1,"company_name":"Broken","workspace":{"id":5}},{"id":2,"company_name":"Acme","workspace":{"id":6}}]}',
        );
      }
      if (path.endsWith('/workspaces/5/contracts')) {
        return jsonResponse('{"message":"Server error"}', 500);
      }
      if (path.endsWith('/workspaces/6/contracts')) {
        return jsonResponse('{"contracts":[{"id":1,"title":"MSA","status":"sent","value":1000,"currency":"SAR"}]}');
      }
      if (path == '/payments/pending') {
        return jsonResponse('{"payments":[]}');
      }
      return jsonResponse('{}');
    });
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final contractProvider = ContractProvider(api: api);
    final paymentProvider = PaymentProvider(repository: PaymentRepository(api: api));
    final approvalProvider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider, approvalProvider);

    expect(find.textContaining('Approve Contract'), findsOneWidget);
  });

  testWidgets('tapping an item navigates to its workspace route', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients') {
        return jsonResponse('{"clients":[{"id":1,"company_name":"Acme","workspace":{"id":5}}]}');
      }
      if (path.endsWith('/workspaces/5/contracts')) {
        return jsonResponse('{"contracts":[{"id":1,"title":"MSA","status":"sent","value":1000,"currency":"SAR"}]}');
      }
      if (path == '/payments/pending') {
        return jsonResponse('{"payments":[]}');
      }
      return jsonResponse('{}');
    });
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final contractProvider = ContractProvider(api: api);
    final paymentProvider = PaymentProvider(repository: PaymentRepository(api: api));
    final approvalProvider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider, approvalProvider);
    await tester.tap(find.textContaining('Approve Contract'));
    await tester.pumpAndSettle();

    expect(find.text('WORKSPACE_PAGE'), findsOneWidget);
  });

  // 23 Sept 2026 — the "Approvals" badge on the AM dashboard
  // (DashboardController::amCounts()) counts pending Approval records
  // (workspace-level approval requests the AM raised for a client)
  // alongside pending contracts, but this screen used to only fetch/list
  // contracts+payments — never the Approval model at all. So the badge
  // could say 2 while this list only showed 1. Pending approvals now come
  // from one GET /approvals/pending (server-scoped to the user's workspaces,
  // each with workspace.client nested), not one request per workspace.
  const pendingApprovalJson =
      '{"approvals":[{"id":5,"status":"pending","title":"Design Mockup","workspace_id":9,'
      '"workspace":{"id":9,"client":{"id":1,"company_name":"Acme"}}}]}';

  testWidgets('lists a pending Approval request alongside the Approvals filter count', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients') return jsonResponse('{"clients":[]}');
      if (path == '/payments/pending') return jsonResponse('{"payments":[]}');
      if (path == '/approvals/pending') return jsonResponse(pendingApprovalJson);
      return jsonResponse('{}');
    });
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final contractProvider = ContractProvider(api: api);
    final paymentProvider = PaymentProvider(repository: PaymentRepository(api: api));
    final approvalProvider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider, approvalProvider);

    expect(find.textContaining('Approvals (1)'), findsOneWidget);
    expect(find.textContaining('Awaiting Client'), findsOneWidget);
    expect(find.textContaining('Design Mockup'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget); // company from the nested workspace.client
  });

  testWidgets('fetches pending approvals in one request, not once per workspace', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients') {
        return jsonResponse(
          '{"clients":[{"id":1,"company_name":"Acme","workspace":{"id":9}},{"id":2,"company_name":"Beta","workspace":{"id":10}}]}',
        );
      }
      if (path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      if (path == '/payments/pending') return jsonResponse('{"payments":[]}');
      if (path == '/approvals/pending') return jsonResponse(pendingApprovalJson);
      return jsonResponse('{}');
    });
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final contractProvider = ContractProvider(api: api);
    final paymentProvider = PaymentProvider(repository: PaymentRepository(api: api));
    final approvalProvider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider, approvalProvider);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/approvals/pending')),
        headers: any(named: 'headers'))).called(1);
    verifyNever(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/approvals') && u.path.startsWith('/workspaces/'))),
        headers: any(named: 'headers')));
  });

  testWidgets('the total sums contracts and approvals (matches the badge when nothing else is pending)', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients') {
        return jsonResponse('{"clients":[{"id":1,"company_name":"Acme","workspace":{"id":9}}]}');
      }
      if (path.endsWith('/workspaces/9/contracts')) {
        return jsonResponse('{"contracts":[{"id":2,"title":"Retainer","status":"sent","value":1000,"currency":"SAR"}]}');
      }
      if (path == '/payments/pending') return jsonResponse('{"payments":[]}');
      if (path == '/approvals/pending') return jsonResponse(pendingApprovalJson);
      return jsonResponse('{}');
    });
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final contractProvider = ContractProvider(api: api);
    final paymentProvider = PaymentProvider(repository: PaymentRepository(api: api));
    final approvalProvider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider, approvalProvider);

    // 1 pending contract + 1 pending approval = 2 — what amCounts() reports
    // for the same data. (Pending payments show in this list too but not in
    // that badge — a separate, still-open question.)
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('tapping an approval navigates to its workspace route', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients') return jsonResponse('{"clients":[]}');
      if (path == '/payments/pending') return jsonResponse('{"payments":[]}');
      if (path == '/approvals/pending') return jsonResponse(pendingApprovalJson);
      return jsonResponse('{}');
    });
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final contractProvider = ContractProvider(api: api);
    final paymentProvider = PaymentProvider(repository: PaymentRepository(api: api));
    final approvalProvider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider, approvalProvider);
    await tester.tap(find.textContaining('Awaiting Client'));
    await tester.pumpAndSettle();

    expect(find.text('WORKSPACE_PAGE'), findsOneWidget);
  });
}
