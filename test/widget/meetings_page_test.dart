import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/meeting_repository.dart';
import 'package:shadapp_client/features/meetings/meetings_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/meeting_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  // meetings_page.dart's _load() guards on _api.workspaceId being non-null
  // (see docs/state-layer-migration-plan.md, P0-1 — no more silent
  // workspace-1 fallback), so every pump needs both an injected api with
  // workspaceId set AND that same api backing the MeetingProvider's
  // repository, or the fetch is skipped and the screen always renders empty.
  Future<void> pumpPage(WidgetTester tester, MeetingProvider provider, {required dynamic api}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MeetingsPage(meetingProvider: provider, api: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when there are no meetings', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"meetings":[]}'),
    );
    final api = buildTestApiClient(client: httpClient)..workspaceId = 5;
    final provider = MeetingProvider(repository: MeetingRepository(api: api));

    await pumpPage(tester, provider, api: api);

    expect(find.text('No meetings'), findsOneWidget);
  });

  testWidgets('splits meetings into Upcoming and Previous sections', (tester) async {
    final httpClient = MockHttpClient();
    final future = DateTime.now().add(const Duration(days: 1)).toIso8601String();
    final past = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"meetings":[{"id":1,"title":"Future meeting","status":"scheduled","scheduled_at":"$future"},'
        '{"id":2,"title":"Past meeting","status":"completed","scheduled_at":"$past"}]}',
      ),
    );
    final api = buildTestApiClient(client: httpClient)..workspaceId = 5;
    final provider = MeetingProvider(repository: MeetingRepository(api: api));

    await pumpPage(tester, provider, api: api);

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Future meeting'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Past meeting'), findsOneWidget);
  });

  testWidgets('a failed fetch results in the empty state, not an error screen', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );
    final api = buildTestApiClient(client: httpClient)..workspaceId = 5;
    final provider = MeetingProvider(repository: MeetingRepository(api: api));

    await pumpPage(tester, provider, api: api);

    // Documents existing (if surprising) behavior: _error is declared but
    // never actually set anywhere in meetings_page.dart, so a failed fetch
    // always falls through to the empty state rather than ErrorState.
    expect(find.text('No meetings'), findsOneWidget);
  });

  testWidgets('shows duration when present', (tester) async {
    final httpClient = MockHttpClient();
    final future = DateTime.now().add(const Duration(days: 1)).toIso8601String();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"meetings":[{"id":1,"title":"Kickoff","status":"scheduled","scheduled_at":"$future","duration_minutes":45}]}',
      ),
    );
    final api = buildTestApiClient(client: httpClient)..workspaceId = 5;
    final provider = MeetingProvider(repository: MeetingRepository(api: api));

    await pumpPage(tester, provider, api: api);

    expect(find.text('45 min'), findsOneWidget);
  });

  testWidgets('a null workspaceId skips the fetch and shows the empty state', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"meetings":[{"id":1,"title":"Should not appear","status":"scheduled"}]}'),
    );
    final api = buildTestApiClient(client: httpClient);
    final provider = MeetingProvider(repository: MeetingRepository(api: api));

    await pumpPage(tester, provider, api: api);

    verifyNever(() => httpClient.get(any(), headers: any(named: 'headers')));
    expect(find.text('No meetings'), findsOneWidget);
  });
}
