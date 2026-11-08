// An approval request carries its files. Before, a file sent in chat with
// "needs approval" showed the client an empty card, and a request raised from
// the Approvals tab never showed its files in the chat.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/api_client.dart';
import 'package:shadapp_client/data/approval_repository.dart';
import 'package:shadapp_client/features/approvals/approvals_page.dart';
import 'package:shadapp_client/features/chat/chat_page_widgets.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/models/approval.dart';
import 'package:shadapp_client/providers/approval_provider.dart';
import '../helpers/mock_http_client.dart';

class _Harness extends StatefulWidget {
  final List<dynamic> messages;
  final ApiClient api;
  const _Harness({required this.messages, required this.api});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(
          children: buildChatMessageList(
            context: context,
            state: this,
            messages: widget.messages,
            api: widget.api,
            onApprove: (_) {},
            onRespondToMessage: (_, __) {},
            onGoToPayments: null,
            onLongPressMessage: (_) {},
          ),
        ),
      );
}

Map<String, dynamic> staffMsg({
  String? message,
  String type = 'text',
  String? fileUrl,
  bool pending = true,
  List<Map<String, dynamic>>? files,
}) =>
    {
      'id': 7,
      'message': message,
      'sender_type': 'App\\Models\\User',
      'sender_id': 99,
      'sender': {'name': 'Manager'},
      'type': type,
      'file_url': fileUrl,
      'requires_action': pending,
      'action_taken': false,
      'approval_id': 3,
      'approval': {'id': 3, 'title': 'x', 'files': files ?? []},
      'created_at': '2026-01-01T10:00:00Z',
    };

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpChat(WidgetTester tester, List<dynamic> messages) async {
    final api = buildTestApiClient(client: MockHttpClient());
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: _Harness(messages: messages, api: api)),
    ));
    await tester.pump();
  }

  const photo = {'id': 11, 'name': '1.jpg', 'size': 35840, 'file_url': 'https://api.example.com/files/a/1.jpg'};
  const brief = {'id': 12, 'name': 'brief.pdf', 'size': 2500000, 'file_url': 'https://api.example.com/files/a/brief.pdf'};

  group('approval card in the chat', () {
    testWidgets('a file-only request shows the file, named from the approval, not an empty card', (tester) async {
      await pumpChat(tester, [
        staffMsg(type: 'file', fileUrl: 'https://api.example.com/files/chat/1.jpg', files: [photo]),
      ]);

      expect(find.text('NEW APPROVAL'), findsOneWidget);
      expect(find.text('1.jpg'), findsOneWidget);
      expect(find.text('35 KB'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('a request raised from the Approvals tab shows its files in the chat', (tester) async {
      await pumpChat(tester, [
        staffMsg(message: 'Brand kit', files: [photo, brief]),
      ]);

      expect(find.text('Brand kit'), findsOneWidget);
      expect(find.text('1.jpg'), findsOneWidget);
      expect(find.text('brief.pdf'), findsOneWidget);
      expect(find.text('2.4 MB'), findsOneWidget);
    });

    testWidgets('a text-only request shows just its text', (tester) async {
      await pumpChat(tester, [staffMsg(message: 'Please approve the logo')]);

      expect(find.text('Please approve the logo'), findsOneWidget);
      expect(find.text('Attachment'), findsNothing);
    });

    testWidgets('an answered request keeps showing its files', (tester) async {
      await pumpChat(tester, [
        staffMsg(message: 'Brand kit', pending: false, files: [brief]),
      ]);

      expect(find.text('brief.pdf'), findsOneWidget);
    });

    testWidgets('an ordinary file message is unchanged', (tester) async {
      await pumpChat(tester, [
        staffMsg(type: 'file', fileUrl: 'https://api.example.com/files/chat/z.pdf', pending: false)..['approval'] = null,
      ]);

      expect(find.text('Attachment'), findsOneWidget);
    });
  });

  group('Approvals tab', () {
    test('the model reads the files, dropping any without a url', () {
      final a = Approval.fromJson({
        'id': 1,
        'files': [
          {'name': 'a.jpg', 'file_url': 'https://x/a.jpg', 'size': 10},
          {'name': 'broken'},
        ],
      });

      expect(a.files, hasLength(1));
      expect(a.files.single['name'], 'a.jpg');
      expect(Approval.fromJson({'id': 2}).files, isEmpty);
    });

    testWidgets('each request lists the files it carries', (tester) async {
      final httpClient = MockHttpClient();
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => jsonResponse(jsonEncode({
          'approvals': [
            {'id': 1, 'title': 'Brand kit', 'status': 'pending', 'files': [photo, brief]},
            {'id': 2, 'title': 'No files here', 'status': 'pending', 'files': []},
          ],
        })),
      );
      final provider = ApprovalProvider(repository: ApprovalRepository(api: buildTestApiClient(client: httpClient)));

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ApprovalsPage(workspaceId: 5, approvalProvider: provider)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Brand kit'), findsOneWidget);
      expect(find.text('1.jpg'), findsOneWidget);
      expect(find.text('brief.pdf'), findsOneWidget);
      expect(find.text('No files here'), findsOneWidget);
      expect(find.text('Attachment'), findsNothing);
    });
  });
}
