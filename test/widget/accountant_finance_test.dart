import 'dart:convert';
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

  const body = '{"payments":{"data":[{"id":23,"workspace_id":5,"amount":"12000","currency":"EGP","status":"pending","method_type":"instapay",'
      '"created_at":"2026-10-17T10:00:00Z","workspace":{"client":{"company_name":"Orbit Clinics"},"manager":{"name":"Mariam Fathy"}}}],'
      '"current_page":1,"last_page":1,"total":1},"stats":{"total_count":1,"approved_count":0,"pending_count":1,"approved_by_currency":{}}}';

  Future<(MockHttpClient, Map<String, dynamic>?Function())> pumpPage(WidgetTester tester, String? role) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = role;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async => jsonResponse(body));
    Map<String, dynamic>? sent;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sent = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"payment":{"id":23,"status":"approved"}}');
    });
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
    return (httpClient, () => sent);
  }

  testWidgets('a manager (or no role) sees no approve / reject buttons', (tester) async {
    await pumpPage(tester, 'account_manager');
    expect(find.byKey(const ValueKey('finance-approve-23')), findsNothing);
    expect(find.byKey(const ValueKey('finance-reject-23')), findsNothing);
  });

  testWidgets('the accountant rejects only with a reason of at least 5 characters', (tester) async {
    final (httpClient, sent) = await pumpPage(tester, 'accountant');
    await tester.tap(find.byKey(const ValueKey('finance-reject-23')));
    await tester.pumpAndSettle();

    ElevatedButton confirm() => tester.widget<ElevatedButton>(find.byKey(const ValueKey('reject-reason-confirm')));
    expect(confirm().onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('reject-reason-field')), 'abcd');
    await tester.pump();
    expect(confirm().onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('reject-reason-field')), 'Blurry proof image');
    await tester.pump();
    expect(confirm().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('reject-reason-confirm')));
    await tester.pumpAndSettle();

    expect(sent()!['action'], 'rejected');
    expect(sent()!['rejection_reason'], 'Blurry proof image');
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/payments/23/review'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  testWidgets('the accountant approves after confirming', (tester) async {
    final (_, sent) = await pumpPage(tester, 'accountant');
    await tester.tap(find.byKey(const ValueKey('finance-approve-23')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(sent(), {'action': 'approved'});
  });
}
