import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/manager_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ManagerRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = ManagerRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchAll parses the manager list', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"managers":[{"id":1,"name":"Ahmed"},{"id":2,"name":"Sara"}]}'),
    );

    final managers = await repo.fetchAll();

    expect(managers, hasLength(2));
    expect(managers.first.name, 'Ahmed');
  });

  test('fetchOne unwraps the manager envelope', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"manager":{"id":5,"name":"Ahmed","managed_clients_count":3}}'),
    );

    final manager = await repo.fetchOne(5);

    expect(manager.id, 5);
    expect(manager.managedClientsCount, 3);
  });

  test('fetchOneRaw returns the raw envelope, including sibling clients list', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"manager":{"id":5,"name":"Ahmed"},"clients":[{"id":1,"company_name":"Acme"}]}'),
    );

    final raw = await repo.fetchOneRaw(5);

    expect(raw['manager']['name'], 'Ahmed');
    expect(raw['clients'], hasLength(1));
  });

  test('fetchStats hits /account-managers/:id/stats and returns the raw map', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients_count":4,"total_revenue":"1500"}'),
    );

    final stats = await repo.fetchStats(5);

    expect(stats['clients_count'], 4);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/account-managers/5/stats'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('create posts the body and returns the raw response (credentials included)', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"manager":{"id":9,"name":"New Mgr"},"credentials":{"email":"e@x.com","password":"pw"}}'),
    );

    final res = await repo.create({'name': 'New Mgr'});

    expect(res['manager']['id'], 9);
    expect(res['credentials']['email'], 'e@x.com');
  });

  test('update puts the body to the manager endpoint', () async {
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"manager":{"id":9,"name":"Renamed"}}'),
    );

    final res = await repo.update(9, {'name': 'Renamed'});

    expect(res['manager']['name'], 'Renamed');
  });

  test('delete calls DELETE on the manager endpoint', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.delete(9);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/account-managers/9'))),
        headers: any(named: 'headers'))).called(1);
  });
}
