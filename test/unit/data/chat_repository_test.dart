import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/chat_repository.dart';
import '../../helpers/mock_http_client.dart';

class _FakeMultipartRequest extends Fake implements http.BaseRequest {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ChatRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(_FakeMultipartRequest());
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = ChatRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchWorkspace hits /workspaces/:id and returns the raw envelope', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"workspace":{"id":4,"status":"active"},"nextMeeting":null}'),
    );

    final data = await repo.fetchWorkspace(4);

    expect(data['workspace']['status'], 'active');
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/4'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('fetchMessages unwraps the messages key via safeList', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"messages":[{"id":1,"message":"hi"}]}'),
    );

    final messages = await repo.fetchMessages(4);

    expect(messages, hasLength(1));
    expect((messages.first as Map)['message'], 'hi');
  });

  test('markRead posts to /workspaces/:id/chat/mark-read with an empty body', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.markRead(4);

    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/4/chat/mark-read'))),
        headers: any(named: 'headers'), body: '{}')).called(1);
  });

  test('sendMessage omits reply_to_id when not provided', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.sendMessage(4, 'hello');

    expect(sentBody, {'message': 'hello'});
  });

  test('sendMessage includes reply_to_id when provided', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.sendMessage(4, 'hello', replyToId: 7);

    expect(sentBody, {'message': 'hello', 'reply_to_id': 7});
  });

  test('editMessage PUTs to /chat/:id', () async {
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.editMessage(9, 'edited text');

    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/chat/9'))),
        headers: any(named: 'headers'), body: jsonEncode({'message': 'edited text'}))).called(1);
  });

  test('requireAction PATCHes /chat/:id/require-action', () async {
    when(() => httpClient.patch(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.requireAction(9);

    verify(() => httpClient.patch(any(that: predicate<Uri>((u) => u.path.endsWith('/chat/9/require-action'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('uploadFile sends a multipart request to /workspaces/:id/chat', () async {
    final tmp = await File('${Directory.systemTemp.path}/chat_upload_test.png').create();
    await tmp.writeAsBytes([0, 1, 2]);
    addTearDown(() => tmp.delete());

    when(() => httpClient.send(any())).thenAnswer((inv) async {
      final req = inv.positionalArguments[0] as http.BaseRequest;
      expect(req.url.path, endsWith('/workspaces/4/chat'));
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
    });

    await repo.uploadFile(4, tmp);

    verify(() => httpClient.send(any())).called(1);
  });

  test('respond omits reason when not provided', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.respond(3, action: 'approved');

    expect(sentBody, {'action': 'approved'});
  });

  test('respond includes reason for edit_requested', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.respond(3, action: 'edit_requested', reason: 'please fix the date');

    expect(sentBody, {'action': 'edit_requested', 'reason': 'please fix the date'});
  });
}
