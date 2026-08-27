import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/client_repository.dart';
import 'package:shadapp_client/features/am/clients/client_detail_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/client_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, ClientProvider provider, dynamic api) async {
    // This screen's ListView has a long preamble (avatar, badges, an info
    // card, a type toggle) before the actual form fields, so the default
    // 800x600 test surface only inflates elements for the first field or two
    // — the rest exist as widgets but never get Elements built without being
    // scrolled into view. A tall surface sidesteps that instead of scrolling
    // between every assertion.
    await tester.binding.setSurfaceSize(const Size(400, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ClientDetailPage(clientId: 5, clientProvider: provider, api: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads company_name, contact_person and sub-users count into the page', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
          '{"client":{"id":5,"company_name":"Acme Co","contact_person":"Sara","email":"sara@acme.com","status":"active","sub_users":[{"name":"Sub One","email":"sub1@acme.com"}]}}'),
    );
    final provider = ClientProvider(repository: ClientRepository(api: api));

    await pumpPage(tester, provider, api);

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller?.text, 'Acme Co');
    expect(fields[1].controller?.text, 'Sara');
    expect(find.text('Sub One'), findsOneWidget);
    expect(find.text('sub1@acme.com'), findsOneWidget);
  });

  testWidgets('saving PUTs to /clients/:id with the edited company_name', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":5,"company_name":"Acme Co","contact_person":"Sara"}}'),
    );
    Map<String, dynamic>? sentBody;
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"client":{"id":5,"company_name":"Acme Renamed"}}');
    });
    final provider = ClientProvider(repository: ClientRepository(api: api));

    await pumpPage(tester, provider, api);
    await tester.enterText(find.byType(TextField).first, 'Acme Renamed');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
    // Not pumpAndSettle: on success the screen calls Navigator.pop(context,
    // true) right after showing the SnackBar, and since this is the only
    // route in the test's MaterialApp, letting the pop transition fully
    // settle takes the SnackBar (and the page hosting it) down with it. A
    // couple of bounded pumps catch the SnackBar while it's still mounted.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(sentBody!['company_name'], 'Acme Renamed');
    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/5'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.textContaining('Changes saved successfully'), findsOneWidget);
  });
}
