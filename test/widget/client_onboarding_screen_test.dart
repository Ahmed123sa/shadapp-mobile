// Characterization test for onboarding/client_onboarding_screen.dart, written
// alongside migrating its four domains onto already-existing provider
// methods — ClientProvider.fetchClientRaw, SystemSettingsProvider.
// fetchSettings, ContractProvider.clientAction, and PaymentProvider.
// createPayment (whose file/bytes/plain three-branch logic already matched
// this screen's _submitPaymentOnboarding exactly, so no new provider code
// was needed). Per the migration's core rule, nothing is committed until
// this and the full suite are green (see docs/state-layer-migration-plan.md
// — this is task #153, the LAST deferred screen anywhere in features/; once
// this is green, features/ has zero remaining _api.verb() calls).
//
// Not covered here (pre-existing testability gap, not introduced by this
// migration): the "Sign Now" / notifications / logout navigation buttons
// (go_router push/go, out of scope for this screen's own domain migration),
// and the proof-file-attached payment branches — FilePicker.platform and
// ImagePicker are real platform channels with no mock registered under plain
// `flutter test`, same reasoning documented throughout this migration (see
// contracts_page_test.dart). Only the no-files plain-POST payment branch is
// exercised here.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/reverb_service.dart';
import 'package:shadapp_client/features/onboarding/client_onboarding_screen.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  // _loadClientData() calls ApiClient.setUserData() (to persist the newly
  // learned workspace id whenever it differs from _api.workspaceId, which is
  // always true here since the test ApiClient starts with none), which hits
  // SharedPreferences.getInstance() — needs mock init values under plain
  // `flutter test`, same as client_dashboard_screen_test.dart /
  // am_dashboard_page_test.dart. Without this every test here hangs
  // pumpAndSettle forever on the initial loading spinner.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void stubGets(MockHttpClient httpClient, {
    required String clientJson,
    String settingsJson = '{"settings":{"corporate_tax_percentage":{"value":"0"}}}',
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/clients/10') return jsonResponse(clientJson);
      if (path == '/settings') return jsonResponse(settingsJson);
      return jsonResponse('{}');
    });
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));
  }

  Future<void> pumpScreen(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ClientOnboardingScreen(api: api, reverb: ReverbService.forTesting(), enableFcm: false),
    ));
    await tester.pumpAndSettle();
  }

  // The payment bottom sheet's own SingleChildScrollView is the last
  // Scrollable in the tree once it's open (it's inserted into the root
  // Overlay above the main screen's content) — its "Send Payment" submit
  // button sits below the 800x600 test surface until scrolled into view,
  // same off-screen-widget reasoning as admin_settings_page_test.dart.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
  }

  testWidgets('loads client and settings, shows the signature stage welcome message', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    stubGets(httpClient, clientJson: '{"client":{"id":10,"contact_person":"Ali","signed_at":null,"client_type":"individual",'
        '"workspace":{"id":5,"status":"pending","contracts":[],"payments":[]}}}');

    await pumpScreen(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/clients/10')), headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path == '/settings')), headers: any(named: 'headers'))).called(1);
    expect(find.text('Welcome Ali'), findsOneWidget);
    expect(find.text('Sign Now'), findsOneWidget);
  });

  testWidgets('approving a sent contract posts client-action', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    stubGets(httpClient, clientJson: '{"client":{"id":10,"contact_person":"Ali","signed_at":"2026-01-01T00:00:00Z","client_type":"individual",'
        '"workspace":{"id":5,"status":"active","contracts":[{"id":7,"status":"sent"}],"payments":[]}}}');

    await pumpScreen(tester, api);

    expect(find.text('Approve'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pumpAndSettle();

    verify(() => httpClient.post(
          any(that: predicate<Uri>((u) => u.path == '/contracts/7/client-action')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });

  // client-signature-plan.md ن3 — _computeStage() now keeps a client with no
  // saved signature on the signature stage even once a contract is sitting
  // at 'sent', instead of jumping them straight to the approve screen (which
  // used to offer an Approve button the backend would then reject, per ك3,
  // with no explanation of why).
  testWidgets('a sent contract with no saved signature shows the signature stage instead of Approve', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    stubGets(httpClient, clientJson: '{"client":{"id":10,"contact_person":"Ali","signed_at":null,"client_type":"individual",'
        '"workspace":{"id":5,"status":"pending","contracts":[{"id":7,"status":"sent"}],"payments":[]}}}');

    await pumpScreen(tester, api);

    expect(find.text('Sign Now'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
  });

  // Fallback path for the same ن3 bug: if the backend still rejects an
  // 'approved' action for missing signature (e.g. a client whose signed_at
  // is stale or desynced from the server's own signature_data check), the
  // reactive maybeShowSignatureRequiredDialog wiring in
  // _respondToContractById's catch block should surface it instead of a
  // generic failure message.
  testWidgets('a backend signature_required rejection on approve shows the signature-required dialog', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    stubGets(httpClient, clientJson: '{"client":{"id":10,"contact_person":"Ali","signed_at":"2026-01-01T00:00:00Z","client_type":"individual",'
        '"workspace":{"id":5,"status":"active","contracts":[{"id":7,"status":"sent"}],"payments":[]}}}');
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"message":"لازم تحفظ توقيعك الأول قبل ما توافق.","code":"signature_required"}', 422),
    );

    await pumpScreen(tester, api);

    expect(find.text('Approve'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Signature Required'), findsOneWidget);
    expect(find.text('Sign Now'), findsOneWidget);
  });

  testWidgets('sending a payment with no attached proof posts to /workspaces/:id/payments', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    stubGets(httpClient, clientJson: '{"client":{"id":10,"contact_person":"Ali","signed_at":"2026-01-01T00:00:00Z","client_type":"individual",'
        '"workspace":{"id":5,"status":"active","contracts":[{"id":7,"status":"company_approved","value":"1000","currency":"SAR"}],"payments":[]}}}');

    await pumpScreen(tester, api);

    final ctaButton = find.widgetWithText(ElevatedButton, 'Send Payment');
    await scrollTo(tester, ctaButton);
    await tester.tap(ctaButton);
    await tester.pumpAndSettle();
    final submitButton = find.widgetWithText(ElevatedButton, 'Send Payment').last;
    await scrollTo(tester, submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    verify(() => httpClient.post(
          any(that: predicate<Uri>((u) => u.path == '/workspaces/5/payments')),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).called(1);
  });

  // plans/payment-currency-plan.md ح4: the onboarding payment sheet used to
  // show a free 9-currency dropdown defaulting to SAR, ignoring the
  // client's actual contract. It's now a fixed value threaded through from
  // buildPaymentStage, displayed read-only — the backend enforces this
  // regardless via PaymentController::resolveCurrency().
  testWidgets('sending a payment for an EGP contract posts currency EGP without offering a free choice', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    stubGets(httpClient, clientJson: '{"client":{"id":10,"contact_person":"Ali","signed_at":"2026-01-01T00:00:00Z","client_type":"individual",'
        '"workspace":{"id":5,"status":"active","contracts":[{"id":7,"status":"company_approved","value":"1000","currency":"EGP"}],"payments":[]}}}');
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpScreen(tester, api);

    final ctaButton = find.widgetWithText(ElevatedButton, 'Send Payment');
    await scrollTo(tester, ctaButton);
    await tester.tap(ctaButton);
    await tester.pumpAndSettle();

    // Only the payment-method dropdown (bank_transfer/swift/...) remains —
    // also a DropdownButtonFormField<String>, so we assert exactly one
    // rather than none, and confirm the currency itself is shown as
    // read-only text instead of a second dropdown.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('EGP'), findsWidgets);

    final submitButton = find.widgetWithText(ElevatedButton, 'Send Payment').last;
    await scrollTo(tester, submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(sentBody?['currency'], 'EGP');
  });

  // payment-proof-upload-plan.md, Stage 4 (ح1) — same fix as
  // payments_page_test.dart's equivalent test, applied to onboarding's own
  // payment sheet.
  testWidgets('sending a payment that the server rejects shows its message inside the sheet and keeps it open', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    stubGets(httpClient, clientJson: '{"client":{"id":10,"contact_person":"Ali","signed_at":"2026-01-01T00:00:00Z","client_type":"individual",'
        '"workspace":{"id":5,"status":"active","contracts":[{"id":7,"status":"company_approved","value":"1000","currency":"SAR"}],"payments":[]}}}');
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse(
        '{"message":"The given data was invalid.","errors":{"amount":["Amount exceeds the remaining contract value"]}}',
        422,
      ),
    );

    await pumpScreen(tester, api);

    final ctaButton = find.widgetWithText(ElevatedButton, 'Send Payment');
    await scrollTo(tester, ctaButton);
    await tester.tap(ctaButton);
    await tester.pumpAndSettle();
    final submitButton = find.widgetWithText(ElevatedButton, 'Send Payment').last;
    await scrollTo(tester, submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Amount exceeds the remaining contract value'), findsOneWidget);
    // The sheet is still open (not popped): both the page's own "Send
    // Payment" CTA behind it and the sheet's submit button (same label) are
    // still on screen. If the sheet had been popped, only the CTA would
    // remain.
    expect(find.widgetWithText(ElevatedButton, 'Send Payment'), findsNWidgets(2));
  });
}
