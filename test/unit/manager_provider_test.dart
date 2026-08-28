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

  test('fetchManagerRaw delegates to the repository', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"manager":{"id":5,"name":"Ahmed"},"clients":[]}'),
    );

    final raw = await provider.fetchManagerRaw(5);

    expect(raw['manager']['name'], 'Ahmed');
  });

  test('fetchManagerStats delegates to the repository', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients_count":2}'),
    );

    final stats = await provider.fetchManagerStats(5);

    expect(stats['clients_count'], 2);
  });

  test('fetchAllManagersRaw returns the raw manager list without touching managers', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"managers":[{"id":1,"managed_clients_count":3}]}'),
    );

    final raw = await provider.fetchAllManagersRaw();

    expect(raw, hasLength(1));
    expect(raw.first['managed_clients_count'], 3);
    expect(provider.managers, isEmpty);
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
