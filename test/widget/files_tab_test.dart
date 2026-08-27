import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/file_repository.dart';
import 'package:shadapp_client/features/am/workspace/files_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/file_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, FileProvider provider, dynamic api, {int workspaceId = 5}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FilesTab(workspaceId: workspaceId, fileProvider: provider, api: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('AM role: shows definitions/files and the add-definition button, no review actions', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
          '{"files":[{"id":1,"name":"passport.pdf","status":"pending"}],"definitions":[{"id":2,"name":"Passport","is_required":true}]}'),
    );
    final provider = FileProvider(repository: FileRepository(api: api));

    await pumpPage(tester, provider, api);

    expect(find.text('Passport'), findsOneWidget);
    expect(find.text('passport.pdf'), findsOneWidget);
    expect(find.text('Add Document Definition'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('SA role: approving a pending file calls the review endpoint and reloads', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    var getCalls = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      getCalls++;
      if (getCalls == 1) {
        return jsonResponse('{"files":[{"id":1,"name":"passport.pdf","status":"pending"}],"definitions":[]}');
      }
      return jsonResponse('{"files":[{"id":1,"name":"passport.pdf","status":"approved"}],"definitions":[]}');
    });
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = {'action': 'approved'};
      return jsonResponse('{}');
    });
    final provider = FileProvider(repository: FileRepository(api: api));

    await pumpPage(tester, provider, api);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(sentBody!['action'], 'approved');
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/files/1/review'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(getCalls, 2);
  });

  testWidgets('deleting a definition: confirming calls DELETE and reloads', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    var getCalls = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      getCalls++;
      if (getCalls == 1) {
        return jsonResponse('{"files":[],"definitions":[{"id":2,"name":"Passport","is_required":true}]}');
      }
      return jsonResponse('{"files":[],"definitions":[]}');
    });
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );
    final provider = FileProvider(repository: FileRepository(api: api));

    await pumpPage(tester, provider, api);
    expect(find.text('Passport'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/document-definitions/2'))),
        headers: any(named: 'headers'))).called(1);
    expect(getCalls, 2);
    expect(find.text('Passport'), findsNothing);
  });
}
