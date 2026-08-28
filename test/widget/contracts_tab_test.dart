// Characterization test for am/workspace/contracts_tab.dart, written
// immediately after migrating its four domains (load, generic action,
// delete, company-approve-with-signature) onto ContractProvider, which
// needed four new pass-through methods added in this same change
// (performAction/deleteContract/fetchCurrentUser/companyApprove) — each a
// 1:1 wrap of a ContractRepository method that already existed. Per the
// migration's core rule, nothing is committed until this and the full suite
// are green (see docs/state-layer-migration-plan.md, Path B).
//
// Not covered here (pre-existing testability/scope gaps, not introduced by
// this migration): the destructive-action confirm path (archive/complete) —
// it's the same _action()/performAction() codepath already exercised by the
// "send" test below, just gated by an extra confirm dialog; and the
// "use my saved signature" branch of company-approve — logically identical
// to the manual-signature path tested here, just skips one dialog when
// /auth/me returns a non-empty signature_data.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/am/workspace/contracts_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  void stubCommon(MockHttpClient httpClient, {
    required String contractsJson,
    String workspaceJson = '{"workspace":{"status":"active","client":{"client_type":"individual"}}}',
    String meJson = '{"user":{}}',
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/workspaces/5/contracts') return jsonResponse(contractsJson);
      if (path == '/workspaces/5') return jsonResponse(workspaceJson);
      if (path == '/auth/me') return jsonResponse(meJson);
      return jsonResponse('{}');
    });
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));
    when(() => httpClient.delete(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{}'));
  }

  Future<void> pumpTab(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ContractsTab(workspaceId: 5, api: api)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads contracts alongside the workspace status', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    stubCommon(httpClient, contractsJson: '{"contracts":[{"id":1,"title":"Renovation Deal","status":"draft","value":500,"currency":"SAR"}]}');

    await pumpTab(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')), headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/workspaces/5')), headers: any(named: 'headers'))).called(1);
    expect(find.text('Renovation Deal'), findsOneWidget);
  });

  testWidgets('sending a draft contract posts the send action', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    stubCommon(httpClient, contractsJson: '{"contracts":[{"id":1,"title":"Renovation Deal","status":"draft","value":500,"currency":"SAR"}]}');

    await pumpTab(tester, api);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    verify(() => httpClient.post(
          any(that: predicate<Uri>((u) => u.path == '/contracts/1/send')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });

  testWidgets('deleting a draft contract via the popup menu calls the delete endpoint', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    stubCommon(httpClient, contractsJson: '{"contracts":[{"id":1,"title":"Renovation Deal","status":"draft","value":500,"currency":"SAR"}]}');

    await pumpTab(tester, api);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path == '/contracts/1')), headers: any(named: 'headers'))).called(1);
  });

  testWidgets('company-approving with a manually entered signature posts it', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(
      httpClient,
      contractsJson: '{"contracts":[{"id":1,"title":"Renovation Deal","status":"client_approved","value":500,"currency":"SAR"}]}',
      meJson: '{"user":{}}',
    );

    await pumpTab(tester, api);

    await tester.tap(find.text('Company Approve'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Jane Doe');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
    await tester.pumpAndSettle();

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/auth/me')), headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.post(
          any(that: predicate<Uri>((u) => u.path == '/contracts/1/company-approve')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });
}
