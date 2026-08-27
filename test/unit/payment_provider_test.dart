import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/payment_repository.dart';
import 'package:shadapp_client/providers/payment_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late PaymentProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = PaymentProvider(repository: PaymentRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchForWorkspace populates payments on success', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"payments":[{"id":1}]}'),
    );

    await provider.fetchForWorkspace(5);

    expect(provider.payments, hasLength(1));
    expect(provider.error, isNull);
  });

  test('fetchForWorkspace records the error on failure', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );

    await provider.fetchForWorkspace(5);

    expect(provider.error, isNotNull);
  });

  test('fetchAllPendingRaw combines every page', () async {
    var call = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      call++;
      if (call == 1) return jsonResponse('{"payments":{"data":[{"id":1}],"last_page":2}}');
      return jsonResponse('{"payments":{"data":[{"id":2}],"last_page":2}}');
    });

    final all = await provider.fetchAllPendingRaw();

    expect(all, hasLength(2));
  });
}
