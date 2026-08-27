import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/sub_user_repository.dart';
import 'package:shadapp_client/providers/sub_user_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late SubUserProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = SubUserProvider(repository: SubUserRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchForClient delegates to the repository', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"sub_users":[{"id":1,"name":"Sub One"}]}'),
    );

    final subUsers = await provider.fetchForClient(9);

    expect(subUsers, hasLength(1));
  });

  test('delete delegates to the repository', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await provider.delete(3);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/sub-users/3'))),
        headers: any(named: 'headers'))).called(1);
  });
}
