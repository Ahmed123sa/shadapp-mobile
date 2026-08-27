import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/am/clients/create_client_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, dynamic api) async {
    // The form is a plain (non-.builder) ListView, but Sliver layout still
    // only builds children within/near the viewport — at the default test
    // surface size (800x600) the address field and both bottom buttons sit
    // below the fold and are never built at all. A tall viewport avoids the
    // need to scroll to each target individually.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CreateClientPage(api: api),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> fillRequiredFields(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Acme Corp');
    await tester.enterText(find.byType(TextFormField).at(1), 'Sara Ahmed');
    await tester.enterText(find.byType(TextFormField).at(2), 'sara@acme.com');
    await tester.enterText(find.byType(TextFormField).at(3), '0501234567');
  }

  testWidgets('shows the address field with its label and hint', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    await pumpPage(tester, api);

    expect(find.widgetWithText(TextFormField, 'Address'), findsOneWidget);
  });

  testWidgets('address is optional: submitting without one omits it from the request', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"client":{"id":1},"credentials":{"email":"sara@acme.com","password":"x"}}');
    });
    await pumpPage(tester, api);
    await fillRequiredFields(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Client'));
    // Not pumpAndSettle: on success, _submit() opens a success dialog and
    // awaits its result — the button stays in its "saving" (spinner) state
    // the whole time it's open, and since this test never dismisses the
    // dialog, that spinner would animate forever and pumpAndSettle would
    // time out. A couple of bounded pumps is enough to flush the mocked
    // (synchronous) API call, which is all these assertions need.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sentBody, isNotNull);
    expect(sentBody!.containsKey('address'), isFalse);
  });

  testWidgets('a filled-in, trimmed address is included in the request', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"client":{"id":1},"credentials":{"email":"sara@acme.com","password":"x"}}');
    });
    await pumpPage(tester, api);
    await fillRequiredFields(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Address'), '  12 Tahrir St, Cairo  ');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Client'));
    // See the comment in the previous test — not pumpAndSettle, same reason.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sentBody!['address'], '12 Tahrir St, Cairo');
  });

  testWidgets('required-field validation blocks submission before any request is sent', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    await pumpPage(tester, api);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Client'));
    await tester.pumpAndSettle();

    expect(find.text('Company name is required'), findsOneWidget);
    verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
  });
}
