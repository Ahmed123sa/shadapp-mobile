// The contract details sheet opened from the Contracts tab. After the client
// approves, the company still reviews each required document; a rejected one
// must show why and offer the client a way to upload it again. The sheet used
// to hide the whole section once the contract left "sent", leaving a rejected
// file with no way forward.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/contracts/contract_detail_sheet.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpSheet(WidgetTester tester, Map<String, dynamic> contract) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{"files":[]}'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The sheet is a DraggableScrollableSheet: it needs a bounded parent,
      // as it gets inside showModalBottomSheet, not a scroll view.
      home: Scaffold(
        body: ContractDetailSheet(
          contract: contract,
          onAction: (_, __) async {},
          onRefresh: () {},
          onGoToPayments: null,
          api: api,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> contract(String status) => {
        'id': 1,
        'title': 'Villa Deal',
        'status': status,
        'required_documents': [
          {
            'id': 10,
            'name': 'National ID',
            'files': [
              {'id': 1, 'status': 'rejected', 'rejection_reason': 'Blurry copy'},
            ],
          },
          {
            'id': 11,
            'name': 'Commercial Register',
            'files': [
              {'id': 2, 'status': 'approved'},
            ],
          },
        ],
      };

  testWidgets('after the client approved, a rejected document shows its reason and an upload button', (tester) async {
    await pumpSheet(tester, contract('client_approved'));

    expect(find.text('National ID'), findsOneWidget);
    expect(find.textContaining('Blurry copy'), findsOneWidget);
    // One upload button: the rejected document. The accepted one needs none.
    expect(find.text('Upload Document'), findsOneWidget);
  });

  testWidgets('the required documents are still listed while the contract waits on the client', (tester) async {
    await pumpSheet(tester, contract('sent'));

    expect(find.text('National ID'), findsOneWidget);
    expect(find.text('Upload Document'), findsOneWidget);
  });
}
