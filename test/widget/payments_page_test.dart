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
import 'package:shadapp_client/data/payment_repository.dart';
import 'package:shadapp_client/features/payments/payments_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/contract_provider.dart';
import 'package:shadapp_client/providers/payment_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // paymentProvider/contractProvider must be wired to the same mocked
      // `api`, otherwise they fall back to real providers backed by the real
      // ApiClient() singleton and the test hangs on a real network call.
      home: PaymentsPage(
        api: api,
        paymentProvider: PaymentProvider(repository: PaymentRepository(api: api)),
        contractProvider: ContractProvider(api: api),
      ),
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
    expect(find.descendant(of: find.byKey(const ValueKey('payment-card-1')), matching: find.text('500 SAR')), findsOneWidget);
    expect(find.text('Pending'), findsWidgets); // filter chip label + card status both read "Pending"
    expect(find.text('No payments'), findsNothing);
  });

  // Serves one /payments envelope and an (empty) contracts list.
  MockHttpClient serve(String paymentsJson) {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse(paymentsJson);
    });
    return httpClient;
  }

  Finder inBlock(String cur, Finder f) =>
      find.descendant(of: find.byKey(ValueKey('payments-lines-$cur')), matching: f);

  // The lines add up to the total: value + fee + conversion + tax.
  testWidgets('shows fixed summary lines that add up to the total, with no line for a zero fee', (tester) async {
    final api = buildTestApiClient(client: serve(
      '{"payments":[{"id":1,"amount":6170,"currency":"SAR","status":"approved"}],"available_methods":[],'
      '"tax_summary":{"contracts_total":5500,"tax_percentage":12,"tax_amount":670,"grand_total":6170,'
      '"by_currency":[{"currency":"SAR","contracts_total":5500,"company_fee_total":0,"conversion_total":0,'
      '"tax_amount":670,"grand_total":6170,"paid":6170,"remaining":0,"contracts":['
      '{"id":1,"title":"Retainer","currency":"SAR","value":5000,"tax_percentage":12,"tax_amount":600,"total":5600},'
      '{"id":2,"title":"Extra","currency":"SAR","value":500,"tax_percentage":14,"tax_amount":70,"total":570}]}]}}'))
      ..workspaceId = 5;

    await pumpPage(tester, api);

    expect(inBlock('SAR', find.text('5,500 SAR')), findsOneWidget);
    expect(inBlock('SAR', find.text('Tax')), findsOneWidget);
    expect(inBlock('SAR', find.text('670 SAR')), findsOneWidget);
    expect(inBlock('SAR', find.text('6,170 SAR')), findsOneWidget);
    expect(inBlock('SAR', find.text('Management fee')), findsNothing);
    expect(inBlock('SAR', find.text('Conversion fee')), findsNothing);
    expect(find.byKey(const ValueKey('payments-paid-in-full')), findsOneWidget);
  });

  testWidgets('lists value, fee, conversion and tax so they sum to 116,400', (tester) async {
    final api = buildTestApiClient(client: serve(
      '{"payments":[],"available_methods":[],"tax_summary":{"contracts_total":100000,"tax_percentage":14,'
      '"tax_amount":1400,"grand_total":116400,"by_currency":[{"currency":"SAR","contracts_total":100000,'
      '"company_fee_total":10000,"conversion_total":5000,"tax_amount":1400,"grand_total":116400,"paid":0,'
      '"remaining":116400,"contracts":[{"id":1,"title":"Retainer","currency":"SAR","value":100000,'
      '"tax_percentage":14,"tax_amount":1400,"total":111400,"total_due":116400}]}]}}'))
      ..workspaceId = 5;

    await pumpPage(tester, api);

    expect(inBlock('SAR', find.text('100,000 SAR')), findsOneWidget);
    expect(inBlock('SAR', find.text('Management fee')), findsOneWidget);
    expect(inBlock('SAR', find.text('10,000 SAR')), findsOneWidget);
    expect(inBlock('SAR', find.text('Conversion fee')), findsOneWidget);
    expect(inBlock('SAR', find.text('5,000 SAR')), findsOneWidget);
    expect(inBlock('SAR', find.text('Tax (14%)')), findsOneWidget);
    expect(inBlock('SAR', find.text('116,400 SAR')), findsOneWidget);
    expect(100000 + 10000 + 5000 + 1400, 116400);
  });

  testWidgets('keeps two currencies apart and never adds them', (tester) async {
    final api = buildTestApiClient(client: serve(
      '{"payments":[],"available_methods":[],"tax_summary":{"contracts_total":0,"tax_percentage":0,"tax_amount":0,'
      '"grand_total":0,"by_currency":['
      '{"currency":"SAR","contracts_total":5000,"company_fee_total":0,"conversion_total":0,"tax_amount":0,'
      '"grand_total":5000,"paid":2000,"remaining":3000,"contracts":[]},'
      '{"currency":"USD","contracts_total":800,"company_fee_total":0,"conversion_total":0,"tax_amount":0,'
      '"grand_total":800,"paid":0,"remaining":800,"contracts":[]}]}}'))
      ..workspaceId = 5;

    await pumpPage(tester, api);

    expect(find.byKey(const ValueKey('payments-block-SAR')), findsOneWidget);
    expect(find.byKey(const ValueKey('payments-block-USD')), findsOneWidget);
    expect(find.text('5,800 SAR'), findsNothing);
    expect(find.text('5,800 USD'), findsNothing);
  });

  testWidgets('hides contract details behind a toggle, shows the first 5, then all on request', (tester) async {
    final contracts = [
      for (var i = 1; i <= 50; i++)
        '{"id":$i,"title":"Deal $i","currency":"SAR","value":100,"tax_percentage":0,"tax_amount":0,"total":100}'
    ].join(',');
    final api = buildTestApiClient(client: serve(
      '{"payments":[],"available_methods":[],"tax_summary":{"contracts_total":5000,"tax_percentage":0,"tax_amount":0,'
      '"grand_total":5000,"by_currency":[{"currency":"SAR","contracts_total":5000,"company_fee_total":0,'
      '"conversion_total":0,"tax_amount":0,"grand_total":5000,"paid":0,"remaining":5000,"contracts":[$contracts]}]}}'))
      ..workspaceId = 5;

    await pumpPage(tester, api);

    expect(find.text('Deal 1'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('payments-details-toggle')));
    await tester.tap(find.byKey(const ValueKey('payments-details-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payments-detail-row-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('payments-detail-row-6')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('payments-show-all')));
    await tester.tap(find.byKey(const ValueKey('payments-show-all')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('payments-detail-row-50')), 400,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('payments-detail-row-50')), findsOneWidget);
  });

  testWidgets('closed contracts stay out of the balance and are listed as history with their payments', (tester) async {
    final api = buildTestApiClient(client: serve(
      '{"payments":[],"closed_payments":[{"id":77,"contract_id":5,"amount":4000,"currency":"SAR","status":"approved",'
      '"created_at":"2026-08-01T00:00:00Z"}],"available_methods":[],"tax_summary":{"contracts_total":5000,'
      '"tax_percentage":0,"tax_amount":0,"grand_total":5000,"by_currency":[{"currency":"SAR","contracts_total":5000,'
      '"company_fee_total":0,"conversion_total":0,"tax_amount":0,"grand_total":5000,"paid":0,"remaining":5000,'
      '"contracts":[]}],"closed":[{"id":5,"title":"Finished deal","currency":"SAR","total_due":4000,'
      '"closed_at":"2026-11-10T10:00:00Z","closed_outstanding":0}]}}'))
      ..workspaceId = 5;

    await pumpPage(tester, api);

    expect(find.text('Finished deal'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('payments-closed-toggle')));
    await tester.tap(find.byKey(const ValueKey('payments-closed-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Finished deal'), findsOneWidget);
    expect(find.text('4,000 SAR'), findsOneWidget);
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
    expect(find.descendant(of: find.byKey(const ValueKey('payment-card-1')), matching: find.text('111 SAR')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('payment-card-2')), matching: find.text('222 SAR')), findsOneWidget);

    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payment-card-1')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('payment-card-2')), matching: find.text('222 SAR')), findsOneWidget);
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
      // The sheet asks for the company's payment methods; none configured here.
      if (uri.path.endsWith('/payment-methods')) return jsonResponse('{"methods":[]}');
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
    // The sheet scrolls; on the 600px test screen the button can sit below the fold.
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();
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

  testWidgets('with company payment methods configured, the client picks one and the request carries its id', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      if (uri.path.endsWith('/payment-methods')) {
        return jsonResponse('{"methods":[{"id":7,"kind":"wallet","label":"Vodafone Cash","details":{"phone":"01012345678"},"fee_percent":1}]}');
      }
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
    await tester.enterText(find.byKey(const ValueKey('payment-amount')), '1000');
    await tester.pumpAndSettle();

    // The old fixed chips are gone; sending without a pick is refused in the sheet.
    expect(find.byKey(const ValueKey('pay-method-bank_transfer')), findsNothing);
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();
    expect(sentBody, isNull);
    expect(find.text('Choose where you are transferring to.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('pay-method-id-7')));
    await tester.tap(find.byKey(const ValueKey('pay-method-id-7')));
    await tester.pumpAndSettle();
    expect(find.text('01012345678'), findsOneWidget);
    expect(find.text('1,010 SAR'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();

    expect(sentBody!['payment_method_id'], 7);
    expect(sentBody!.containsKey('method_type'), isFalse);
    expect(sentBody!['amount'], 1000.0);
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
    // The sheet scrolls; on the 600px test screen the button can sit below the fold.
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid amount'), findsOneWidget);
    verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
  });

  // payment-proof-upload-plan.md, Stage 4 (ح1): the real server error must
  // show up inside the still-open sheet, not a SnackBar the user might not
  // see behind it (م1/م2). Only the plain-amount path is testable here — the
  // proof-attached path needs the camera/gallery, which are real platform
  // channels with no mock under plain `flutter test` (see
  // client_onboarding_screen_test.dart for the same documented gap).
  testWidgets('requesting a payment that the server rejects shows its message inside the sheet and keeps it open', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse('{"payments":[],"available_methods":["bank_transfer"],"tax_summary":null}');
    });
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse(
        '{"message":"The given data was invalid.","errors":{"amount":["Amount exceeds the remaining contract value"]}}',
        422,
      ),
    );

    await pumpPage(tester, api);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '250');
    // The sheet scrolls; on the 600px test screen the button can sit below the fold.
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Amount exceeds the remaining contract value'), findsOneWidget);
    expect(find.text('Payment request sent'), findsNothing);
    // The sheet is still open (not popped), unlike the success path.
    expect(find.widgetWithText(ElevatedButton, 'Send Payment'), findsOneWidget);
  });

  testWidgets('paying a scheduled payment without attaching proof shows a validation message and does not call the API', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse(
        '{"payments":[{"id":9,"amount":300,"currency":"SAR","status":"scheduled","requested_by_manager":true,'
        '"installment_label":"Installment 2"}],"available_methods":["bank_transfer"],"tax_summary":null}',
      );
    });

    await pumpPage(tester, api);
    // Opens the scheduled-payment detail sheet, then its "Pay Now" action.
    await tester.tap(find.text('Installment 2').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Pay Now'));
    await tester.pumpAndSettle();
    // The sheet scrolls; on the 600px test screen the button can sit below the fold.
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Send Proof'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Proof'));
    await tester.pumpAndSettle();

    expect(find.text('Payment proof is required'), findsOneWidget);
    verifyNever(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body')));
  });

  testWidgets('requesting a payment with multiple payable contracts shows the contract dropdown and posts the selected contract_id', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) {
        return jsonResponse(
          '{"contracts":[{"id":1,"title":"MSA","status":"company_approved","value":5000,"currency":"SAR"},'
          '{"id":2,"title":"MSA II","status":"company_approved","value":9000,"currency":"SAR"}]}',
        );
      }
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

    expect(find.text('Select the contract you\'re paying for'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '250');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MSA (5000 SAR)').last);
    await tester.pumpAndSettle();
    // The sheet scrolls; on the 600px test screen the button can sit below the fold.
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();

    expect(sentBody!['contract_id'], 1);
    expect(sentBody!['amount'], 250.0);
    expect(find.text('Payment request sent'), findsOneWidget);
  });

  testWidgets('with a single payable contract the sheet posts no contract_id (backed by the latest-contract fallback)', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) {
        return jsonResponse(
          '{"contracts":[{"id":1,"title":"MSA","status":"company_approved","value":5000,"currency":"SAR"}]}',
        );
      }
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

    expect(find.text('Select the contract you\'re paying for'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '250');
    // The sheet scrolls; on the 600px test screen the button can sit below the fold.
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();

    expect(sentBody!.containsKey('contract_id'), isFalse);
    expect(find.text('Payment request sent'), findsOneWidget);
  });

  // plans/payment-currency-plan.md ح4 (م5 fix): switching the selected
  // contract in the multi-contract dropdown used to update the amount
  // field's currency prefix but leave the separate currency dropdown
  // (defaulted from the first payable contract) stale. Both are now driven
  // by the same selectedContract notifier via a shared currencyFor()
  // helper, so switching to an EGP contract must update the displayed
  // currency AND the currency actually submitted.
  testWidgets('switching the selected contract updates the displayed and submitted currency', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) {
        return jsonResponse(
          '{"contracts":[{"id":1,"title":"MSA","status":"company_approved","value":5000,"currency":"SAR"},'
          '{"id":2,"title":"MSA II","status":"company_approved","value":9000,"currency":"EGP"}]}',
        );
      }
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

    // Two payable contracts with different currencies: the sheet falls back
    // to the first contract's currency (SAR) until one is explicitly picked.
    expect(find.text('SAR'), findsWidgets);
    expect(find.text('EGP'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '250');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MSA II (9000 EGP)').last);
    await tester.pumpAndSettle();

    expect(find.text('EGP'), findsWidgets);
    expect(find.text('SAR'), findsNothing);

    // The sheet scrolls; on the 600px test screen the button can sit below the fold.
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Payment'));
    await tester.pumpAndSettle();

    expect(sentBody!['contract_id'], 2);
    expect(sentBody!['currency'], 'EGP');
    expect(find.text('Payment request sent'), findsOneWidget);
  });

  // payments-fixes-2-plan.md ت١ — a client taps a due payment from the chat,
  // then "Pay" — this used to work, but the sheet kept reopening on its own
  // every 30s afterward even after the client closed it, because
  // onTargetPaymentHandled never actually rebuilt the tree with
  // initialPaymentId: null (see client_dashboard_screen.dart) and _load()'s
  // own 30s refresh re-triggered the open every time it ran regardless.
  //
  // A ValueNotifier stands in for the real screen's own state var
  // (_targetPaymentId) — it's what onTargetPaymentHandled clears, and
  // wrapping PaymentsPage in a ValueListenableBuilder means that clear
  // actually reaches PaymentsPage as a new initialPaymentId: null the way a
  // real setState in the parent would, instead of silently doing nothing.
  Future<void> pumpTargetPayment(WidgetTester tester, dynamic api, ValueNotifier<int?> idNotifier) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ValueListenableBuilder<int?>(
        valueListenable: idNotifier,
        builder: (context, id, _) => PaymentsPage(
          api: api,
          paymentProvider: PaymentProvider(repository: PaymentRepository(api: api)),
          contractProvider: ContractProvider(api: api),
          initialPaymentId: id,
          onTargetPaymentHandled: () => idNotifier.value = null,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the scheduled-payment sheet for a payment set after the initial load', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse(
        '{"payments":[{"id":7,"amount":300,"currency":"SAR","status":"scheduled","requested_by_manager":true,'
        '"installment_label":"Installment 2"}],"available_methods":["bank_transfer"],"tax_summary":null}',
      );
    });

    final idNotifier = ValueNotifier<int?>(null);
    await pumpTargetPayment(tester, api, idNotifier);
    expect(find.text('Send Proof'), findsNothing);

    idNotifier.value = 7;
    await tester.pumpAndSettle();

    expect(find.text('Send Proof'), findsOneWidget);
  });

  testWidgets('does not reopen the sheet on the next 30s refresh after it was closed', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse(
        '{"payments":[{"id":7,"amount":300,"currency":"SAR","status":"scheduled","requested_by_manager":true,'
        '"installment_label":"Installment 2"}],"available_methods":["bank_transfer"],"tax_summary":null}',
      );
    });

    final idNotifier = ValueNotifier<int?>(7);
    await pumpTargetPayment(tester, api, idNotifier);
    expect(find.text('Send Proof'), findsOneWidget);
    // onTargetPaymentHandled fires as soon as the sheet is triggered to open
    // (not on user action inside it), so the id is already cleared here —
    // matching "closes it, meaning to pay later" from the plan's manual QA
    // table just as much as "actually pays".
    expect(idNotifier.value, isNull);

    // Close the sheet without paying.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Send Proof'), findsNothing);

    // The periodic refresh fires again; with the id already null this must
    // not reopen the sheet. This is the exact scenario the bug report
    // describes and must fail against the old code (which re-triggered the
    // open from inside _load() on every refresh regardless of the id having
    // "already been handled").
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text('Send Proof'), findsNothing);
  });

  testWidgets('clears the target id without crashing when the payment is not in the list', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse('{"payments":[],"available_methods":["bank_transfer"],"tax_summary":null}');
    });

    final idNotifier = ValueNotifier<int?>(99);
    await pumpTargetPayment(tester, api, idNotifier);

    expect(find.text('Send Proof'), findsNothing);
    expect(idNotifier.value, isNull);
  });

  // subuser-review-plan.md م٦ — uploading/re-uploading a payment proof maps
  // to can_upload_payment_proof.
  group('sub-user action gating (م٦)', () {
    testWidgets('hides the request-payment FAB when can_upload_payment_proof is missing', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      api.role = 'sub_user';
      api.subUserPermissions = {};
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
        final uri = inv.positionalArguments[0] as Uri;
        if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
        return jsonResponse('{"payments":[],"available_methods":["bank_transfer"],"tax_summary":null}');
      });

      await pumpPage(tester, api);

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('shows the request-payment FAB when can_upload_payment_proof is granted', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      api.role = 'sub_user';
      api.subUserPermissions = {'can_upload_payment_proof': true};
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
        final uri = inv.positionalArguments[0] as Uri;
        if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
        return jsonResponse('{"payments":[],"available_methods":["bank_transfer"],"tax_summary":null}');
      });

      await pumpPage(tester, api);

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('hides the re-upload button on a rejected payment when can_upload_payment_proof is missing', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      api.role = 'sub_user';
      api.subUserPermissions = {};
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
        final uri = inv.positionalArguments[0] as Uri;
        if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
        return jsonResponse(
          '{"payments":[{"id":1,"amount":500,"currency":"SAR","status":"rejected","method_type":"bank_transfer","created_at":"2026-01-01T00:00:00Z"}],'
          '"available_methods":["bank_transfer"],"tax_summary":null}',
        );
      });

      await pumpPage(tester, api);

      expect(find.text('Re-upload Payment Proof'), findsNothing);
    });

    testWidgets('hides the Pay Now button on a scheduled payment when can_upload_payment_proof is missing', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      api.role = 'sub_user';
      api.subUserPermissions = {};
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
        final uri = inv.positionalArguments[0] as Uri;
        if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
        return jsonResponse(
          '{"payments":[{"id":9,"amount":300,"currency":"SAR","status":"scheduled","requested_by_manager":true,'
          '"installment_label":"Installment 2"}],"available_methods":["bank_transfer"],"tax_summary":null}',
        );
      });

      await pumpPage(tester, api);
      await tester.tap(find.text('Installment 2').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Pay Now'), findsNothing);
    });
  });
}
