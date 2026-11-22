// Closing a finished contract (staff side): behind a menu, with a dialog that
// shows the numbers, blocks while a proof waits for review, lets only the super
// admin close with money owed, and asks for the contract name.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/am/workspace/contracts_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  const running = '{"id":1,"title":"Running deal","status":"completed","value":1000,"currency":"SAR","closed_at":null}';
  const closed =
      '{"id":3,"title":"Old deal","status":"completed","value":3000,"currency":"SAR","closed_at":"2026-11-10T10:00:00Z","closed_outstanding":250}';

  String preview({num paid = 1000, num outstanding = 0, int pending = 0, bool override = false, int scheduled = 0}) =>
      '{"preview":{"contract_id":1,"title":"Running deal","currency":"SAR","total_due":1000,"paid":$paid,'
      '"outstanding":$outstanding,"pending_count":$pending,"pending_amount":0,"scheduled_count":$scheduled,'
      '"scheduled_amount":${scheduled * 300},"unlinked_paid":0,"can_override":$override}}';

  Map<String, dynamic>? lastBody;
  String? lastPostPath;

  MockHttpClient stub({required String contracts, String previewJson = ''}) {
    final httpClient = MockHttpClient();
    lastBody = null;
    lastPostPath = null;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/workspaces/5/contracts') return jsonResponse('{"contracts":[$contracts]}');
      if (path == '/workspaces/5') return jsonResponse('{"workspace":{"status":"active","client":{"client_type":"individual"}}}');
      if (path == '/contracts/1/close-preview') return jsonResponse(previewJson.isEmpty ? preview() : previewJson);
      return jsonResponse('{}');
    });
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      lastPostPath = (inv.positionalArguments[0] as Uri).path;
      final raw = inv.namedArguments[#body];
      lastBody = raw is String && raw.isNotEmpty ? jsonDecode(raw) as Map<String, dynamic> : <String, dynamic>{};
      return jsonResponse('{}');
    });
    return httpClient;
  }

  Future<void> pumpTab(WidgetTester tester, dynamic api, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ContractsTab(workspaceId: 5, api: api)),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('contract-more-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contract-close-1')));
    await tester.pumpAndSettle();
  }

  Finder confirmBtn() => find.byKey(const ValueKey('close-confirm'));
  bool confirmEnabled(WidgetTester tester) => tester.widget<ElevatedButton>(confirmBtn()).onPressed != null;

  testWidgets('the manager closes a fully paid contract only after typing its name', (tester) async {
    final httpClient = stub(contracts: running);
    final api = buildTestApiClient(client: httpClient)..role = 'account_manager';
    await pumpTab(tester, api);

    await openDialog(tester);
    expect(find.byKey(const ValueKey('close-contract-dialog')), findsOneWidget);
    expect(confirmEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const ValueKey('close-name-field')), 'Running');
    await tester.pump();
    expect(confirmEnabled(tester), isFalse);
    await tester.enterText(find.byKey(const ValueKey('close-name-field')), 'Running deal');
    await tester.pump();
    expect(confirmEnabled(tester), isTrue);

    await tester.tap(confirmBtn());
    await tester.pumpAndSettle();

    expect(lastPostPath, '/contracts/1/close');
    expect(lastBody, isEmpty);
    expect(find.text('Contract closed.'), findsOneWidget);
  });

  testWidgets('a balance still owed stops the manager and offers no name field', (tester) async {
    final httpClient = stub(contracts: running, previewJson: preview(paid: 600, outstanding: 400));
    final api = buildTestApiClient(client: httpClient)..role = 'account_manager';
    await pumpTab(tester, api);

    await openDialog(tester);

    expect(find.byKey(const ValueKey('close-manager-block')), findsOneWidget);
    expect(find.byKey(const ValueKey('close-name-field')), findsNothing);
    expect(confirmEnabled(tester), isFalse);
  });

  testWidgets('the super admin closes with money owed only after ticking the box and typing the name', (tester) async {
    final httpClient = stub(contracts: running, previewJson: preview(paid: 600, outstanding: 400, override: true));
    final api = buildTestApiClient(client: httpClient)..role = 'super_admin';
    await pumpTab(tester, api);

    await openDialog(tester);
    await tester.enterText(find.byKey(const ValueKey('close-name-field')), 'Running deal');
    await tester.pump();
    expect(confirmEnabled(tester), isFalse);

    await tester.tap(find.byKey(const ValueKey('close-understood')));
    await tester.pump();
    expect(confirmEnabled(tester), isTrue);

    await tester.tap(confirmBtn());
    await tester.pumpAndSettle();

    expect(lastPostPath, '/contracts/1/close');
    expect(lastBody, {'confirm_outstanding': true});
  });

  testWidgets('a payment waiting for review blocks everyone, even the super admin', (tester) async {
    final httpClient = stub(contracts: running, previewJson: preview(pending: 2, override: true));
    final api = buildTestApiClient(client: httpClient)..role = 'super_admin';
    await pumpTab(tester, api);

    await openDialog(tester);

    expect(find.byKey(const ValueKey('close-pending-block')), findsOneWidget);
    expect(find.byKey(const ValueKey('close-name-field')), findsNothing);
    expect(confirmEnabled(tester), isFalse);
  });

  testWidgets('scheduled installments are announced as removed', (tester) async {
    final httpClient = stub(contracts: running, previewJson: preview(scheduled: 3));
    final api = buildTestApiClient(client: httpClient)..role = 'account_manager';
    await pumpTab(tester, api);

    await openDialog(tester);

    expect(find.textContaining('3 scheduled installment(s)'), findsOneWidget);
  });

  testWidgets('cancelling closes nothing', (tester) async {
    final httpClient = stub(contracts: running);
    final api = buildTestApiClient(client: httpClient)..role = 'account_manager';
    await pumpTab(tester, api);

    await openDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('close-contract-dialog')), findsNothing);
    expect(lastPostPath, isNull);
  });

  testWidgets('an assistant or staff member gets no menu, and a draft has none either', (tester) async {
    final httpClient = stub(contracts: running);
    final api = buildTestApiClient(client: httpClient)..role = 'manager_assistant';
    await pumpTab(tester, api);
    expect(find.byKey(const ValueKey('contract-more-1')), findsNothing);

    final httpClient2 = stub(contracts: '{"id":2,"title":"Draft deal","status":"draft","value":1,"currency":"SAR"}');
    final api2 = buildTestApiClient(client: httpClient2)..role = 'account_manager';
    await pumpTab(tester, api2);
    expect(find.byKey(const ValueKey('contract-more-2')), findsNothing);
  });

  testWidgets('closed contracts leave the list, sit in a collapsed section, and can be reopened after a confirmation', (tester) async {
    final httpClient = stub(contracts: '$running,$closed');
    final api = buildTestApiClient(client: httpClient)..role = 'account_manager';
    await pumpTab(tester, api);

    expect(find.text('Running deal'), findsOneWidget);
    expect(find.text('Old deal'), findsNothing);

    await tester.tap(find.text('Closed contracts (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Old deal'), findsOneWidget);
    expect(find.textContaining('Closed with 250 SAR still owed'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('reopen-contract-3')));
    await tester.tap(find.byKey(const ValueKey('reopen-contract-3')));
    await tester.pumpAndSettle();
    expect(lastPostPath, isNull);

    await tester.tap(find.byKey(const ValueKey('reopen-confirm')));
    await tester.pumpAndSettle();

    expect(lastPostPath, '/contracts/3/reopen');
    expect(find.text('Contract reopened.'), findsOneWidget);
  });

  testWidgets('speaks Arabic', (tester) async {
    final httpClient = stub(contracts: running);
    final api = buildTestApiClient(client: httpClient)..role = 'account_manager';
    await pumpTab(tester, api, locale: const Locale('ar'));

    await openDialog(tester);

    expect(find.text('تنهي "Running deal"؟'), findsOneWidget);
  });
}
