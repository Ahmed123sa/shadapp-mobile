// Characterization test for contracts/contract_detail_modal.dart, written
// immediately after migrating its four domains onto
// ContractProvider/FileProvider — every provider method used already
// existed (same infrastructure contracts_page.dart's embedded modal uses).
// This standalone widget has exactly one production call site
// (onboarding/client_onboarding_screen.dart, itself still unseamed/deferred
// — task #153), so it's pumped directly here rather than through that
// screen; the seam is purely additive (defaults to the real ApiClient
// singleton), so the deferred screen's behavior is unaffected.
//
// Not covered here (pre-existing testability gap, not introduced by this
// migration): the "upload document" button — FilePicker.platform is a real
// platform channel with no mock registered under plain `flutter test`, same
// reasoning documented in chat_page_test.dart/contracts_page_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/contracts/contract_detail_modal.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  void stubCommon(MockHttpClient httpClient, {
    String contractsJson = '{"contracts":[{"id":1,"title":"Villa Deal","status":"sent","clauses":[{"content":"Clause A"}]}]}',
    String filesJson = '{"files":[]}',
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/workspaces/5/contracts') return jsonResponse(contractsJson);
      if (path == '/workspaces/5/files') return jsonResponse(filesJson);
      return jsonResponse('{}');
    });
    when(() => httpClient.delete(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{}'));
  }

  Future<void> pumpModal(WidgetTester tester, dynamic api, {Map<String, dynamic>? contract}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ContractDetailModal(
          contract: contract ?? {'id': 1, 'title': 'Villa Deal', 'status': 'sent'},
          onAction: (_, __) async {},
          onRefresh: () {},
          workspaceId: 5,
          api: api,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('merges in the full contract (clauses) when the passed-in contract lacks them', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    stubCommon(httpClient);

    await pumpModal(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/workspaces/5/contracts')), headers: any(named: 'headers'))).called(1);
    expect(find.text('Clause A'), findsOneWidget);
  });

  testWidgets('loads uploaded files for this contract', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    stubCommon(httpClient, filesJson: '{"files":[{"id":9,"name":"deed.pdf","contract_id":1,"status":"pending"}]}');

    await pumpModal(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/workspaces/5/files')), headers: any(named: 'headers'))).called(1);
    expect(find.text('deed.pdf'), findsOneWidget);
  });

  testWidgets('deleting an uploaded file calls the delete endpoint after confirming', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    stubCommon(httpClient, filesJson: '{"files":[{"id":9,"name":"deed.pdf","contract_id":1,"status":"pending"}]}');

    await pumpModal(tester, api);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path == '/workspaces/5/files/9')), headers: any(named: 'headers'))).called(1);
  });
}
