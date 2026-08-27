import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/approval_repository.dart';
import 'package:shadapp_client/features/approvals/approvals_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/approval_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpPage(WidgetTester tester, ApprovalProvider provider, {int workspaceId = 5}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ApprovalsPage(workspaceId: workspaceId, approvalProvider: provider)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the approval list once loaded', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"approvals":[{"id":1,"title":"Q1 report","status":"pending","requested_by_name":"Ahmed"}]}'),
    );
    final provider = ApprovalProvider(repository: ApprovalRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    expect(find.text('Q1 report'), findsOneWidget);
    expect(find.text('Ahmed'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no approvals', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"approvals":[]}'),
    );
    final provider = ApprovalProvider(repository: ApprovalRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    expect(find.text('No approvals'), findsOneWidget);
  });

  testWidgets('shows the error state on a failed fetch', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );
    final provider = ApprovalProvider(repository: ApprovalRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);

    expect(find.text('Failed to load approvals'), findsOneWidget);
  });

  testWidgets('approving: confirming sends {action: approved} with no reason key, then reloads', (tester) async {
    final httpClient = MockHttpClient();
    var getCalls = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      getCalls++;
      return jsonResponse('{"approvals":[{"id":1,"title":"Q1 report","status":"pending"}]}');
    });
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });
    final provider = ApprovalProvider(repository: ApprovalRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve').last);
    await tester.pumpAndSettle();

    expect(sentBody, {'action': 'approved'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/approvals/1/respond'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(getCalls, 2);
  });

  testWidgets('requesting an edit: sends the typed reason', (tester) async {
    final httpClient = MockHttpClient();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"approvals":[{"id":1,"title":"Q1 report","status":"pending"}]}'),
    );
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });
    final provider = ApprovalProvider(repository: ApprovalRepository(api: buildTestApiClient(client: httpClient)));

    await pumpPage(tester, provider);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Request Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'please fix the total');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
    await tester.pumpAndSettle();

    expect(sentBody, {'action': 'edit_requested', 'reason': 'please fix the total'});
  });

  testWidgets('no workspace id available shows the no-workspace message without calling the API', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient); // api.workspaceId defaults to null
    final provider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ApprovalsPage(approvalProvider: provider, api: api)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No workspace selected'), findsOneWidget);
    verifyNever(() => httpClient.get(any(), headers: any(named: 'headers')));
  });
}
