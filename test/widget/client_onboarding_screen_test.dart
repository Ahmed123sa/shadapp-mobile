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
}
