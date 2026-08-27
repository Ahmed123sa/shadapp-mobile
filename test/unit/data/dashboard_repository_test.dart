import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/dashboard_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late DashboardRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = DashboardRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchBadgeCounts hits /badge-counts and returns the raw map', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"notifications":3,"chat":1}'),
    );

    final counts = await repo.fetchBadgeCounts();

    expect(counts['notifications'], 3);
    expect(counts['chat'], 1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/badge-counts'))),
        headers: any(named: 'headers'))).called(1);
  });
}
