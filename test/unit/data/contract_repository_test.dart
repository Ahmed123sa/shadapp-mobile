import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/contract_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ContractRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = ContractRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchForWorkspace hits the workspace-scoped endpoint', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"contracts":[{"id":1}]}'),
    );

    final contracts = await repo.fetchForWorkspace(5);

    expect(contracts, hasLength(1));
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/contracts'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('fetchAll hits the flat endpoint', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"contracts":[{"id":1},{"id":2}]}'),
    );

    final contracts = await repo.fetchAll();

    expect(contracts, hasLength(2));
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/contracts'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('handles a paginated {data: [...]} response shape via safeList', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"contracts":{"data":[{"id":1}]}}'),
    );

    final contracts = await repo.fetchAll();

    expect(contracts, hasLength(1));
  });
}
