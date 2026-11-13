// Picking a file in the chat composer no longer sends it at once: it waits as a
// chip (with a way to remove it) and goes out with the text when the user taps
// send. If the send fails, the file and the text come back.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/chat_repository.dart';
import 'package:shadapp_client/features/chat/chat_shared.dart';
import 'package:shadapp_client/providers/chat_provider.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/pump_app.dart';

class _FakeRequest extends Fake implements http.BaseRequest {}

void main() {
  late MockHttpClient httpClient;
  late ChatProvider provider;
  late File file;
  late TextEditingController controller;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(_FakeRequest());
  });

  setUp(() async {
    httpClient = MockHttpClient();
    provider = ChatProvider(repository: ChatRepository(api: buildTestApiClient(client: httpClient)));
    file = await File('${Directory.systemTemp.path}/chat_attachment_test.jpg').create();
    await file.writeAsBytes(List.filled(2048, 1));
    controller = TextEditingController();
  });

  tearDown(() async {
    controller.dispose();
    if (await file.exists()) await file.delete();
  });

  /// Answers the multipart send and keeps the request it was given.
  List<http.MultipartRequest> captureMultipart({int status = 200}) {
    final sent = <http.MultipartRequest>[];
    when(() => httpClient.send(any())).thenAnswer((inv) async {
      sent.add(inv.positionalArguments[0] as http.MultipartRequest);
      return http.StreamedResponse(Stream.value(utf8.encode(status == 200 ? '{}' : '{"message":"no"}')), status);
    });
    return sent;
  }

  Future<void> send({
    File? picked,
    Map<String, dynamic>? replyTo,
    bool requiresAction = false,
    void Function(File, String, bool)? onFailed,
    VoidCallback? clearFile,
  }) =>
      chatSend(
        controller: controller,
        wsId: 4,
        replyTo: replyTo,
        chatProvider: provider,
        setState: (fn) => fn(),
        clearReplyTo: () {},
        load: () {},
        markRead: () {},
        consumeRequiresAction: () => requiresAction,
        logTag: 'test',
        file: picked,
        clearFile: clearFile,
        onFileFailed: onFailed,
      );

  group('sending the picked file', () {
    test('goes out with the text as one message', () async {
      final sent = captureMultipart();
      controller.text = 'Here is the draft';

      await send(picked: file);

      expect(sent, hasLength(1));
      expect(sent.single.url.path, endsWith('/workspaces/4/chat'));
      expect(sent.single.fields['message'], 'Here is the draft');
      expect(sent.single.files.single.field, 'file');
      expect(controller.text, isEmpty);
    });

    test('a file alone is enough, and sends no empty message field', () async {
      final sent = captureMultipart();

      await send(picked: file);

      expect(sent, hasLength(1));
      expect(sent.single.fields.containsKey('message'), isFalse);
    });

    test('carries the approval switch and the reply with it', () async {
      final sent = captureMultipart();

      await send(picked: file, requiresAction: true, replyTo: {'id': 9});

      expect(sent.single.fields['requires_action'], '1');
      expect(sent.single.fields['reply_to_id'], '9');
    });

    test('is released from the composer once taken', () async {
      captureMultipart();
      var cleared = false;

      await send(picked: file, clearFile: () => cleared = true);

      expect(cleared, isTrue);
    });

    test('a failed send hands the file, the text and the switch back', () async {
      captureMultipart(status: 500);
      controller.text = 'Please look';
      File? backFile;
      String? backText;
      bool? backSwitch;

      await send(picked: file, requiresAction: true, onFailed: (f, t, r) {
        backFile = f;
        backText = t;
        backSwitch = r;
      });

      expect(backFile, same(file));
      expect(backText, 'Please look');
      expect(backSwitch, isTrue);
    });
  });

  group('text only is unchanged', () {
    test('sends a normal JSON message, not a multipart one', () async {
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => jsonResponse('{}'));
      controller.text = 'hello';

      await send();

      verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/4/chat'))),
          headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
      verifyNever(() => httpClient.send(any()));
    });

    test('nothing to send when there is no text and no file', () async {
      await send();

      verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
      verifyNever(() => httpClient.send(any()));
    });
  });

  group('LxPendingAttachment', () {
    testWidgets('shows the name and size, and removes on tap', (tester) async {
      var removed = 0;
      await pumpWithLocalizations(tester, LxPendingAttachment(file: file, onRemove: () => removed++));

      expect(find.text('chat_attachment_test.jpg'), findsOneWidget);
      expect(find.text('2 KB'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('chat-pending-remove')));
      await tester.pump();

      expect(removed, 1);
    });

    testWidgets('its remove button is named for screen readers', (tester) async {
      await pumpWithLocalizations(tester, LxPendingAttachment(file: file, onRemove: () {}));

      expect(find.byTooltip('Remove attachment'), findsOneWidget);
    });
  });
}
