// Characterization test for am/workspace/chat_tab.dart, written BEFORE any
// behavior migration (see docs/state-layer-migration-plan.md, Path D). Locks
// in the screen's CURRENT behavior so later commits that move it onto
// ChatProvider/ContractProvider/MeetingProvider can prove they changed
// nothing.
//
// Not covered here (pre-existing testability gaps, not introduced by this
// test): the file-attachment button (FilePicker.platform is a real platform
// channel with no mock registered under plain `flutter test`) and the
// "meeting found and joinable" branch of the Zoom-link button (reaches
// canLaunchUrl, also an unmocked platform channel — though the surrounding
// try/catch means it fails silently rather than crashing). Both are already
// covered at the repository/provider level by chat_repository_test.dart and
// chat_provider_test.dart.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/reverb_service.dart';
import 'package:shadapp_client/data/chat_repository.dart';
import 'package:shadapp_client/features/am/workspace/chat_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/chat_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Map<String, dynamic> msg(int id, {
    required String senderType,
    required int senderId,
    required String senderName,
    required String message,
    String type = 'text',
    dynamic approvalId,
    bool requiresAction = false,
    bool actionTaken = false,
  }) =>
      {
        'id': id,
        'message': message,
        'sender_type': senderType,
        'sender_id': senderId,
        'sender': {'name': senderName},
        'type': type,
        'approval_id': approvalId,
        'requires_action': requiresAction,
        'action_taken': actionTaken,
        'created_at': '2026-01-01T10:00:00Z',
      };

  final clientMsg = msg(1, senderType: 'App\\Models\\Client', senderId: 20, senderName: 'Ali Client', message: 'Hello there');
  final ownMsg = msg(2, senderType: 'App\\Models\\User', senderId: 10, senderName: 'Manager Name', message: 'Own AM message');

  void stubDefaultGets(MockHttpClient httpClient, {List<dynamic>? messages, List<dynamic>? contracts, List<dynamic>? meetings}) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/chat')) {
        return jsonResponse(jsonEncode({'messages': messages ?? [clientMsg, ownMsg]}));
      }
      if (uri.path.endsWith('/contracts')) {
        return jsonResponse(jsonEncode({'contracts': contracts ?? []}));
      }
      if (uri.path.endsWith('/meetings')) {
        return jsonResponse(jsonEncode({'meetings': meetings ?? []}));
      }
      return jsonResponse(jsonEncode({
        'workspace': {'client': {'contact_person': 'Ali Client', 'avatar_url': null, 'client_type': null}},
        'nextMeeting': null,
        'nextPayment': null,
      }));
    });
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/mark-read'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((_) async => jsonResponse('{}'));
  }

  Future<void> pumpTab(WidgetTester tester, dynamic api, {String wsStatus = 'active'}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatTab(
          workspaceId: 5,
          wsStatus: wsStatus,
          api: api,
          // Must be wired to the same mocked `api`, otherwise it falls back
          // to a real ChatProvider() backed by the real ApiClient() singleton
          // and the test hangs on a real network call.
          chatProvider: ChatProvider(repository: ChatRepository(api: api)),
          reverb: ReverbService.forTesting(),
          enablePolling: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads workspace + messages and marks the thread read on init', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient);

    await pumpTab(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5'))),
        headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat'))),
        headers: any(named: 'headers'))).called(1);
    // At least once — initState always chains one mark-read after load, but
    // the message list's initial scroll-to-bottom can also cross the
    // "already at bottom" threshold and fire an extra one via the scroll
    // listener, which isn't the behavior under test here.
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat/mark-read'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(greaterThanOrEqualTo(1));
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('Own AM message'), findsOneWidget);
  });

  testWidgets('shows the locked state when the workspace is not active', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient);

    await pumpTab(tester, api, wsStatus: 'inactive');

    expect(find.text('Chat unavailable — waiting for workspace activation'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no messages', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient, messages: []);

    await pumpTab(tester, api);

    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('super admin sees the read-only indicator and no input bar', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'super_admin';
    api.userId = 99;
    stubDefaultGets(httpClient);

    await pumpTab(tester, api);

    expect(find.text('View chat only'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('sending a plain message posts {message} with no extra fields', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpTab(tester, api);
    await tester.enterText(find.byType(TextField), 'a plain message');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sentBody, {'message': 'a plain message'});
  });

  testWidgets('toggling "Request Client Approval" adds requires_action: true to the send', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpTab(tester, api);
    await tester.tap(find.text('Request Client Approval'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'please approve this');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sentBody, {'message': 'please approve this', 'requires_action': true});
  });

  testWidgets('replying to a message includes reply_to_id in the send', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpTab(tester, api);
    await tester.longPress(find.text('Hello there'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'replying now');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sentBody, {'message': 'replying now', 'reply_to_id': 1});
  });

  testWidgets('editing your own message PUTs the new text to /chat/:id', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpTab(tester, api);
    await tester.longPress(find.text('Own AM message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'edited AM message');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(sentBody, {'message': 'edited AM message'});
    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/chat/2'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  testWidgets('requesting client approval on a message PATCHes /chat/:id/require-action', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient);
    when(() => httpClient.patch(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await pumpTab(tester, api);
    await tester.longPress(find.text('Own AM message'));
    await tester.pumpAndSettle();
    // The input bar's own "Request Client Approval" toggle is still present
    // underneath the action sheet, so plain find.text() is ambiguous here —
    // target the ListTile specifically.
    await tester.tap(find.widgetWithText(ListTile, 'Request Client Approval'));
    await tester.pumpAndSettle();

    verify(() => httpClient.patch(any(that: predicate<Uri>((u) => u.path.endsWith('/chat/2/require-action'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  testWidgets('opening the contracts sheet fetches and lists workspace contracts', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient, contracts: [
      {'id': 1, 'title': 'Service Agreement', 'status': 'sent'},
    ]);

    await pumpTab(tester, api);
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/contracts'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('Service Agreement'), findsOneWidget);
  });

  testWidgets('opening the contracts sheet shows the empty state with no contracts', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient, contracts: []);

    await pumpTab(tester, api);
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();

    expect(find.text('No contracts'), findsOneWidget);
  });

  testWidgets('tapping the Zoom button with no scheduled meeting shows the no-active-meeting snackbar', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.role = 'account_manager';
    api.userId = 10;
    stubDefaultGets(httpClient, meetings: []);

    await pumpTab(tester, api);
    await tester.tap(find.byIcon(Icons.videocam_outlined));
    await tester.pumpAndSettle();

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/meetings'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('No active meeting'), findsOneWidget);
  });
}
