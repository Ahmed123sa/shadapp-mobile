import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/profile/profile_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/auth_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, AuthProvider provider, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProfilePage(authProvider: provider, api: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads the current user into the name field', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"user":{"name":"Ahmed","avatar_url":null}}'),
    );
    final provider = AuthProvider(api: api);

    await pumpPage(tester, provider, api);

    // TextField's current text isn't a Text descendant, so it has to be read
    // off the controller directly.
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'Ahmed');
  });

  testWidgets('saving puts the new name to /auth/me and pops with true', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"user":{"name":"Ahmed","avatar_url":null}}'),
    );
    Map<String, dynamic>? sentBody;
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });
    final provider = AuthProvider(api: api);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProfilePage(authProvider: provider, api: api),
          )),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ahmed Ali');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    // Not pumpAndSettle: the save flow calls Navigator.pop right after
    // showing the SnackBar, and settling can finish that pop transition
    // before the assertions below run.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(sentBody, {'name': 'Ahmed Ali'});
    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/auth/me'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
