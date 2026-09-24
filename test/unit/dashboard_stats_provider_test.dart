import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/dashboard_stats_repository.dart';
import 'package:shadapp_client/providers/dashboard_stats_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late DashboardStatsProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = DashboardStatsProvider(repository: DashboardStatsRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchStats delegates to the repository', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"payments":{"pending":7}}'),
    );

    final stats = await provider.fetchStats();

    expect(stats['payments']['pending'], 7);
  });
}
