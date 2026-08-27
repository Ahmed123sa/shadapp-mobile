import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/client_repository.dart';
import 'package:shadapp_client/data/contract_repository.dart';
import 'package:shadapp_client/data/payment_repository.dart';
import 'package:shadapp_client/features/am/dashboard/sa_approvals_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
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

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider);

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

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider);

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

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider);

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

    await pumpPage(tester, clientProvider, contractProvider, paymentProvider);
    await tester.tap(find.textContaining('Approve Contract'));
    await tester.pumpAndSettle();

    expect(find.text('WORKSPACE_PAGE'), findsOneWidget);
  });
}
