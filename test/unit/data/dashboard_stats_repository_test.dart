import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/dashboard_stats_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late DashboardStatsRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = DashboardStatsRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchStats hits /dashboard/stats and returns the raw map', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients":{"total":42},"contracts":{"active":18,"awaiting_client":5}}'),
    );

    final stats = await repo.fetchStats();

    expect(stats['clients']['total'], 42);
    expect(stats['contracts']['active'], 18);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/dashboard/stats'))),
        headers: any(named: 'headers'))).called(1);
  });
}
