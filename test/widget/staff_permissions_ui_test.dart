// PLAN_2 ف٦ — a company staff member only does on a client what
// `staffPermissions` (from GET /workspaces/{id} → my_staff_permissions) allows.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/reverb_service.dart';
import 'package:shadapp_client/data/approval_repository.dart';
import 'package:shadapp_client/data/chat_repository.dart';
import 'package:shadapp_client/data/meeting_repository.dart';
import 'package:shadapp_client/features/am/workspace/approvals_tab.dart';
import 'package:shadapp_client/features/am/workspace/chat_tab.dart';
import 'package:shadapp_client/features/am/workspace/meetings_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/approval_provider.dart';
import 'package:shadapp_client/providers/chat_provider.dart';
import 'package:shadapp_client/providers/contract_provider.dart';
import 'package:shadapp_client/providers/meeting_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() => registerFallbackValue(Uri.parse('http://localhost')));

  dynamic staffApi(MockHttpClient http, Map<String, bool>? perms) {
    final api = buildTestApiClient(client: http);
    api.role = 'staff_member';
    api.userId = 7;
    api.staffPermissions = perms;
    return api;
  }

  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  void stubGets(MockHttpClient http, {String meetingsJson = '{"meetings":[]}'}) {
    when(() => http.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path.endsWith('/chat')) return jsonResponse(jsonEncode({'messages': []}));
      if (path.endsWith('/approvals')) return jsonResponse('{"approvals":[]}');
      if (path.endsWith('/meetings')) return jsonResponse(meetingsJson);
      return jsonResponse(jsonEncode({'workspace': {'client': {'contact_person': 'Ali'}}}));
    });
    when(() => http.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((_) async => jsonResponse('{}'));
  }

  Future<void> pumpChat(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(host(ChatTab(
      workspaceId: 5,
      wsStatus: 'active',
      api: api,
      chatProvider: ChatProvider(repository: ChatRepository(api: api)),
      contractProvider: ContractProvider(api: api),
      meetingProvider: MeetingProvider(repository: MeetingRepository(api: api)),
      reverb: ReverbService.forTesting(),
      enablePolling: false,
    )));
    await tester.pumpAndSettle();
  }

  Map<String, bool> perms({bool send = true, bool request = true, bool join = true}) => {
        'can_view_chat': true, 'can_send_chat': send,
        'can_view_approvals': true, 'can_request_approvals': request,
        'can_view_meetings': true, 'can_join_meetings': join,
      };

  testWidgets('chat: view-only staff gets no composer, just a note', (tester) async {
    final http = MockHttpClient();
    stubGets(http);
    await pumpChat(tester, staffApi(http, perms(send: false)));

    expect(find.byKey(const ValueKey('chat-read-only')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('chat: staff who may send keeps the composer', (tester) async {
    final http = MockHttpClient();
    stubGets(http);
    await pumpChat(tester, staffApi(http, perms()));

    expect(find.byKey(const ValueKey('chat-read-only')), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('chat: permissions not loaded yet hides nothing', (tester) async {
    final http = MockHttpClient();
    stubGets(http);
    await pumpChat(tester, staffApi(http, null));

    expect(find.byKey(const ValueKey('chat-read-only')), findsNothing);
  });

  Future<void> pumpApprovals(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(host(ApprovalsTab(
      workspaceId: 5,
      api: api,
      approvalProvider: ApprovalProvider(repository: ApprovalRepository(api: api)),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('approvals: staff who may not request gets no create button', (tester) async {
    final http = MockHttpClient();
    stubGets(http);
    await pumpApprovals(tester, staffApi(http, perms(request: false)));
    expect(find.text('Create Approval Request'), findsNothing);
  });

  testWidgets('approvals: staff who may request sees the create button', (tester) async {
    final http = MockHttpClient();
    stubGets(http);
    await pumpApprovals(tester, staffApi(http, perms()));
    expect(find.text('Create Approval Request'), findsOneWidget);
  });

  String upcomingMeeting() {
    final at = DateTime.now().add(const Duration(minutes: 2)).toUtc().toIso8601String();
    return '{"meetings":[{"id":1,"title":"Kickoff","status":"scheduled","scheduled_at":"$at","link":"https://zoom.us/j/1"}]}';
  }

  Future<void> pumpMeetings(WidgetTester tester, dynamic api) async {
    await tester.pumpWidget(host(MeetingsTab(
      workspaceId: 5,
      api: api,
      meetingProvider: MeetingProvider(repository: MeetingRepository(api: api)),
      contractProvider: ContractProvider(api: api),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('meetings: staff who may not join sees the meeting but no join / copy-link row', (tester) async {
    final http = MockHttpClient();
    stubGets(http, meetingsJson: upcomingMeeting());
    await pumpMeetings(tester, staffApi(http, perms(join: false)));

    expect(find.text('Kickoff'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsNothing);
  });

  testWidgets('meetings: staff who may join sees the join row', (tester) async {
    final http = MockHttpClient();
    stubGets(http, meetingsJson: upcomingMeeting());
    await pumpMeetings(tester, staffApi(http, perms()));

    expect(find.text('Kickoff'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });

  test('ApiClient.staffCan is unrestricted for everyone but staff', () {
    final http = MockHttpClient();
    final mgr = buildTestApiClient(client: http)..role = 'account_manager';
    mgr.staffPermissions = {'can_send_chat': false};
    expect(mgr.staffCan('can_send_chat'), isTrue);

    final staff = staffApi(http, {'can_send_chat': false});
    expect(staff.staffCan('can_send_chat'), isFalse);
    expect(staff.staffCan('can_view_chat'), isFalse); // a key missing from the map is not allowed
  });
}
