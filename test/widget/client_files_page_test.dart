import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/file_repository.dart';
import 'package:shadapp_client/features/files/client_files_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/file_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, FileProvider provider, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ClientFilesPage(fileProvider: provider, api: api)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads and displays files, definitions and payment proofs', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
          '{"files":[{"id":1,"name":"passport.pdf","status":"pending"}],'
          '"definitions":[{"id":2,"name":"Passport","is_required":true}],'
          '"paymentFiles":[{"id":3,"name":"receipt.png","status":"approved","amount":"500","currency":"SAR"}]}'),
    );
    final provider = FileProvider(repository: FileRepository(api: api));

    await pumpPage(tester, provider, api);

    expect(find.text('passport.pdf'), findsOneWidget);
    expect(find.textContaining('Passport'), findsWidgets);
    expect(find.text('receipt.png'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no files', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"files":[],"definitions":[],"paymentFiles":[]}'),
    );
    final provider = FileProvider(repository: FileRepository(api: api));

    await pumpPage(tester, provider, api);

    expect(find.text('No files'), findsOneWidget);
  });

  testWidgets('deleting a file: confirming calls DELETE then reloads', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.workspaceId = 5;
    var getCalls = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      getCalls++;
      if (getCalls == 1) {
        return jsonResponse('{"files":[{"id":1,"name":"passport.pdf","status":"pending"}],"definitions":[],"paymentFiles":[]}');
      }
      return jsonResponse('{"files":[],"definitions":[],"paymentFiles":[]}');
    });
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );
    final provider = FileProvider(repository: FileRepository(api: api));

    await pumpPage(tester, provider, api);
    expect(find.text('passport.pdf'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/files/1'))),
        headers: any(named: 'headers'))).called(1);
    expect(getCalls, 2);
    expect(find.text('No files'), findsOneWidget);
  });
}
