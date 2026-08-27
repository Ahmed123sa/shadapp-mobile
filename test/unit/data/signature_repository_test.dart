import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/signature_repository.dart';
import '../../helpers/mock_http_client.dart';

class _FakeMultipartRequest extends Fake implements http.BaseRequest {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late SignatureRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(_FakeMultipartRequest());
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = SignatureRepository(api: buildTestApiClient(client: httpClient));
  });

  test('deleteSignature calls DELETE on /clients/:id/sign', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.deleteSignature(9);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/sign'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('uploadImage sends a multipart request to /clients/:id/sign', () async {
    final tmp = await File('${Directory.systemTemp.path}/sig_test.png').create();
    await tmp.writeAsBytes([0, 1, 2]);
    addTearDown(() => tmp.delete());

    when(() => httpClient.send(any())).thenAnswer((inv) async {
      final req = inv.positionalArguments[0] as http.BaseRequest;
      expect(req.url.path, endsWith('/clients/9/sign'));
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
    });

    await repo.uploadImage(9, tmp);

    verify(() => httpClient.send(any())).called(1);
  });

  test('saveText posts the signature text', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.saveText(9, 'Ahmed Ali');

    expect(sentBody, {'signature': 'Ahmed Ali'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/sign'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
