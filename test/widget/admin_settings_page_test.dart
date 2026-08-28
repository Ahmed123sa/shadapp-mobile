// Characterization test for am/settings/admin_settings_page.dart, written
// immediately after migrating its domains onto AuthProvider (extended with
// updateProfileRaw/uploadAvatarBytes), ContractProvider (extended with
// fetchAllClauseTemplates/createClauseTemplate/updateClauseTemplate/
// deleteClauseTemplate/reorderClauseTemplates), SignatureProvider (extended
// with deleteSelfSignature/uploadSelfSignatureImage/saveSelfSignatureText —
// the `/auth/sign` self-signature endpoints, distinct from the existing
// `/clients/:id/sign` client-signature ones), and a brand new
// SystemSettingsProvider/SystemSettingsRepository pair for the global
// `/settings` (corporate tax) resource. Per the migration's core rule,
// nothing is committed until this and the full suite are green (see
// docs/state-layer-migration-plan.md — this closes task #152, the
// second-to-last deferred screen).
//
// Not covered here (pre-existing testability gap, not introduced by this
// migration): the avatar-upload and draw/upload-signature-image buttons —
// FilePicker.platform is a real platform channel with no mock registered
// under plain `flutter test`, same reasoning documented throughout this
// migration (see contracts_page_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/am/settings/admin_settings_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  void stubCommon(MockHttpClient httpClient, {
    String meJson = '{"user":{"name":"Sara Admin","official_email":"sara@shad.app"}}',
    String settingsJson = '{"settings":{"corporate_tax_percentage":{"value":"15"}}}',
    String clausesJson = '{"templates":[]}',
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/auth/me') return jsonResponse(meJson);
      if (path == '/settings') return jsonResponse(settingsJson);
      if (path == '/contract-clause-templates') return jsonResponse(clausesJson);
      return jsonResponse('{}');
    });
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));
    when(() => httpClient.delete(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => jsonResponse('{}'));
  }

  Future<void> pumpPage(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AdminSettingsPage(api: api)),
    ));
    await tester.pumpAndSettle();
  }

  // The page's body is one long ListView (profile -> signature -> tax ->
  // clauses); most of what these tests interact with sits well below the
  // default 800x600 test surface, and a plain (non-builder) ListView only
  // inflates Elements for children near the viewport, so an off-screen
  // widget isn't just unclickable, it isn't even findable. Every tap/find
  // below that isn't on the profile fields goes through this first.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('loads profile, tax setting and clause templates for a super_admin', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(httpClient, clausesJson: '{"templates":[{"id":1,"title":"Confidentiality","content":"...","type":"fixed","is_active":true}]}');

    await pumpPage(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/auth/me')), headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/settings')), headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/contract-clause-templates')), headers: any(named: 'headers'))).called(1);
    expect(find.text('Sara Admin'), findsOneWidget);
    await scrollTo(tester, find.text('Confidentiality'));
    expect(find.text('Confidentiality'), findsOneWidget);
  });

  testWidgets('saving the profile puts /auth/me with the official email for a super_admin', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(httpClient);

    await pumpPage(tester, api);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
    await tester.pumpAndSettle();

    final captured = verify(() => httpClient.put(
          any(that: predicate<Uri>((u) => u.path == '/auth/me')),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        )).captured;
    expect(captured.single, contains('official_email'));
  });

  testWidgets('saving the tax rate puts /settings', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(httpClient);

    await pumpPage(tester, api);

    await scrollTo(tester, find.widgetWithText(ElevatedButton, 'Save Tax Rate'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Tax Rate'));
    await tester.pumpAndSettle();

    verify(() => httpClient.put(
          any(that: predicate<Uri>((u) => u.path == '/settings')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });

  testWidgets('adding a clause posts /contract-clause-templates', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(httpClient);

    await pumpPage(tester, api);

    await scrollTo(tester, find.widgetWithText(ElevatedButton, 'Add Clause'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Clause'));
    await tester.pumpAndSettle();
    // Scoped to the dialog itself (title/category/content, in that order) —
    // safer than a raw byType(TextField) index, since which of the screen's
    // own fields are still inflated behind the dialog depends on how far it
    // had to scroll to reveal the "Add Clause" button.
    final dialogFields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(dialogFields.at(0), 'Payment Terms');
    await tester.enterText(dialogFields.at(2), 'Payment is due within 30 days.');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    verify(() => httpClient.post(
          any(that: predicate<Uri>((u) => u.path == '/contract-clause-templates')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });

  testWidgets('deleting a clause calls DELETE after confirming', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(httpClient, clausesJson: '{"templates":[{"id":5,"title":"Confidentiality","content":"...","type":"fixed","is_active":true}]}');

    await pumpPage(tester, api);

    await scrollTo(tester, find.byIcon(Icons.delete_outline));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path == '/contract-clause-templates/5')), headers: any(named: 'headers'))).called(1);
  });

  testWidgets('toggling a clause active state puts is_active', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(httpClient, clausesJson: '{"templates":[{"id":5,"title":"Confidentiality","content":"...","type":"fixed","is_active":true}]}');

    await pumpPage(tester, api);

    await scrollTo(tester, find.byIcon(Icons.visibility_outlined));
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    verify(() => httpClient.put(
          any(that: predicate<Uri>((u) => u.path == '/contract-clause-templates/5')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });

  testWidgets('saving a typed signature posts /auth/sign', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(httpClient);

    await pumpPage(tester, api);

    await scrollTo(tester, find.text('Text'));
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    // Matched by its hint text rather than a byType(TextField) index — which
    // index the signature field lands on depends on how far the screen had
    // to scroll (and thus which earlier fields are still inflated).
    final sigField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Type your signature');
    await scrollTo(tester, sigField);
    await tester.enterText(sigField, 'Sara A.');
    await scrollTo(tester, find.widgetWithText(ElevatedButton, 'Save Signature'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Signature'));
    await tester.pumpAndSettle();

    verify(() => httpClient.post(
          any(that: predicate<Uri>((u) => u.path == '/auth/sign')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });

  testWidgets('deleting the existing signature calls DELETE /auth/sign', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    stubCommon(httpClient, meJson: '{"user":{"name":"Sara Admin","official_email":"sara@shad.app","signature_data":"Sara A."}}');

    await pumpPage(tester, api);

    await scrollTo(tester, find.byIcon(Icons.delete_outline));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path == '/auth/sign')), headers: any(named: 'headers'))).called(1);
  });
}
