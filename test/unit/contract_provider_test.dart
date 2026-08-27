import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/providers/contract_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ContractProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = ContractProvider(api: buildTestApiClient(client: httpClient));
  });

  test('fetchContracts(workspaceId) hits the workspace-scoped endpoint', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"contracts":[{"id":1}]}'),
    );

    await provider.fetchContracts(5);

    final captured = verify(() => httpClient.get(captureAny(), headers: any(named: 'headers'))).captured;
    expect((captured.single as Uri).path, contains('/workspaces/5/contracts'));
    expect(provider.contracts, hasLength(1));
  });

  test('fetchAllContracts hits the flat endpoint', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"contracts":[{"id":1},{"id":2}]}'),
    );

    await provider.fetchAllContracts();

    final captured = verify(() => httpClient.get(captureAny(), headers: any(named: 'headers'))).captured;
    expect((captured.single as Uri).path, endsWith('/contracts'));
    expect(provider.contracts, hasLength(2));
  });

  // safeList() (used internally) must tolerate a paginated {"data": [...]}
  // shape as well as a bare array, since not every endpoint paginates.
  test('handles a paginated {data: [...]} response shape via safeList', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"contracts":{"data":[{"id":1}]}}'),
    );

    await provider.fetchAllContracts();

    expect(provider.contracts, hasLength(1));
  });

  test('records the error on failure without throwing', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"nope"}', 500),
    );

    await provider.fetchAllContracts();

    expect(provider.error, isNotNull);
  });
}
