import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/payment_repository.dart';
import 'package:shadapp_client/features/am/finance/finance_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/payment_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  const body = '{"payments":{"data":[{"id":24,"amount":"23000","currency":"EGP","status":"approved","method_type":"bank_transfer",'
      '"created_at":"2026-10-16T10:00:00Z","workspace":{"client":{"company_name":"Relax"},"manager":{"name":"Taha Ahmed"}}},'
      '{"id":23,"amount":"12000","currency":"EGP","status":"pending","method_type":"instapay","created_at":"2026-10-17T10:00:00Z",'
      '"workspace":{"client":{"company_name":"Orbit Clinics"},"manager":{"name":"Mariam Fathy"}}}],"current_page":1,"last_page":2,"total":30},'
      '"stats":{"total_count":30,"approved_count":20,"pending_count":4,"approved_by_currency":{"EGP":79500,"USD":100}}}';

  Future<MockHttpClient> pumpPage(WidgetTester tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async => jsonResponse(body));
    final provider = PaymentProvider(repository: PaymentRepository(api: api));
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FinancePage(paymentProvider: provider, api: api),
    ));
    await tester.pumpAndSettle();
    return httpClient;
  }

  testWidgets('shows the approved total, counts and the payment cards', (tester) async {
    final httpClient = await pumpPage(tester);

    expect(find.text('Relax'), findsOneWidget);
    expect(find.text('Orbit Clinics'), findsOneWidget);
    expect(find.textContaining('79,500'), findsOneWidget);
    expect(find.text('30'), findsOneWidget); // all payments (stats.total_count)
    expect(find.text('4'), findsOneWidget); // pending
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/all-payments') && u.queryParameters['page'] == '1')),
        headers: any(named: 'headers'))).called(1);
  });

  testWidgets('a status chip refetches with that status', (tester) async {
    final httpClient = await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('finance-chip-pending')));
    await tester.pumpAndSettle();

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/all-payments') && u.queryParameters['status'] == 'pending')),
        headers: any(named: 'headers'))).called(1);
  });

  testWidgets('load more fetches the next page', (tester) async {
    final httpClient = await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('finance-load-more')));
    await tester.pumpAndSettle();

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/all-payments') && u.queryParameters['page'] == '2')),
        headers: any(named: 'headers'))).called(1);
  });
}
