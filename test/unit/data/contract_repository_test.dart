import 'dart:convert';
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

  test('fetchForWorkspacePaginatedRaw loops through every page and combines results', () async {
    var call = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      call++;
      final uri = inv.positionalArguments[0] as Uri;
      expect(uri.query, 'page=$call');
      if (call == 1) {
        return jsonResponse('{"contracts":{"data":[{"id":1}],"last_page":2}}');
      }
      return jsonResponse('{"contracts":{"data":[{"id":2}],"last_page":2}}');
    });

    final all = await repo.fetchForWorkspacePaginatedRaw(5);

    expect(all, hasLength(2));
    expect(call, 2);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/contracts'))),
        headers: any(named: 'headers'))).called(2);
  });

  test('fetchWorkspace hits /workspaces/:id', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"workspace":{"id":5}}'),
    );

    final data = await repo.fetchWorkspace(5);

    expect(data['workspace']['id'], 5);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('clientAction omits reason when not provided', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.clientAction(9, 'approved');

    expect(sentBody, {'action': 'approved'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/contracts/9/client-action'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('clientAction includes reason for edit_requested', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.clientAction(9, 'edit_requested', reason: 'please fix dates');

    expect(sentBody, {'action': 'edit_requested', 'reason': 'please fix dates'});
  });

  test('performAction posts to /contracts/:id/:action', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.performAction(9, 'archive');

    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/contracts/9/archive'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('delete calls DELETE on the contract endpoint', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.delete(9);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/contracts/9'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('fetchCurrentUser hits /auth/me', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"user":{"id":1,"signature_data":"Ahmed"}}'),
    );

    final data = await repo.fetchCurrentUser();

    expect(data['user']['signature_data'], 'Ahmed');
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/auth/me'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('companyApprove sends an empty body when no signature is given', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.companyApprove(9);

    expect(sentBody, {});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/contracts/9/company-approve'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('companyApprove sends the signature when provided', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.companyApprove(9, signature: 'Ahmed Ali');

    expect(sentBody, {'signature': 'Ahmed Ali'});
  });

  test('fetchClauseTemplates hits /contract-clause-templates', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"templates":[{"id":1}]}'),
    );

    final data = await repo.fetchClauseTemplates();

    expect(data['templates'], hasLength(1));
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/contract-clause-templates'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('create posts the payload to /workspaces/:id/contracts', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"contract":{"id":42}}'),
    );

    final res = await repo.create(5, {'title': 'New contract'});

    expect(res['contract']['id'], 42);
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/contracts'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('update puts the payload to /contracts/:id', () async {
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.update(9, {'title': 'Renamed'});

    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/contracts/9'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('send posts to /contracts/:id/send', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.send(9);

    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/contracts/9/send'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
