import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/report_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ReportRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = ReportRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetch hits /reports with no query string when every filter is omitted', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"total_clients":1}'),
    );

    await repo.fetch();

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/reports') && u.query == '')),
        headers: any(named: 'headers'))).called(1);
  });

  test('fetch includes only the filters that were provided', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"total_clients":1}'),
    );

    await repo.fetch(dateFrom: '2026-01-01', dateTo: '2026-01-31', clientId: 5, clientType: 'business', managerId: 9);

    verify(() => httpClient.get(
          any(
            that: predicate<Uri>((u) =>
                u.queryParameters['date_from'] == '2026-01-01' &&
                u.queryParameters['date_to'] == '2026-01-31' &&
                u.queryParameters['client_id'] == '5' &&
                u.queryParameters['client_type'] == 'business' &&
                u.queryParameters['manager_id'] == '9'),
          ),
          headers: any(named: 'headers'),
        )).called(1);
  });

  test('returns the raw stats envelope on success', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"total_clients":42,"manager_stats":[{"name":"Sara","revenue":100}]}'),
    );

    final data = await repo.fetch();

    expect(data['total_clients'], 42);
    expect(data['manager_stats'], isA<List>());
  });

  test('converts a failed request into an {error:true, message:...} map instead of throwing', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server Error"}', 500),
    );

    final data = await repo.fetch();

    expect(data['error'], true);
    expect(data['message'], isNotNull);
  });
}
