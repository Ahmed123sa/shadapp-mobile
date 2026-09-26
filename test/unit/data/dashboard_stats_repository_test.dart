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

  // pending-approvals-plan.md ك5 — sa_approvals_page.dart's single-request
  // replacement for its old per-client-workspace N+1 loop.
  test('fetchPendingApprovals hits /dashboard/pending-approvals with the given limit', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"awaiting_you":{"contracts":[],"payments":[]},"awaiting_client":{"contracts":[],"approvals":[]}}'),
    );

    final result = await repo.fetchPendingApprovals(limit: 75);

    expect(result['awaiting_you'], isNotNull);
    verify(() => httpClient.get(
          any(that: predicate<Uri>((u) => u.path.endsWith('/dashboard/pending-approvals') && u.queryParameters['limit'] == '75')),
          headers: any(named: 'headers'),
        )).called(1);
  });

  test('fetchPendingApprovals defaults to the endpoint-max limit of 200', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"awaiting_you":{"contracts":[],"payments":[]},"awaiting_client":{"contracts":[],"approvals":[]}}'),
    );

    await repo.fetchPendingApprovals();

    verify(() => httpClient.get(
          any(that: predicate<Uri>((u) => u.queryParameters['limit'] == '200')),
          headers: any(named: 'headers'),
        )).called(1);
  });
}
