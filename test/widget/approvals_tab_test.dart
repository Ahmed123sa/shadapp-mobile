import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/approval_repository.dart';
import 'package:shadapp_client/features/am/workspace/approvals_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/approval_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpTab(WidgetTester tester, ApprovalProvider provider, dynamic api) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ApprovalsTab(workspaceId: 5, approvalProvider: provider, api: api)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state for an account manager with no approvals yet', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 1;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"approvals":[]}'),
    );
    final provider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpTab(tester, provider, api);

    expect(find.text('No approval requests'), findsOneWidget);
    expect(find.text('Create Approval Request'), findsOneWidget);
  });

  testWidgets('shows a pending approval from someone else with action buttons', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 1;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"approvals":[{"id":9,"title":"Q1 report","status":"pending","requested_by":2,"requested_by_name":"Sara"}]}',
      ),
    );
    final provider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpTab(tester, provider, api);

    expect(find.text('Q1 report'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Approve'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Request Edit'), findsOneWidget);
  });

  testWidgets('hides action buttons on a request the current user made themselves', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 1;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"approvals":[{"id":9,"title":"Q1 report","status":"pending","requested_by":1,"requested_by_name":"Me"}]}',
      ),
    );
    final provider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpTab(tester, provider, api);

    expect(find.widgetWithText(ElevatedButton, 'Approve'), findsNothing);
  });

  testWidgets('super admin does not see the create-request form', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    api.userId = 1;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"approvals":[]}'),
    );
    final provider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpTab(tester, provider, api);

    expect(find.text('Create Approval Request'), findsNothing);
  });

  testWidgets('creating a request posts to /workspaces/:id/approvals and reloads the list', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 1;
    var loadCount = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      loadCount++;
      if (loadCount == 1) return jsonResponse('{"approvals":[]}');
      return jsonResponse('{"approvals":[{"id":9,"title":"New request","status":"pending","requested_by":1}]}');
    });
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });
    final provider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpTab(tester, provider, api);
    await tester.enterText(find.byType(TextField).first, 'New request');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Approval Request'));
    await tester.pumpAndSettle();

    expect(sentBody!['title'], 'New request');
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/approvals'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    expect(find.text('New request'), findsOneWidget);
  });

  testWidgets('tapping approve calls respond with the approved action', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 1;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"approvals":[{"id":9,"title":"Q1 report","status":"pending","requested_by":2}]}',
      ),
    );
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });
    final provider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpTab(tester, provider, api);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(sentBody, {'action': 'approved'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/approvals/9/respond'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
