import 'dart:convert';

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

  test('fetchWorkspaceRaw hits /workspaces/:id', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"workspace":{"id":5,"status":"active"}}'),
    );

    final data = await provider.fetchWorkspaceRaw(5);

    expect(data['workspace']['status'], 'active');
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('fetchWorkspaceContractsPaginatedRaw combines every page', () async {
    var call = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      call++;
      if (call == 1) return jsonResponse('{"contracts":{"data":[{"id":1}],"last_page":2}}');
      return jsonResponse('{"contracts":{"data":[{"id":2}],"last_page":2}}');
    });

    final all = await provider.fetchWorkspaceContractsPaginatedRaw(5);

    expect(all, hasLength(2));
  });

  test('fetchWorkspaceContractsRaw hits the workspace-scoped endpoint without touching provider state', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"contracts":[{"id":1},{"id":2}]}'),
    );

    final contracts = await provider.fetchWorkspaceContractsRaw(5);

    expect(contracts, hasLength(2));
    expect(provider.contracts, isEmpty);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/contracts'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('clientAction posts the action to /contracts/:id/client-action', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await provider.clientAction(9, 'approved');

    expect(sentBody, {'action': 'approved'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/contracts/9/client-action'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('clientAction includes reason only when provided', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await provider.clientAction(9, 'edit_requested', reason: 'please fix the date');

    expect(sentBody, {'action': 'edit_requested', 'reason': 'please fix the date'});
  });

  test('records the error on failure without throwing', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"nope"}', 500),
    );

    await provider.fetchAllContracts();

    expect(provider.error, isNotNull);
  });
}
