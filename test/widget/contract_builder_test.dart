// Characterization test for am/widgets/contract_builder.dart, written
// immediately after migrating its four domains (load clause templates,
// create, send, update) onto ContractProvider — which needed four new
// pass-through methods added in this same change
// (fetchClauseTemplates/create/update/send), each a 1:1 wrap of a
// ContractRepository method that already existed. Per the migration's core
// rule, nothing is committed until this and the full suite are green (see
// docs/state-layer-migration-plan.md, Path B — this is the fourth and last
// Contracts screen).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/am/widgets/contract_builder.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  void stubTemplates(MockHttpClient httpClient, {
    String templatesJson = '{"templates":[{"content":"Fixed Clause One","type":"fixed"},{"content":"Optional Clause One","type":"optional"}]}',
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/contract-clause-templates') return jsonResponse(templatesJson);
      return jsonResponse('{}');
    });
  }

  Future<void> pumpBuilder(WidgetTester tester, dynamic api, {int? contractId, Map<String, dynamic>? contractData}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ContractBuilder(api: api, contractId: contractId, contractData: contractData)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads clause templates and renders the fixed clause', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    stubTemplates(httpClient);

    await pumpBuilder(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/contract-clause-templates')), headers: any(named: 'headers'))).called(1);
    expect(find.text('Fixed Clause One'), findsOneWidget);
  });

  // Stubs both endpoints the builder loads on open: the clause templates and
  // the system settings that drive `show_contract_dates`.
  void stubTemplatesAndSettings(MockHttpClient httpClient, {required String showDatesValue}) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/contract-clause-templates') {
        return jsonResponse('{"templates":[{"content":"Fixed Clause One","type":"fixed"}]}');
      }
      if (path == '/settings') {
        return jsonResponse('{"settings":{"show_contract_dates":{"value":"$showDatesValue"}}}');
      }
      return jsonResponse('{}');
    });
  }

  testWidgets('shows the contract date fields when show_contract_dates is on', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    stubTemplatesAndSettings(httpClient, showDatesValue: '1');

    await pumpBuilder(tester, api);

    expect(find.text('Select Date'), findsWidgets);
  });

  testWidgets('hides the contract date fields when show_contract_dates is off', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    stubTemplatesAndSettings(httpClient, showDatesValue: '0');

    await pumpBuilder(tester, api);

    // The rest of the form still renders — only the date row is gone.
    expect(find.text('Fixed Clause One'), findsOneWidget);
    expect(find.text('Select Date'), findsNothing);
  });

  testWidgets('a failing /settings leaves the form usable with dates shown', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/contract-clause-templates') {
        return jsonResponse('{"templates":[{"content":"Fixed Clause One","type":"fixed"}]}');
      }
      if (path == '/settings') return jsonResponse('{"message":"boom"}', 500);
      return jsonResponse('{}');
    });

    await pumpBuilder(tester, api);

    // Non-fatal by design: the settings read is wrapped so the builder still
    // opens on the default rather than failing to load at all.
    expect(find.text('Fixed Clause One'), findsOneWidget);
    expect(find.text('Select Date'), findsWidgets);
  });

  testWidgets('creating a new contract posts create then send', (tester) async {
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

    await tester.enterText(find.byType(TextField).at(0), 'Villa Renovation');
    await tester.enterText(find.byType(TextField).at(1), '2500');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create and Send'));
    await tester.pumpAndSettle();

    verify(() => httpClient.post(
          any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
    verify(() => httpClient.post(
          any(that: predicate<Uri>((u) => u.path == '/contracts/7/send')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });

  testWidgets('editing an existing contract puts the update', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    stubTemplates(httpClient);
    when(() => httpClient.put(any(that: predicate<Uri>((u) => u.path == '/contracts/3')),
        headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));

    await pumpBuilder(tester, api, contractId: 3, contractData: {
      'title': 'Existing Deal',
      'value': 1000,
      'currency': 'SAR',
      'clauses': [],
      'required_documents': [],
    });

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
    await tester.pumpAndSettle();

    verify(() => httpClient.put(
          any(that: predicate<Uri>((u) => u.path == '/contracts/3')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });
}
