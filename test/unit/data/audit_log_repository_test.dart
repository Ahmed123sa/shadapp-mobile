import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/audit_log_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late AuditLogRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = AuditLogRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetch always includes page, and omits empty filters', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"logs":{"data":[],"last_page":1,"total":0}}'),
    );

    await repo.fetch(page: 2);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/audit-logs') && u.query == 'page=2')),
        headers: any(named: 'headers'))).called(1);
  });

  test('fetch includes search/action/date filters when provided', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"logs":{"data":[]}}'),
    );

    await repo.fetch(search: 'ahmed', action: 'contract', dateFrom: '2026-01-01', dateTo: '2026-01-31', page: 1);

    verify(() => httpClient.get(
          any(
            that: predicate<Uri>((u) =>
                u.queryParameters['search'] == 'ahmed' &&
                u.queryParameters['action'] == 'contract' &&
                u.queryParameters['date_from'] == '2026-01-01' &&
                u.queryParameters['date_to'] == '2026-01-31' &&
                u.queryParameters['page'] == '1'),
          ),
          headers: any(named: 'headers'),
        )).called(1);
  });

  test('returns the raw paginated envelope', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"logs":{"data":[{"id":1}],"last_page":3,"total":25}}'),
    );

    final data = await repo.fetch();

    expect(data['logs']['total'], 25);
    expect(data['logs']['last_page'], 3);
  });
}
