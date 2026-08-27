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
