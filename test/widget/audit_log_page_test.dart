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

  // 20 Sept 2026 — audit_logs.user_id is an FK into `users`, so any action
  // taken by a client or sub-user arrives with user: null. This tile read
  // only log['user']['name'], so all of those rows — every sub_user.* entry,
  // client-approved contracts, and now client/sub-user logins — rendered
  // with no actor at all. The backend eager-loads `client` for exactly this
  // case and the dashboard already falls back to it.
  testWidgets('falls back to the client company name when the actor is not staff', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"logs":{"data":[{"id":1,"action":"login","created_at":"2026-01-01T10:30:00Z",'
        '"user":null,"client":{"company_name":"Acme Corp","contact_person":"Sara"}}],'
        '"last_page":1,"total":1}}',
      ),
    );
    final provider = AuditLogProvider(repository: AuditLogRepository(api: api));

    await pumpPage(tester, provider);

    expect(find.textContaining('Acme Corp'), findsOneWidget);
  });

  testWidgets('falls back to the contact person when the client has no company name', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"logs":{"data":[{"id":1,"action":"sub_user.created","created_at":"2026-01-01T10:30:00Z",'
        '"user":null,"client":{"company_name":"","contact_person":"Sara"}}],'
        '"last_page":1,"total":1}}',
      ),
    );
    final provider = AuditLogProvider(repository: AuditLogRepository(api: api));

    await pumpPage(tester, provider);

    expect(find.textContaining('Sara'), findsOneWidget);
  });

  testWidgets('a staff name still wins over the client name', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"logs":{"data":[{"id":1,"action":"contract.created","created_at":"2026-01-01T10:30:00Z",'
        '"user":{"name":"Ahmed"},"client":{"company_name":"Acme Corp"}}],'
        '"last_page":1,"total":1}}',
      ),
    );
    final provider = AuditLogProvider(repository: AuditLogRepository(api: api));

    await pumpPage(tester, provider);

    expect(find.textContaining('Ahmed'), findsOneWidget);
    expect(find.textContaining('Acme Corp'), findsNothing);
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
