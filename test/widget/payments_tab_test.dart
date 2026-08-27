// Characterization test for am/workspace/payments_tab.dart, written BEFORE
// any behavior migration (see docs/state-layer-migration-plan.md, Path A).
// Locks in the screen's CURRENT behavior so later commits that move it onto
// PaymentProvider/ContractProvider can prove they changed nothing.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/am/workspace/payments_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpTab(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PaymentsTab(workspaceId: 5, api: api)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads payments and contracts, shows the total-paid summary and a payment card', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse(
        '{"payments":[{"id":1,"amount":500,"currency":"SAR","status":"pending","created_at":"2026-01-01T00:00:00Z"}],"tax_summary":null}',
      );
    });

    await pumpTab(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments'))),
        headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/contracts'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('500 SAR'), findsOneWidget);
    expect(find.text('No payments'), findsNothing);
  });

  testWidgets('shows the empty state when there are no payments', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse('{"payments":[],"tax_summary":null}');
    });

    await pumpTab(tester, api);

    expect(find.text('No payments'), findsOneWidget);
  });

  testWidgets('shows the error state when the payments load fails', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );

    await pumpTab(tester, api);

    expect(find.text('Failed to load payments'), findsOneWidget);
  });

  testWidgets('super admin approving a pending payment posts action=approved and shows the active-workspace message', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse(
        '{"payments":[{"id":7,"amount":500,"currency":"SAR","status":"pending"}],"tax_summary":null}',
      );
    });
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"workspace":{"status":"active"}}');
    });

    await pumpTab(tester, api);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(sentBody, {'action': 'approved'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/payments/7/review'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.text('Payment approved — workspace is now active'), findsOneWidget);
  });

  testWidgets('account manager scheduling an installment posts to /workspaces/:id/payments/schedule', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse(
        '{"payments":[{"id":1,"amount":500,"currency":"SAR","status":"pending"}],"tax_summary":null}',
      );
    });
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpTab(tester, api);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Installment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Schedule (1 installments)'));
    await tester.pumpAndSettle();

    expect(sentBody!['installments'], isA<List>());
    expect((sentBody!['installments'] as List).first['amount'], 100.0);
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments/schedule'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.text('Payments scheduled successfully'), findsOneWidget);
  });

  testWidgets('account manager requesting a payment posts to /workspaces/:id/payments/request', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse('{"payments":[{"id":1,"amount":500,"currency":"SAR","status":"pending"}],"tax_summary":null}');
    });
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpTab(tester, api);
    await tester.tap(find.byIcon(Icons.request_quote));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '250');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Request'));
    await tester.pumpAndSettle();

    expect(sentBody, {'amount': 250.0, 'currency': 'SAR'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments/request'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.text('Payment request sent successfully'), findsOneWidget);
  });

  testWidgets('account manager clearing a scheduled installment confirms and calls DELETE /payments/:id/schedule', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    var loadCount = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      loadCount++;
      if (loadCount == 1) {
        return jsonResponse(
          '{"payments":[{"id":3,"amount":300,"currency":"SAR","status":"scheduled","requested_by_manager":true}],"tax_summary":null}',
        );
      }
      return jsonResponse('{"payments":[],"tax_summary":null}');
    });
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer((_) async => jsonResponse('{}'));

    await pumpTab(tester, api);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Clear'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/payments/3/schedule'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('Installment cleared successfully'), findsOneWidget);
  });
}
