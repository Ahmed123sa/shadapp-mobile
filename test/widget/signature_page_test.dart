import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/client_repository.dart';
import 'package:shadapp_client/data/signature_repository.dart';
import 'package:shadapp_client/features/signature/signature_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/client_provider.dart';
import 'package:shadapp_client/providers/signature_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, ClientProvider clientProvider, SignatureProvider signatureProvider, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SignaturePage(clientProvider: clientProvider, signatureProvider: signatureProvider, api: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads an existing text signature and displays it', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 9;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"signature_data":"Ahmed Ali"}}'),
    );
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final signatureProvider = SignatureProvider(repository: SignatureRepository(api: api));

    await pumpPage(tester, clientProvider, signatureProvider, api);

    expect(find.text('Ahmed Ali'), findsOneWidget);
    expect(find.text('Current Signature'), findsOneWidget);
  });

  testWidgets('switching to text mode and saving posts the signature text', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 9;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{}}'),
    );
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final signatureProvider = SignatureProvider(repository: SignatureRepository(api: api));

    await pumpPage(tester, clientProvider, signatureProvider, api);
    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sara Ahmed');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Signature'));
    // Not pumpAndSettle: a successful save schedules Navigator.pop(context,
    // true) a full second later via Future.delayed, which the test's virtual
    // clock would otherwise fast-forward through and pop the only route in
    // this bare MaterialApp. A few zero-duration pumps are enough to flush
    // the mocked POST and the resulting setState/SnackBar without reaching
    // that timer.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(sentBody, {'signature': 'Sara Ahmed'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/sign'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.text('Signature saved'), findsWidgets);

    // Flush the pending 1-second Future.delayed(Navigator.pop) timer so the
    // test binding doesn't fail its "no pending timers" teardown check.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('deleting the existing signature calls DELETE and clears it', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 9;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"signature_data":"Ahmed Ali"}}'),
    );
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final signatureProvider = SignatureProvider(repository: SignatureRepository(api: api));

    await pumpPage(tester, clientProvider, signatureProvider, api);
    expect(find.text('Current Signature'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete Signature'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/sign'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('Current Signature'), findsNothing);
  });
}
