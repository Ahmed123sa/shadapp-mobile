import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/manager_repository.dart';
import 'package:shadapp_client/features/am/managers/manager_detail_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/manager_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, ManagerProvider provider, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ManagerDetailPage(managerId: 5, managerProvider: provider, api: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads and displays manager name, stats and client list', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/account-managers/5/stats'))),
        headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients_count":4,"active_workspaces":2,"pending_payments":1,"total_revenue":"1500"}'),
    );
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/account-managers/5'))),
        headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
          '{"manager":{"id":5,"name":"Ahmed Ali","email":"ahmed@acme.com"},"clients":[{"id":1,"company_name":"Acme","contact_person":"Sara","workspace":{"status":"active"}}]}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: api));

    await pumpPage(tester, provider, api);

    expect(find.text('Ahmed Ali'), findsWidgets);
    expect(find.text('ahmed@acme.com'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // clients_count stat
    expect(find.text('Acme'), findsOneWidget);
  });

  // 21 Sept 2026 — total_revenue and payments_by_month both sum every
  // currency into one number with no currency attached at all. Not
  // mislabeled like the dashboard's old "EGP" bug, but still meaningless
  // once currencies mix with no exchange rate. These cover the fix:
  // payments_by_month_by_currency drives the income card's real figure and
  // a currency toggle above the monthly-income chart.
  Future<void> pumpWithStats(WidgetTester tester, String statsJson) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/account-managers/5/stats'))),
        headers: any(named: 'headers'))).thenAnswer((_) async => jsonResponse(statsJson));
    when(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/account-managers/5'))),
        headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"manager":{"id":5,"name":"Ahmed Ali","email":"ahmed@acme.com"},"clients":[]}'),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: api));
    await pumpPage(tester, provider, api);
  }

  testWidgets('shows the largest currency total with its code on the income card', (tester) async {
    await pumpWithStats(tester, '{"clients_count":0,"active_workspaces":0,"pending_payments":0,"total_revenue":"0",'
        '"payments_by_month_by_currency":{"2026-09":{"SAR":85000,"USD":6000}}}');

    expect(find.textContaining('85.0K SAR'), findsOneWidget);
  });

  testWidgets('does not show currency chips when there is only one currency', (tester) async {
    await pumpWithStats(tester, '{"clients_count":0,"active_workspaces":0,"pending_payments":0,"total_revenue":"0",'
        '"payments_by_month_by_currency":{"2026-09":{"SAR":5000}}}');

    // The income card's own text is "5.0K SAR" (one Text widget, not two),
    // so an exact match on the bare code only finds something if a chip
    // rendered one.
    expect(find.text('SAR'), findsNothing);
  });

  testWidgets('shows a chip per currency, and switching does not change the income headline', (tester) async {
    await pumpWithStats(tester, '{"clients_count":0,"active_workspaces":0,"pending_payments":0,"total_revenue":"0",'
        '"payments_by_month_by_currency":{"2026-08":{"SAR":1000,"USD":9000},"2026-09":{"SAR":2000,"USD":1000}}}');

    // USD totals 10000 vs SAR's 3000, so USD is the income headline and
    // starts selected on the chart.
    expect(find.textContaining('10.0K USD'), findsOneWidget);
    expect(find.text('SAR'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);

    await tester.tap(find.text('SAR'));
    await tester.pumpAndSettle();

    // Switching the chart's currency doesn't change which currency the
    // income card headlines — that's always the biggest total overall.
    expect(find.textContaining('10.0K USD'), findsOneWidget);
  });

  testWidgets('shows the failure message and a retry button when loading fails', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );
    final provider = ManagerProvider(repository: ManagerRepository(api: api));

    await pumpPage(tester, provider, api);

    expect(find.text('Failed to load data'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  });
}
