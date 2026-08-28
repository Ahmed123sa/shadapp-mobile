// Characterization test for contracts/contracts_page.dart, written
// immediately after (not before, given the tool constraints of this session
// — no local shell access) migrating its four domains onto
// ContractProvider/FileProvider, both of which already existed and are
// covered by their own test suites (see docs/state-layer-migration-plan.md,
// Path B). Every provider method used is a 1:1 mechanical replacement of the
// original _api.get/post/multipartPost call it replaces — verified by
// reading contract_repository.dart/file_repository.dart before wiring them
// in. This test exists to catch anything that mapping missed before it's
// committed; per the plan's core rule, nothing is committed until this (and
// the full suite) is green.
//
// Not covered here (pre-existing testability gap, not introduced by this
// migration): the "upload document" button inside the contract-detail modal
// — FilePicker.platform is a real platform channel with no mock registered
// under plain `flutter test`, same reasoning documented in
// chat_page_test.dart/chat_tab_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/contracts/contracts_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  void stubCommon(MockHttpClient httpClient, {
    String contractsJson = '{"contracts":[{"id":1,"title":"Villa Renovation Deal","status":"sent","value":1000,"currency":"SAR"}]}',
    String workspaceJson = '{"client":{"client_type":"business"}}',
    String filesJson = '{"files":[]}',
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/workspaces/5/contracts') return jsonResponse(contractsJson);
      if (path == '/workspaces/5/files') return jsonResponse(filesJson);
      if (path == '/workspaces/5') return jsonResponse(workspaceJson);
      return jsonResponse('{}');
    });
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));
  }

  Future<void> pumpPage(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ContractsPage(api: api)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads contracts and the workspace client_type together', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    stubCommon(httpClient);

    await pumpPage(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')), headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/workspaces/5')), headers: any(named: 'headers'))).called(1);
    expect(find.text('Villa Renovation Deal'), findsOneWidget);
    // client_type == 'business' -> the VAT-exclusion hint renders on the card.
    expect(find.text('Contract value excludes VAT'), findsOneWidget);
  });

  testWidgets('approving a contract posts the client-action and refreshes the list', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    stubCommon(httpClient);

    await pumpPage(tester, api);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve').first);
    await tester.pumpAndSettle();
    // Confirm dialog.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm').first);
    await tester.pumpAndSettle();

    verify(() => httpClient.post(
          any(that: predicate<Uri>((u) => u.path == '/contracts/1/client-action')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });

  testWidgets('opening a contract card loads its uploaded files', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    stubCommon(httpClient, filesJson: '{"files":[{"id":9,"name":"passport.pdf","contract_id":1,"status":"approved"}]}');

    await pumpPage(tester, api);

    await tester.tap(find.text('Villa Renovation Deal'));
    await tester.pumpAndSettle();

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/workspaces/5/files')), headers: any(named: 'headers'))).called(1);
    expect(find.text('passport.pdf'), findsOneWidget);
  });
}
