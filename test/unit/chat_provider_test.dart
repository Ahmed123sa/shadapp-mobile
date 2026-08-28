import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/chat_repository.dart';
import 'package:shadapp_client/providers/chat_provider.dart';
import '../helpers/mock_http_client.dart';

class _FakeMultipartRequest extends Fake implements http.BaseRequest {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ChatProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(_FakeMultipartRequest());
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = ChatProvider(repository: ChatRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchWorkspace returns the raw envelope', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"workspace":{"id":4},"nextMeeting":null,"nextPayment":null}'),
    );

    final data = await provider.fetchWorkspace(4);

    expect(data['workspace']['id'], 4);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/4'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('fetchMessages returns the message list', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"messages":[{"id":1},{"id":2}]}'),
    );

    final messages = await provider.fetchMessages(4);

    expect(messages, hasLength(2));
  });

  test('markRead posts to /workspaces/:id/chat/mark-read', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await provider.markRead(4);

    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/4/chat/mark-read'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('sendMessage forwards requiresAction and replyToId', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await provider.sendMessage(4, 'hi', requiresAction: true, replyToId: 3);

    expect(sentBody, {'message': 'hi', 'requires_action': true, 'reply_to_id': 3});
  });

  test('sendMessage sends a plain body when neither optional flag is set', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await provider.sendMessage(4, 'hi');

    expect(sentBody, {'message': 'hi'});
  });

  test('editMessage PUTs to /chat/:id', () async {
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await provider.editMessage(9, 'new text');

    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/chat/9'))),
        headers: any(named: 'headers'), body: jsonEncode({'message': 'new text'}))).called(1);
  });

  test('requireAction PATCHes /chat/:id/require-action', () async {
    when(() => httpClient.patch(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await provider.requireAction(9);

    verify(() => httpClient.patch(any(that: predicate<Uri>((u) => u.path.endsWith('/chat/9/require-action'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('uploadFile sends a multipart request to /workspaces/:id/chat', () async {
    final tmp = await File('${Directory.systemTemp.path}/chat_provider_upload_test.png').create();
    await tmp.writeAsBytes([0, 1, 2]);
    addTearDown(() => tmp.delete());

    when(() => httpClient.send(any())).thenAnswer((inv) async {
      final req = inv.positionalArguments[0] as http.BaseRequest;
      expect(req.url.path, endsWith('/workspaces/4/chat'));
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
    });

    await provider.uploadFile(4, tmp);

    verify(() => httpClient.send(any())).called(1);
  });

  test('respond posts the action to /chat/:id/respond', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await provider.respond(3, action: 'approved');

    expect(sentBody, {'action': 'approved'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/chat/3/respond'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
