// Ads contracts: the agency's management fee is a share of the contract value
// (inside it, never on top). The server sends the split already computed; the
// app shows it and lets the manager switch a contract to an ads contract.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/widgets/ads_split.dart';
import 'package:shadapp_client/features/am/widgets/contract_builder.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  const adsContract = {
    'id': 702,
    'title': 'ad cc',
    'value': '10000',
    'currency': 'SAR',
    'ads_percentage': 10,
    'ads_amount': 1000,
    'ads_budget': 9000,
  };
  const normalContract = {
    'id': 701,
    'title': 'Plain',
    'value': '10000',
    'currency': 'SAR',
    'ads_percentage': null,
    'ads_amount': null,
    'ads_budget': null,
  };

  Widget wrap(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  group('AdsSplit', () {
    test('knows an ads contract from a normal one', () {
      expect(contractHasAds(adsContract), isTrue);
      expect(contractHasAds(normalContract), isFalse);
      expect(contractHasAds(null), isFalse);
    });

    testWidgets('shows the fee and the budget in English', (tester) async {
      await tester.pumpWidget(wrap(const AdsSplit(contract: adsContract, currency: 'SAR')));

      expect(find.text('Ads management fee (10%)'), findsOneWidget);
      expect(find.text('Ad budget'), findsOneWidget);
      expect(find.textContaining('1,000'), findsOneWidget);
      expect(find.textContaining('9,000'), findsOneWidget);
    });

    testWidgets('shows the same lines in Arabic', (tester) async {
      await tester.pumpWidget(wrap(const AdsSplit(contract: adsContract, currency: 'SAR'), locale: const Locale('ar')));

      expect(find.textContaining('نسبة إدارة الإعلانات'), findsOneWidget);
      expect(find.text('ميزانية الإعلانات'), findsOneWidget);
    });

    testWidgets('draws nothing for a normal contract', (tester) async {
      await tester.pumpWidget(wrap(const AdsSplit(contract: normalContract, currency: 'SAR')));

      expect(find.byKey(const ValueKey('ads-split')), findsNothing);
    });
  });

  group('ContractBuilder with the ads switch', () {
    void stubTemplates(MockHttpClient httpClient) {
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
        final path = (inv.positionalArguments[0] as Uri).path;
        if (path == '/contract-clause-templates') return jsonResponse('{"templates":[]}');
        return jsonResponse('{}');
      });
    }

    Future<void> pumpBuilder(WidgetTester tester, dynamic api, {int? contractId, Map<String, dynamic>? contractData}) async {
      await tester.pumpWidget(wrap(ContractBuilder(api: api, contractId: contractId, contractData: contractData)));
      await tester.pumpAndSettle();
    }

    testWidgets('the percentage field appears only after the switch is ticked', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      stubTemplates(httpClient);

      await pumpBuilder(tester, api);

      expect(find.byKey(const ValueKey('cb-ads-percent')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('cb-ads-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cb-ads-percent')), findsOneWidget);
    });

    testWidgets('an ads contract is created with its percentage', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      stubTemplates(httpClient);
      when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{"contract":{"id":7}}'));
      when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path == '/contracts/7/send')),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{}'));

      await pumpBuilder(tester, api);

      await tester.enterText(find.byType(TextField).at(0), 'ad cc');
      await tester.enterText(find.byType(TextField).at(1), '10000');
      await tester.tap(find.byKey(const ValueKey('cb-ads-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cb-ads-percent')), '10');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create and Send'));
      await tester.pumpAndSettle();

      final captured = verify(() => httpClient.post(
            any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured;
      final body = jsonDecode(captured.single as String) as Map<String, dynamic>;
      expect(body['ads_percentage'], 10);
    });

    testWidgets('a normal contract sends no percentage', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      stubTemplates(httpClient);
      when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{"contract":{"id":7}}'));
      when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path == '/contracts/7/send')),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{}'));

      await pumpBuilder(tester, api);

      await tester.enterText(find.byType(TextField).at(0), 'Plain');
      await tester.enterText(find.byType(TextField).at(1), '2500');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create and Send'));
      await tester.pumpAndSettle();

      final captured = verify(() => httpClient.post(
            any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured;
      final body = jsonDecode(captured.single as String) as Map<String, dynamic>;
      expect(body.containsKey('ads_percentage'), isFalse);
    });

    testWidgets('an ads contract without a valid percentage is not sent and says why', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      stubTemplates(httpClient);

      await pumpBuilder(tester, api);

      await tester.enterText(find.byType(TextField).at(0), 'ad cc');
      await tester.enterText(find.byType(TextField).at(1), '10000');
      await tester.tap(find.byKey(const ValueKey('cb-ads-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cb-ads-percent')), '101');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create and Send'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a percentage between 0.01 and 100.'), findsWidgets);
      verifyNever(() => httpClient.post(
            any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ));
    });

    testWidgets('editing an ads contract shows its percentage and can turn it off', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.workspaceId = 5;
      stubTemplates(httpClient);
      when(() => httpClient.put(any(that: predicate<Uri>((u) => u.path == '/contracts/3')),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{}'));

      await pumpBuilder(tester, api, contractId: 3, contractData: {
        'title': 'ad cc',
        'value': 10000,
        'currency': 'SAR',
        'ads_percentage': 10,
        'clauses': [],
        'required_documents': [],
      });

      final field = tester.widget<TextField>(find.byKey(const ValueKey('cb-ads-percent')));
      expect(field.controller!.text, '10');

      await tester.tap(find.byKey(const ValueKey('cb-ads-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      final captured = verify(() => httpClient.put(
            any(that: predicate<Uri>((u) => u.path == '/contracts/3')),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured;
      final body = jsonDecode(captured.single as String) as Map<String, dynamic>;
      expect(body.containsKey('ads_percentage'), isTrue);
      expect(body['ads_percentage'], isNull);
    });
  });
}
