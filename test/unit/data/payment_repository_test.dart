import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/payment_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late PaymentRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = PaymentRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchForWorkspace hits the workspace-scoped endpoint', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"payments":[{"id":1}]}'),
    );

    final payments = await repo.fetchForWorkspace(5);

    expect(payments, hasLength(1));
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('handles a paginated {data: [...]} response shape via safeList', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"payments":{"data":[{"id":1}]}}'),
    );

    final payments = await repo.fetchForWorkspace(5);

    expect(payments, hasLength(1));
  });

  test('fetchPending includes the page number in the query', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"payments":[]}'),
    );

    await repo.fetchPending(page: 2);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/payments/pending') && u.query == 'page=2')),
        headers: any(named: 'headers'))).called(1);
  });
}
