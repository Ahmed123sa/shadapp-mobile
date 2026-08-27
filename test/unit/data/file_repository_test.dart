import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/file_repository.dart';
import '../../helpers/mock_http_client.dart';

class _FakeMultipartRequest extends Fake implements http.BaseRequest {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late FileRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(_FakeMultipartRequest());
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = FileRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchWorkspaceFiles returns the raw composite response', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"files":[{"id":1}],"definitions":[{"id":2}],"paymentFiles":[{"id":3}]}'),
    );

    final res = await repo.fetchWorkspaceFiles(5);

    expect(res['files'], hasLength(1));
    expect(res['definitions'], hasLength(1));
    expect(res['paymentFiles'], hasLength(1));
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/files'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('uploadFile sends a multipart request to the workspace files endpoint', () async {
    final tmp = await File('${Directory.systemTemp.path}/file_repo_test.png').create();
    await tmp.writeAsBytes([0, 1, 2]);
    addTearDown(() => tmp.delete());

    when(() => httpClient.send(any())).thenAnswer((inv) async {
      final req = inv.positionalArguments[0] as http.BaseRequest;
      expect(req.url.path, endsWith('/workspaces/5/files'));
      return http.StreamedResponse(Stream.value(utf8.encode('{"file":{"id":9}}')), 200);
    });

    final res = await repo.uploadFile(5, {'document_definition_id': 2}, file: tmp);

    expect(res['file']['id'], 9);
  });

  test('deleteFile calls DELETE on the workspace file endpoint', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.deleteFile(5, 42);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/files/42'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('reviewFile sends the reason only when rejecting', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.reviewFile(7, action: 'rejected', reason: 'blurry scan');

    expect(sentBody!['action'], 'rejected');
    expect(sentBody!['reason'], 'blurry scan');
  });

  test('reviewFile omits the reason key when approving', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.reviewFile(7, action: 'approved');

    expect(sentBody!.containsKey('reason'), isFalse);
  });
}
