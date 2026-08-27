import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/report_repository.dart';
import 'package:shadapp_client/providers/report_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ReportProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = ReportProvider(repository: ReportRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetch hits /reports and returns the raw envelope', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"total_clients":7}'),
    );

    final data = await provider.fetch(clientId: 3);

    expect(data['total_clients'], 7);
    verify(() => httpClient.get(
          any(that: predicate<Uri>((u) => u.path.endsWith('/reports') && u.queryParameters['client_id'] == '3')),
          headers: any(named: 'headers'),
        )).called(1);
  });
}
