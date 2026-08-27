import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/client_repository.dart';
import 'package:shadapp_client/data/manager_repository.dart';
import 'package:shadapp_client/data/report_repository.dart';
import 'package:shadapp_client/features/am/workspace/reports_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/client_provider.dart';
import 'package:shadapp_client/providers/manager_provider.dart';
import 'package:shadapp_client/providers/report_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpTab(WidgetTester tester, MockHttpClient httpClient) async {
    final api = buildTestApiClient(client: httpClient);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReportsTab(
          clientProvider: ClientProvider(repository: ClientRepository(api: api)),
          managerProvider: ManagerProvider(repository: ManagerRepository(api: api)),
          reportProvider: ReportProvider(repository: ReportRepository(api: api)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads and shows KPI values from /reports', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/clients')) return jsonResponse('{"clients":[]}');
      if (uri.path.endsWith('/account-managers')) return jsonResponse('{"managers":[]}');
      return jsonResponse(
        '{"total_clients":12,"payments_by_month":{},"contracts_by_status":{"draft":2},"pending_approvals":3,"active_workspaces":5}',
      );
    });

    await pumpTab(tester, httpClient);

    expect(find.text('Clients'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('shows the /reports error message with a retry button on failure', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/clients')) return jsonResponse('{"clients":[]}');
      if (uri.path.endsWith('/account-managers')) return jsonResponse('{"managers":[]}');
      return jsonResponse('{"message":"Server Error"}', 500);
    });

    await pumpTab(tester, httpClient);

    expect(find.text('Server Error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping "This Month" refetches /reports with a date_from/date_to filter', (tester) async {
    final httpClient = MockHttpClient();
    final reportQueries = <Uri>[];
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/clients')) return jsonResponse('{"clients":[]}');
      if (uri.path.endsWith('/account-managers')) return jsonResponse('{"managers":[]}');
      reportQueries.add(uri);
      return jsonResponse(
        '{"total_clients":0,"payments_by_month":{},"contracts_by_status":{"draft":1},"pending_approvals":0,"active_workspaces":0}',
      );
    });

    await pumpTab(tester, httpClient);
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();

    expect(reportQueries.last.queryParameters.containsKey('date_from'), true);
    expect(reportQueries.last.queryParameters.containsKey('date_to'), true);
  });
}
