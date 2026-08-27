import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/signature_repository.dart';
import 'package:shadapp_client/providers/signature_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late SignatureProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = SignatureProvider(repository: SignatureRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('saveText delegates to the repository', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await provider.saveText(9, 'Ahmed Ali');

    expect(sentBody, {'signature': 'Ahmed Ali'});
  });

  test('deleteSignature delegates to the repository', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await provider.deleteSignature(9);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/sign'))),
        headers: any(named: 'headers'))).called(1);
  });
}
