import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/audit_log_repository.dart';
import 'package:shadapp_client/features/am/reports/audit_log_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/audit_log_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, AuditLogProvider provider) async {
    // The empty state's SizedBox is sized to 30% of MediaQuery's screen
    // height; the default test MediaQuery isn't tall enough to fit
    // EmptyState's icon+title+subtitle inside that 30%, which overflows.
    // Overriding MediaQueryData directly (rather than the test surface size,
    // which didn't change what MediaQuery.of(context).size reports here)
    // gives EmptyState enough room.
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(400, 1200)),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AuditLogPage(auditLogProvider: provider),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads and shows a log entry with the event count', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"logs":{"data":[{"id":1,"action":"contract.created","created_at":"2026-01-01T10:30:00Z","user":{"name":"Ahmed"}}],"last_page":1,"total":1}}',
      ),
    );
    final provider = AuditLogProvider(repository: AuditLogRepository(api: api));

    await pumpPage(tester, provider);

    expect(find.text('1 events logged'), findsOneWidget);
    expect(find.textContaining('Ahmed'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no logs', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"logs":{"data":[],"last_page":1,"total":0}}'),
    );
    final provider = AuditLogProvider(repository: AuditLogRepository(api: api));

    await pumpPage(tester, provider);

    expect(find.text('No events'), findsOneWidget);
  });

  testWidgets('typing in the search box debounces and refetches with the search filter', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    final searchesSent = <String?>[];
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      searchesSent.add(uri.queryParameters['search']);
      return jsonResponse('{"logs":{"data":[],"last_page":1,"total":0}}');
    });
    final provider = AuditLogProvider(repository: AuditLogRepository(api: api));

    await pumpPage(tester, provider);
    await tester.enterText(find.byType(TextField), 'ahmed');
    // The search is debounced by 400ms inside the screen itself.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(searchesSent.last, 'ahmed');
  });

  testWidgets('tapping a filter chip refetches with that action filter', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    final actionsSent = <String?>[];
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      actionsSent.add(uri.queryParameters['action']);
      return jsonResponse('{"logs":{"data":[],"last_page":1,"total":0}}');
    });
    final provider = AuditLogProvider(repository: AuditLogRepository(api: api));

    await pumpPage(tester, provider);
    await tester.tap(find.text('Contracts'));
    await tester.pumpAndSettle();

    expect(actionsSent.last, 'contract');
  });
}
