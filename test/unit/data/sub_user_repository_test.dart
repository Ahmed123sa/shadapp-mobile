import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/sub_user_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late SubUserRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = SubUserRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchForClient hits /clients/:id/sub-users and unwraps the list', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"sub_users":[{"id":1,"name":"Sub One"}]}'),
    );

    final subUsers = await repo.fetchForClient(9);

    expect(subUsers, hasLength(1));
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/sub-users'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('create posts the body and returns the raw response', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"sub_user":{"id":3,"name":"New Sub"}}'),
    );

    final res = await repo.create(9, {'name': 'New Sub', 'email': 'sub@x.com', 'password': 'pw123456'});

    expect(res['sub_user']['id'], 3);
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/sub-users'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('delete calls DELETE on the sub-user endpoint', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.delete(3);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/sub-users/3'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('updatePermissions PATCHes the permissions map wrapped in a "permissions" key', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.patch(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"sub_user":{"id":3,"permissions":{"can_chat":true}}}');
    });

    final res = await repo.updatePermissions(3, {'can_chat': true});

    expect(sentBody, {'permissions': {'can_chat': true}});
    expect(res['sub_user']['permissions']['can_chat'], true);
    verify(() => httpClient.patch(any(that: predicate<Uri>((u) => u.path.endsWith('/sub-users/3/permissions'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
