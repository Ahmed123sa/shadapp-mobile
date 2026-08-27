import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/client_repository.dart';
import 'package:shadapp_client/providers/client_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ClientProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = ClientProvider(repository: ClientRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchClients populates clients on success', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients":[{"id":1,"company_name":"Acme"}]}'),
    );

    await provider.fetchClients();

    expect(provider.clients, hasLength(1));
    expect(provider.clients.first.companyName, 'Acme');
    expect(provider.error, isNull);
    expect(provider.isLoading, isFalse);
  });

  test('fetchClients records the error on failure', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );

    await provider.fetchClients();

    expect(provider.error, isNotNull);
    expect(provider.isLoading, isFalse);
  });

  test('createClient posts the body and returns the raw response, without refetching the list', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":9,"company_name":"New Co"},"credentials":{"email":"e@x.com","password":"pw"}}'),
    );

    final res = await provider.createClient({'company_name': 'New Co'});

    expect(res['credentials']['email'], 'e@x.com');
    expect(provider.clients, isEmpty);
    verifyNever(() => httpClient.get(any(), headers: any(named: 'headers')));
  });

  test('deleteClient removes the client from the in-memory list', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients":[{"id":1,"company_name":"Acme"},{"id":2,"company_name":"Beta"}]}'),
    );
    await provider.fetchClients();
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await provider.deleteClient(1);

    expect(provider.clients, hasLength(1));
    expect(provider.clients.first.id, 2);
  });
}
