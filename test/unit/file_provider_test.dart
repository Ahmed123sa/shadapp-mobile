import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/file_repository.dart';
import 'package:shadapp_client/providers/file_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late FileProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = FileProvider(repository: FileRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchWorkspaceFiles delegates to the repository', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"files":[{"id":1}],"definitions":[],"paymentFiles":[]}'),
    );

    final res = await provider.fetchWorkspaceFiles(5);

    expect(res['files'], hasLength(1));
  });

  test('deleteFile delegates to the repository', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await provider.deleteFile(5, 42);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/files/42'))),
        headers: any(named: 'headers'))).called(1);
  });
}
