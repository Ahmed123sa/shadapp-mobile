// Characterization test for payments_page.dart, written BEFORE any behavior
// migration (see docs/state-layer-migration-plan.md, Path A). This locks in
// the screen's CURRENT behavior — including its existing quirks — so later
// commits that move it onto PaymentProvider/ContractProvider can prove they
// changed nothing. Do not "fix" anything found here without updating the
// plan's bug-tracking policy first.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/payments/payments_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PaymentsPage(api: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads payments and contracts for the current workspace and shows a payment card', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse(
        '{"payments":[{"id":1,"amount":500,"currency":"SAR","status":"pending","method_type":"bank_transfer","created_at":"2026-01-01T00:00:00Z"}],'
        '"available_methods":["bank_transfer","swift"],"tax_summary":null}',
      );
    });

    await pumpPage(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments'))),
        headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/contracts'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('500 SAR'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets); // filter chip label + card status both read "Pending"
    expect(find.text('No payments'), findsNothing);
  });

  testWidgets('shows the empty state when there are no payments', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse('{"payments":[],"available_methods":[],"tax_summary":null}');
    });

    await pumpPage(tester, api);

    expect(find.text('No payments'), findsOneWidget);
  });

  testWidgets('filtering to Accepted hides non-approved payments', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse(
        '{"payments":[{"id":1,"amount":111,"currency":"SAR","status":"pending"},'
        '{"id":2,"amount":222,"currency":"SAR","status":"approved"}],'
        '"available_methods":[],"tax_summary":null}',
      );
    });

    await pumpPage(tester, api);
    expect(find.text('111 SAR'), findsOneWidget);
    expect(find.text('222 SAR'), findsOneWidget);

    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();

    expect(find.text('111 SAR'), findsNothing);
    expect(find.text('222 SAR'), findsOneWidget);
  });

  testWidgets('shows the error state with retry when the payments load fails', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );

    await pumpPage(tester, api);

    expect(find.text('Failed to load payments'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('requesting a payment posts a plain JSON body to /workspaces/:id/payments and reloads', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    var loadCount = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      loadCount++;
      return jsonResponse('{"payments":[],"available_methods":["bank_transfer"],"tax_summary":null}');
    });
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpPage(tester, api);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '250');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();

    expect(sentBody!['amount'], 250.0);
    expect(sentBody!['currency'], 'SAR');
    expect(sentBody!['method_type'], 'bank_transfer');
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.text('Payment request sent'), findsOneWidget);
    expect(loadCount, 2); // initial load + reload after successful submit
  });

  testWidgets('requesting a payment with an invalid amount shows a validation message and does not call the API', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse('{"payments":[],"available_methods":["bank_transfer"],"tax_summary":null}');
    });

    await pumpPage(tester, api);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid amount'), findsOneWidget);
    verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
  });
}
