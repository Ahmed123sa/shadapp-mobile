import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/manager_repository.dart';
import 'package:shadapp_client/providers/manager_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ManagerProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = ManagerProvider(repository: ManagerRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchManagers populates managers on success', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"managers":[{"id":1,"name":"Ahmed"}]}'),
    );

    await provider.fetchManagers();

    expect(provider.managers, hasLength(1));
    expect(provider.error, isNull);
  });

  test('fetchManagers records the error on failure', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );

    await provider.fetchManagers();

    expect(provider.error, isNotNull);
  });

  test('deleteManager removes the manager from the in-memory list', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"managers":[{"id":1,"name":"Ahmed"},{"id":2,"name":"Sara"}]}'),
    );
    await provider.fetchManagers();
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await provider.deleteManager(1);

    expect(provider.managers, hasLength(1));
    expect(provider.managers.first.id, 2);
  });
}
