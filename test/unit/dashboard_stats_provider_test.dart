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

  // pending-approvals-plan.md ك5.
  test('fetchPendingApprovals delegates to the repository', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"awaiting_you":{"contracts":[],"payments":[]},"awaiting_client":{"contracts":[],"approvals":[]},"counts":{"total":0}}'),
    );

    final result = await provider.fetchPendingApprovals();

    expect(result['counts']['total'], 0);
    verify(() => httpClient.get(
          any(that: predicate<Uri>((u) => u.path.endsWith('/dashboard/pending-approvals'))),
          headers: any(named: 'headers'),
        )).called(1);
  });
}
