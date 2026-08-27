import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/dashboard_repository.dart';
import 'package:shadapp_client/providers/dashboard_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late DashboardProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = DashboardProvider(repository: DashboardRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchBadgeCounts delegates to the repository', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"notifications":5}'),
    );

    final counts = await provider.fetchBadgeCounts();

    expect(counts['notifications'], 5);
  });
}
