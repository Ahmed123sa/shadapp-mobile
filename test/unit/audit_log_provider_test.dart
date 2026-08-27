import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/audit_log_repository.dart';
import 'package:shadapp_client/providers/audit_log_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late AuditLogProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = AuditLogProvider(repository: AuditLogRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetch hits /audit-logs and returns the raw envelope', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"logs":{"data":[{"id":1}],"total":1}}'),
    );

    final data = await provider.fetch(page: 1);

    expect(data['logs']['total'], 1);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/audit-logs'))),
        headers: any(named: 'headers'))).called(1);
  });
}
