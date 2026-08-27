import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/file_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late FileRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = FileRepository(api: buildTestApiClient(client: httpClient));
  });

  test('createDefinition posts the body to /workspaces/:id/document-definitions', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"definition":{"id":1}}');
    });

    final res = await repo.createDefinition(5, {'name': 'Passport', 'is_required': true});

    expect(sentBody!['name'], 'Passport');
    expect(res['definition']['id'], 1);
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/document-definitions'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('deleteDefinition calls DELETE on the definition endpoint', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.deleteDefinition(5, 3);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/document-definitions/3'))),
        headers: any(named: 'headers'))).called(1);
  });
}
