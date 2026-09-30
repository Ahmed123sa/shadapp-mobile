import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/settings_repository.dart';
import 'package:shadapp_client/features/settings/settings_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  // The sub_user save path calls ApiClient.setUserData(), which reads
  // SharedPreferences.getInstance() — without a mock, that platform channel
  // call never resolves in the test environment and pumpAndSettle() times
  // out waiting for it (same fix used in login_page_test.dart).
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpPage(WidgetTester tester, SettingsProvider provider, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsPage(settingsProvider: provider, api: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('client role: loads contact_person into the name field', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'client';
    api.userId = 9;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":9,"contact_person":"Sara","email":"sara@acme.com"}}'),
    );
    final provider = SettingsProvider(repository: SettingsRepository(api: api));

    await pumpPage(tester, provider, api);

    // TextField's rendered value isn't a Text-widget descendant, so
    // widgetWithText can't see it — read the controller directly instead.
    final nameField = tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField.controller?.text, 'Sara');
  });

  testWidgets('sub_user role: loads email/phone fields from /sub-users/:id', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'sub_user';
    api.subUserId = 3;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"sub_user":{"id":3,"email":"sub@acme.com","phone":"0500000000"}}'),
    );
    final provider = SettingsProvider(repository: SettingsRepository(api: api));

    await pumpPage(tester, provider, api);

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    // Order per the build method: name, email, phone (email/phone only render
    // for sub_user).
    expect(fields[1].controller?.text, 'sub@acme.com');
    expect(fields[2].controller?.text, '0500000000');
  });

  testWidgets('client role: saving PUTs to /clients/:id/profile with contact_person', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'client';
    api.userId = 9;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":9,"contact_person":"Sara"}}'),
    );
    Map<String, dynamic>? sentBody;
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });
    final provider = SettingsProvider(repository: SettingsRepository(api: api));

    await pumpPage(tester, provider, api);
    await tester.enterText(find.byType(TextField).first, 'Sara Updated');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(sentBody!['contact_person'], 'Sara Updated');
    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/profile'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  // subuser-review-plan.md م٤ — email is the sub-user's login; only the
  // owning client can change it (SubUserController::updateProfile 403s a
  // sub-user who tries). The field must be disabled and never sent, even
  // though the value is still loaded and shown for reference.
  testWidgets('sub_user role: email field is disabled and never sent when saving the profile', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'sub_user';
    api.subUserId = 3;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"sub_user":{"id":3,"name":"Employee","email":"sub@acme.com","phone":"0500000000"}}'),
    );
    Map<String, dynamic>? sentBody;
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });
    final provider = SettingsProvider(repository: SettingsRepository(api: api));

    await pumpPage(tester, provider, api);

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[1].enabled, isFalse);

    final saveButton = find.widgetWithText(ElevatedButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(sentBody, isNotNull);
    expect(sentBody!.containsKey('email'), isFalse);
    expect(sentBody!['phone'], '0500000000');
    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/sub-users/3/profile'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
