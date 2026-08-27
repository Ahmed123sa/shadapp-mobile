import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/meeting_repository.dart';
import 'package:shadapp_client/features/am/workspace/meetings_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/contract_provider.dart';
import 'package:shadapp_client/providers/meeting_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpTab(WidgetTester tester, MeetingProvider meetingProvider, ContractProvider contractProvider) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MeetingsTab(workspaceId: 5, meetingProvider: meetingProvider, contractProvider: contractProvider),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads and groups meetings into Upcoming vs Previous', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"meetings":[{"id":1,"title":"Future Sync","status":"scheduled","scheduled_at":"2030-01-01T10:00:00.000Z"},'
        '{"id":2,"title":"Past Sync","status":"completed","scheduled_at":"2020-01-01T10:00:00.000Z"}]}',
      ),
    );
    final meetingProvider = MeetingProvider(repository: MeetingRepository(api: api));
    final contractProvider = ContractProvider(api: api);

    await pumpTab(tester, meetingProvider, contractProvider);

    expect(find.text('Upcoming Meetings'), findsOneWidget);
    expect(find.text('Future Sync'), findsOneWidget);
    expect(find.text('Previous Meetings'), findsOneWidget);
    expect(find.text('Past Sync'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no meetings', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"meetings":[]}'),
    );
    final meetingProvider = MeetingProvider(repository: MeetingRepository(api: api));
    final contractProvider = ContractProvider(api: api);

    await pumpTab(tester, meetingProvider, contractProvider);

    expect(find.text('No meetings'), findsOneWidget);
  });

  testWidgets('cancelling a meeting confirms, hits PATCH /meetings/:id/cancel, and reloads', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    var loadCount = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      loadCount++;
      if (loadCount == 1) {
        return jsonResponse(
          '{"meetings":[{"id":1,"title":"Future Sync","status":"scheduled","scheduled_at":"2030-01-01T10:00:00.000Z"}]}',
        );
      }
      return jsonResponse('{"meetings":[]}');
    });
    when(() => httpClient.patch(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));
    final meetingProvider = MeetingProvider(repository: MeetingRepository(api: api));
    final contractProvider = ContractProvider(api: api);

    await pumpTab(tester, meetingProvider, contractProvider);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Meeting'));
    await tester.pumpAndSettle();

    verify(() => httpClient.patch(any(that: predicate<Uri>((u) => u.path.endsWith('/meetings/1/cancel'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.text('Meeting cancelled successfully'), findsOneWidget);
    expect(find.text('No meetings'), findsOneWidget);
  });

  testWidgets('creating a meeting posts to /workspaces/:id/meetings with the entered title', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/contracts')) return jsonResponse('{"contracts":[]}');
      return jsonResponse('{"meetings":[]}');
    });
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });
    final meetingProvider = MeetingProvider(repository: MeetingRepository(api: api));
    final contractProvider = ContractProvider(api: api);

    await pumpTab(tester, meetingProvider, contractProvider);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Kickoff Call');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Meeting'));
    await tester.pumpAndSettle();

    expect(sentBody!['title'], 'Kickoff Call');
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/meetings'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
