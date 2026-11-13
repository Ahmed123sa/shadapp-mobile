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
import 'package:shadapp_client/core/widgets/luxe/luxe_widgets.dart';
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

  testWidgets('deleting a draft contract via its Delete button calls the delete endpoint', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    stubCommon(httpClient, contractsJson: '{"contracts":[{"id":1,"title":"Renovation Deal","status":"draft","value":500,"currency":"SAR"}]}');

    await pumpTab(tester, api);

    // Mockup cards have no ⋮ menu: a draft shows its own Delete button.
    await tester.tap(find.byKey(const ValueKey('contract-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path == '/contracts/1')), headers: any(named: 'headers'))).called(1);
  });

  // Delete is offered only for a contract that was saved and never sent.
  group('delete is for drafts only', () {
    testWidgets('a contract the client has seen shows no Delete button, in any status', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.role = 'account_manager';
      stubCommon(httpClient, contractsJson: '{"contracts":['
          '{"id":1,"title":"Asked","status":"edit_requested","value":500,"currency":"SAR"},'
          '{"id":2,"title":"Sent","status":"sent","value":500,"currency":"SAR"},'
          '{"id":3,"title":"Approved","status":"company_approved","value":500,"currency":"SAR"},'
          '{"id":4,"title":"Draft","status":"draft","value":500,"currency":"SAR"}]}');
      // Tall enough that all four cards are built, not only the first ones.
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpTab(tester, api);

      expect(find.byKey(const ValueKey('contract-delete-1')), findsNothing);
      expect(find.byKey(const ValueKey('contract-delete-2')), findsNothing);
      expect(find.byKey(const ValueKey('contract-delete-3')), findsNothing);
      expect(find.byKey(const ValueKey('contract-delete-4')), findsOneWidget);
    });

    testWidgets('cancelling the confirmation deletes nothing', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.role = 'account_manager';
      stubCommon(httpClient, contractsJson: '{"contracts":[{"id":1,"title":"Draft","status":"draft","value":500,"currency":"SAR"}]}');

      await pumpTab(tester, api);

      await tester.tap(find.byKey(const ValueKey('contract-delete-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => httpClient.delete(any(), headers: any(named: 'headers')));
    });

    testWidgets('when the server refuses, its reason is shown', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.role = 'account_manager';
      stubCommon(httpClient, contractsJson: '{"contracts":[{"id":1,"title":"Draft","status":"draft","value":500,"currency":"SAR"}]}');
      when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
          (_) async => jsonResponse('{"message":"Already sent, cannot delete.","code":"contract_not_deletable"}', 422));

      await pumpTab(tester, api);

      await tester.tap(find.byKey(const ValueKey('contract-delete-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Already sent, cannot delete.'), findsOneWidget);
    });

    testWidgets('a super admin sees no Delete button on a draft', (tester) async {
      final httpClient = MockHttpClient();
      final api = buildTestApiClient(client: httpClient);
      api.role = 'super_admin';
      stubCommon(httpClient, contractsJson: '{"contracts":[{"id":1,"title":"Draft","status":"draft","value":500,"currency":"SAR"}]}');

      await pumpTab(tester, api);

      expect(find.byKey(const ValueKey('contract-delete-1')), findsNothing);
    });
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

  // The company can approve only once every required document is accepted:
  // the card lists them, the button is off and a shortcut leads to the Files tab.
  testWidgets('company approval is locked while a required document is not accepted, with a way to the Files tab', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(
      httpClient,
      contractsJson: '{"contracts":[{"id":1,"title":"Renovation Deal","status":"client_approved","value":500,"currency":"SAR",'
          '"required_documents":[{"id":10,"name":"Commercial Register","is_required":true,"files":[{"id":5,"status":"pending"}]},'
          '{"id":11,"name":"National ID","is_required":true,"files":[{"id":6,"status":"rejected"}]}]}]}',
    );
    var wentToFiles = 0;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ContractsTab(workspaceId: 5, api: api, onGoToFiles: () => wentToFiles++)),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('contract-docs-1')), findsOneWidget);
    expect(find.text('Commercial Register'), findsOneWidget);
    expect(find.text('Under review'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(tester.widget<LuxeButton>(find.widgetWithText(LuxeButton, 'Company Approve')).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('contract-docs-review-1')));
    expect(wentToFiles, 1);
  });

  testWidgets('company approval is open once every required document is accepted', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(
      httpClient,
      contractsJson: '{"contracts":[{"id":1,"title":"Renovation Deal","status":"client_approved","value":500,"currency":"SAR",'
          '"required_documents":[{"id":10,"name":"Commercial Register","is_required":true,"files":[{"id":5,"status":"approved"}]}]}]}',
    );

    await pumpTab(tester, api);

    expect(tester.widget<LuxeButton>(find.widgetWithText(LuxeButton, 'Company Approve')).onPressed, isNotNull);
    expect(find.byKey(const ValueKey('contract-docs-review-1')), findsNothing);
  });

  const clientApproved =
      '{"contracts":[{"id":1,"title":"Renovation Deal","status":"client_approved","value":500,"currency":"SAR"}]}';

  testWidgets('a manager without the approval permission gets no Company Approve button', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    stubCommon(httpClient, contractsJson: clientApproved);

    await pumpTab(tester, api);

    expect(find.text('Renovation Deal'), findsOneWidget);
    expect(find.text('Company Approve'), findsNothing);
  });

  testWidgets('a manager the super admin granted the permission to can company-approve', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.canApproveContracts = true;
    stubCommon(httpClient, contractsJson: clientApproved);

    await pumpTab(tester, api);

    await tester.tap(find.text('Company Approve'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Jane Doe');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
    await tester.pumpAndSettle();

    verify(() => httpClient.post(
          any(that: predicate<Uri>((u) => u.path == '/contracts/1/company-approve')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });
}
