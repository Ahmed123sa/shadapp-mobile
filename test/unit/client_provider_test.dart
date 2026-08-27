import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
    provider = ClientProvider(api: buildTestApiClient(client: httpClient));
  });

  test('fetchClients populates clients on success', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients":[{"id":1,"company_name":"Acme"}]}'),
    );

    await provider.fetchClients();

    expect(provider.clients, hasLength(1));
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
}
