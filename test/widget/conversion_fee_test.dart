// Ads contracts can carry a dollar-conversion fee: a share of the ad budget,
// added on top of the contract value and never taxed. Any contract can also be
// taken out of tax with a switch.
//
// Reference: value 100,000, company fee 10% (10,000), ad budget 90,000,
// conversion 5% of the budget (4,500), tax 14% on the fee only (1,400):
// total due 105,900, or 104,500 with the tax switched off.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/widgets/ads_split.dart';
import 'package:shadapp_client/features/am/widgets/contract_builder.dart';
import 'package:shadapp_client/features/onboarding/client_onboarding_stages.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/pump_app.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  const withConversion = {
    'id': 710,
    'title': 'conv cc',
    'status': 'company_approved',
    'value': '100000',
    'currency': 'SAR',
    'ads_percentage': 10,
    'ads_amount': 10000,
    'ads_budget': 90000,
    'conversion_percentage': 5,
    'conversion_amount': 4500,
  };
  const adsOnly = {
    'id': 711,
    'title': 'ads only',
    'status': 'company_approved',
    'value': '100000',
    'currency': 'SAR',
    'ads_percentage': 10,
    'ads_amount': 10000,
    'ads_budget': 90000,
    'conversion_percentage': null,
    'conversion_amount': null,
  };

  Widget wrap(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('AdsSplit with a conversion fee', () {
    test('knows a contract that carries a conversion fee', () {
      expect(contractHasConversion(withConversion), isTrue);
      expect(contractHasConversion(adsOnly), isFalse);
      expect(contractHasConversion({...withConversion, 'conversion_amount': 0}), isFalse);
      expect(contractHasConversion(null), isFalse);
    });

    testWidgets('shows the fee and says the value excludes it, in English', (tester) async {
      await tester.pumpWidget(wrap(const AdsSplit(contract: withConversion, currency: 'SAR')));

      expect(find.byKey(const ValueKey('ads-conversion')), findsOneWidget);
      expect(find.text('Dollar conversion fee (5%)'), findsOneWidget);
      expect(find.textContaining('4,500'), findsOneWidget);
      expect(find.text('Contract value excludes the conversion fee'), findsOneWidget);
    });

    testWidgets('shows the same in Arabic', (tester) async {
      await tester.pumpWidget(wrap(const AdsSplit(contract: withConversion, currency: 'SAR'), locale: const Locale('ar')));

      expect(find.textContaining('رسوم التحويل الدولاري'), findsOneWidget);
      expect(find.text('قيمة العقد غير شاملة رسوم التحويل'), findsOneWidget);
    });

    testWidgets('an ads contract without a conversion fee shows no conversion line', (tester) async {
      await tester.pumpWidget(wrap(const AdsSplit(contract: adsOnly, currency: 'SAR')));

      expect(find.byKey(const ValueKey('ads-split')), findsOneWidget);
      expect(find.byKey(const ValueKey('ads-conversion')), findsNothing);
      expect(find.text('Contract value excludes the conversion fee'), findsNothing);
    });
  });

  group('onboarding payment stage adds the conversion fee', () {
    // An amount as its own bill row shows it.
    Finder amount(String figure) => find.byWidgetPredicate(
          (w) => w is Text && (w.textSpan?.toPlainText() ?? w.data ?? '').startsWith('$figure '),
        );

    Future<void> pumpStage(WidgetTester tester, Map<String, dynamic> contract) async {
      await pumpWithLocalizations(
        tester,
        SingleChildScrollView(
          child: Builder(
            builder: (ctx) => buildPaymentStage(
              context: ctx,
              workspace: {'id': 5, 'contracts': [contract], 'payments': []},
              client: {'client_type': 'business'},
              taxSettings: {'corporate_tax_percentage': {'value': '14'}},
            ),
          ),
        ),
      );
    }

    testWidgets('uses the figures the server computed', (tester) async {
      await pumpStage(tester, {...withConversion, 'tax_percentage': 14, 'tax_amount': 1400});

      expect(amount('4,500'), findsOneWidget); // conversion row
      expect(amount('1,400'), findsOneWidget); // tax row
      expect(amount('105,900'), findsNWidgets(2)); // total due and remaining
      expect(find.text('Total due'), findsOneWidget);
    });

    testWidgets('computes the same figure itself when the server sent none', (tester) async {
      await pumpStage(tester, Map<String, dynamic>.from(withConversion));

      expect(amount('1,400'), findsOneWidget);
      expect(amount('105,900'), findsNWidgets(2));
    });

    testWidgets('a contract excluded from tax pays no tax but still pays the conversion fee', (tester) async {
      await pumpStage(tester, {...withConversion, 'tax_excluded': true});

      expect(amount('1,400'), findsNothing);
      expect(amount('104,500'), findsNWidgets(2));
    });

    testWidgets('a normal contract is unchanged', (tester) async {
      await pumpStage(tester, {'id': 8, 'status': 'company_approved', 'value': '50000', 'currency': 'EGP'});

      expect(amount('7,000'), findsOneWidget);
      expect(amount('57,000'), findsNWidgets(2));
      expect(find.text('Total due'), findsNothing);
    });
  });

  group('ContractBuilder with the conversion fee and tax switch', () {
    void stubTemplates(MockHttpClient httpClient) {
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
        final path = (inv.positionalArguments[0] as Uri).path;
        if (path == '/contract-clause-templates') return jsonResponse('{"templates":[]}');
        return jsonResponse('{}');
      });
    }

    void stubCreate(MockHttpClient httpClient) {
      when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{"contract":{"id":7}}'));
      when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path == '/contracts/7/send')),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{}'));
    }

    Future<void> pumpBuilder(WidgetTester tester, dynamic api, {int? contractId, Map<String, dynamic>? contractData}) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ContractBuilder(api: api, contractId: contractId, contractData: contractData)),
      ));
      await tester.pumpAndSettle();
    }

    Future<Map<String, dynamic>> sentBody(MockHttpClient httpClient, String path) async {
      final captured = verify(() => httpClient.post(
            any(that: predicate<Uri>((u) => u.path == path)),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured;
      return jsonDecode(captured.single as String) as Map<String, dynamic>;
    }

    testWidgets('the conversion field appears only for an ads contract', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      stubTemplates(httpClient);

      await pumpBuilder(tester, api);

      expect(find.byKey(const ValueKey('cb-conversion-percent')), findsNothing);
      expect(find.byKey(const ValueKey('cb-tax-excluded-toggle')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cb-ads-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cb-conversion-percent')), findsOneWidget);
    });

    testWidgets('creates an ads contract with its conversion fee and no tax', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      stubTemplates(httpClient);
      stubCreate(httpClient);

      await pumpBuilder(tester, api);

      await tester.enterText(find.byType(TextField).at(0), 'conv cc');
      await tester.enterText(find.byType(TextField).at(1), '100000');
      await tester.tap(find.byKey(const ValueKey('cb-ads-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cb-ads-percent')), '10');
      await tester.enterText(find.byKey(const ValueKey('cb-conversion-percent')), '5');
      await tester.ensureVisible(find.byKey(const ValueKey('cb-tax-excluded-toggle')));
      await tester.tap(find.byKey(const ValueKey('cb-tax-excluded-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create and Send'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create and Send'));
      await tester.pumpAndSettle();

      final body = await sentBody(httpClient, '/workspaces/5/contracts');
      expect(body['ads_percentage'], 10);
      expect(body['conversion_percentage'], 5);
      expect(body['tax_excluded'], true);
    });

    testWidgets('a normal contract sends neither option', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      stubTemplates(httpClient);
      stubCreate(httpClient);

      await pumpBuilder(tester, api);

      await tester.enterText(find.byType(TextField).at(0), 'Plain');
      await tester.enterText(find.byType(TextField).at(1), '2500');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create and Send'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create and Send'));
      await tester.pumpAndSettle();

      final body = await sentBody(httpClient, '/workspaces/5/contracts');
      expect(body.containsKey('conversion_percentage'), isFalse);
      expect(body.containsKey('tax_excluded'), isFalse);
    });

    testWidgets('a conversion percentage above 100 is not sent and says why', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      stubTemplates(httpClient);

      await pumpBuilder(tester, api);

      await tester.enterText(find.byType(TextField).at(0), 'conv cc');
      await tester.enterText(find.byType(TextField).at(1), '100000');
      await tester.tap(find.byKey(const ValueKey('cb-ads-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cb-ads-percent')), '10');
      await tester.enterText(find.byKey(const ValueKey('cb-conversion-percent')), '150');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create and Send'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create and Send'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a percentage between 0 and 100.'), findsWidgets);
      verifyNever(() => httpClient.post(
            any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ));
    });

    testWidgets('editing shows both options and clears the fee when ads is turned off', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      stubTemplates(httpClient);
      when(() => httpClient.put(any(that: predicate<Uri>((u) => u.path == '/contracts/3')),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{}'));

      await pumpBuilder(tester, api, contractId: 3, contractData: {
        'title': 'conv cc',
        'value': 100000,
        'currency': 'SAR',
        'ads_percentage': 10,
        'conversion_percentage': 5,
        'tax_excluded': true,
        'clauses': [],
        'required_documents': [],
      });

      expect(find.byKey(const ValueKey('cb-conversion-percent')), findsOneWidget);
      final field = tester.widget<TextField>(find.byKey(const ValueKey('cb-conversion-percent')));
      expect(field.controller!.text, '5');

      await tester.tap(find.byKey(const ValueKey('cb-ads-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      final captured = verify(() => httpClient.put(
            any(that: predicate<Uri>((u) => u.path == '/contracts/3')),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured;
      final body = jsonDecode(captured.single as String) as Map<String, dynamic>;
      expect(body['ads_percentage'], isNull);
      expect(body['conversion_percentage'], isNull);
      expect(body['tax_excluded'], true);
    });
  });
}
