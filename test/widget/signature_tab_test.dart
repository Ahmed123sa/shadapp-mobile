import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/client_repository.dart';
import 'package:shadapp_client/data/signature_repository.dart';
import 'package:shadapp_client/features/signature/signature_tab.dart';
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
      home: Scaffold(body: SignatureTab(clientProvider: clientProvider, signatureProvider: signatureProvider, api: api)),
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
  });

  testWidgets('switching to text mode and saving posts the text, then reloads', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 9;
    var getCalls = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      getCalls++;
      if (getCalls == 1) return jsonResponse('{"client":{}}');
      return jsonResponse('{"client":{"signature_data":"Sara Ahmed"}}');
    });
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
    await tester.pumpAndSettle();

    expect(sentBody, {'signature': 'Sara Ahmed'});
    expect(getCalls, 2);
    expect(find.text('Sara Ahmed'), findsOneWidget);
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
    expect(find.text('Ahmed Ali'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete Signature'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/sign'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('Ahmed Ali'), findsNothing);
  });
}
