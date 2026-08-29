// Characterization test for chat/chat_page.dart (client-side chat), written
// BEFORE any behavior migration (see docs/state-layer-migration-plan.md,
// Path D). Locks in the screen's CURRENT behavior so later commits that move
// it onto ChatProvider/ContractProvider/MeetingProvider can prove they
// changed nothing.
//
// Not covered here (pre-existing testability gaps, not introduced by this
// test): the file-attachment button (FilePicker.platform is a real platform
// channel with no mock registered under plain `flutter test`) and the
// "meeting found and joinable" branch of the Zoom-link button (reaches
// canLaunchUrl, also an unmocked platform channel — though the surrounding
// try/catch means it fails silently rather than crashing). Both are already
// covered at the repository/provider level by chat_repository_test.dart,
// chat_provider_test.dart, and contract_provider_test.dart.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/reverb_service.dart';
import 'package:shadapp_client/data/chat_repository.dart';
import 'package:shadapp_client/features/chat/chat_page.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/data/meeting_repository.dart';
import 'package:shadapp_client/providers/chat_provider.dart';
import 'package:shadapp_client/providers/contract_provider.dart';
import 'package:shadapp_client/providers/meeting_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Map<String, dynamic> msg(int id, {
    required String senderType,
    required int senderId,
    required String senderName,
    String? message,
    String type = 'text',
    dynamic approvalId,
    bool requiresAction = false,
    bool actionTaken = false,
    Map<String, dynamic>? contract,
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
        'contract': contract,
        'created_at': '2026-01-01T10:00:00Z',
      };

  final clientOwnMsg = msg(1, senderType: 'App\\Models\\Client', senderId: 10, senderName: 'Ali Client', message: 'My own message');
  final amMsg = msg(2, senderType: 'App\\Models\\User', senderId: 99, senderName: 'AM Manager', message: 'Hello from AM');

  void stubDefaultGets(MockHttpClient httpClient, {
    List<dynamic>? messages,
    List<dynamic>? contracts,
    List<dynamic>? meetings,
    String workspaceStatus = 'active',
  }) {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      if (uri.path.endsWith('/chat')) {
        return jsonResponse(jsonEncode({'messages': messages ?? [clientOwnMsg, amMsg]}));
      }
      if (uri.path.endsWith('/contracts')) {
        return jsonResponse(jsonEncode({'contracts': contracts ?? []}));
      }
      if (uri.path.endsWith('/meetings')) {
        return jsonResponse(jsonEncode({'meetings': meetings ?? []}));
      }
      return jsonResponse(jsonEncode({
        'workspace': {'status': workspaceStatus, 'manager': {'name': 'AM Manager', 'avatar_url': null}},
        'nextMeeting': null,
        'nextPayment': null,
      }));
    });
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/mark-read'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((_) async => jsonResponse('{}'));
  }

  Future<ReverbService> pumpPage(WidgetTester tester, dynamic api, {ReverbService? reverb}) async {
    final reverbService = reverb ?? ReverbService.forTesting();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatPage(
          api: api,
          chatProvider: ChatProvider(repository: ChatRepository(api: api)),
          contractProvider: ContractProvider(api: api),
          meetingProvider: MeetingProvider(repository: MeetingRepository(api: api)),
          reverb: reverbService,
          enablePolling: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return reverbService;
  }

  testWidgets('loads workspace + messages and marks the thread read on init', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    stubDefaultGets(httpClient);

    await pumpPage(tester, api);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5'))),
        headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat'))),
        headers: any(named: 'headers'))).called(1);
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat/mark-read'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(greaterThanOrEqualTo(1));
    expect(find.text('My own message'), findsOneWidget);
    expect(find.text('Hello from AM'), findsOneWidget);
  });

  testWidgets('a contract status change over reverb reloads the messages', (tester) async {
    // Regression test for docs/state-layer-migration-plan.md, بند ٥'s
    // "اكتشاف جانبي": chat_tab.dart (AM side) has always listened for this
    // reverb event to refresh, but chat_page.dart (client side) didn't wire
    // an equivalent handler until now — a contract update while the client
    // had the chat open would go unreflected until the next fallback poll.
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    stubDefaultGets(httpClient);

    final reverb = await pumpPage(tester, api);
    // initState's own _load() already fetched /chat once.
    verify(() => httpClient.get(
      any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat'))),
      headers: any(named: 'headers'),
    )).called(1);

    reverb.onContractStatusChanged?.call();
    await tester.pumpAndSettle();

    // Confirmed empirically: mocktail's verify() consumes the interactions
    // it checks, so this second verify() only counts calls that happened
    // AFTER the one above — called(1) here means exactly one more /chat
    // fetch happened, i.e. the handler actually reloaded.
    verify(() => httpClient.get(
      any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat'))),
      headers: any(named: 'headers'),
    )).called(1);
  });

  testWidgets('shows the locked state when the workspace is not active', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    stubDefaultGets(httpClient, workspaceStatus: 'pending');

    await pumpPage(tester, api);

    expect(find.text('Chat is unavailable — waiting for workspace activation after payment'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no messages', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    stubDefaultGets(httpClient, messages: []);

    await pumpPage(tester, api);

    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('sending a plain message posts {message} with no reply_to_id', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    stubDefaultGets(httpClient);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpPage(tester, api);
    await tester.enterText(find.byType(TextField), 'a plain message');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sentBody, {'message': 'a plain message'});
  });

  testWidgets('replying to a message includes reply_to_id in the send', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    stubDefaultGets(httpClient);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/chat'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpPage(tester, api);
    await tester.longPress(find.text('Hello from AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'replying now');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sentBody, {'message': 'replying now', 'reply_to_id': 2});
  });

  testWidgets('editing your own message PUTs the new text to /chat/:id', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    stubDefaultGets(httpClient);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpPage(tester, api);
    await tester.longPress(find.text('My own message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'edited message');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(sentBody, {'message': 'edited message'});
    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/chat/1'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  testWidgets('approving a contract card posts action=approved to /contracts/:id/client-action', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    final contractMsg = msg(3, senderType: 'App\\Models\\Client', senderId: 10, senderName: 'Ali Client',
        contract: {'id': 7, 'status': 'sent', 'title': 'Service Agreement', 'clauses': []});
    stubDefaultGets(httpClient, messages: [contractMsg]);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/contracts/7/client-action'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpPage(tester, api);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(sentBody, {'action': 'approved'});
  });

  testWidgets('approving a pending message posts action=approved to /chat/:id/respond', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    final pendingMsg = msg(4, senderType: 'App\\Models\\User', senderId: 99, senderName: 'AM Manager',
        message: 'Please approve this', requiresAction: true);
    stubDefaultGets(httpClient, messages: [pendingMsg]);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/chat/4/respond'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpPage(tester, api);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(sentBody, {'action': 'approved'});
  });

  testWidgets('requesting an edit on a pending message posts action + reason and shows the toast', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    final pendingMsg = msg(4, senderType: 'App\\Models\\User', senderId: 99, senderName: 'AM Manager',
        message: 'Please approve this', requiresAction: true);
    stubDefaultGets(httpClient, messages: [pendingMsg]);
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/chat/4/respond'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await pumpPage(tester, api);
    await tester.tap(find.text('Request Edit'));
    await tester.pumpAndSettle();
    // The main chat input bar's TextField is still in the tree underneath
    // the dialog, so target the dialog's own TextField specifically.
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'please change the color',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
    await tester.pumpAndSettle();

    expect(sentBody, {'action': 'edit_requested', 'reason': 'please change the color'});
    expect(find.text('Edit requested'), findsOneWidget);
  });

  testWidgets('opening the contracts sheet fetches and lists workspace contracts', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    stubDefaultGets(httpClient, contracts: [
      {'id': 1, 'title': 'Service Agreement', 'status': 'sent'},
    ]);

    await pumpPage(tester, api);
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/contracts'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('Service Agreement'), findsOneWidget);
  });

  testWidgets('opening the contracts sheet shows the empty state with no contracts', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    stubDefaultGets(httpClient, contracts: []);

    await pumpPage(tester, api);
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();

    expect(find.text('No Contracts'), findsOneWidget);
  });

  testWidgets('tapping the Zoom button with no scheduled meeting shows the no-active-meeting snackbar', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    api.userId = 10;
    api.workspaceId = 5;
    stubDefaultGets(httpClient, meetings: []);

    await pumpPage(tester, api);
    await tester.tap(find.byIcon(Icons.videocam_outlined));
    await tester.pumpAndSettle();

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/meetings'))),
        headers: any(named: 'headers'))).called(1);
    expect(find.text('No active meeting'), findsOneWidget);
  });
}
