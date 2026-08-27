import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/settings_repository.dart';
import 'package:shadapp_client/providers/settings_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late SettingsProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = SettingsProvider(repository: SettingsRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchClient delegates to the repository and returns the unwrapped client', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":9,"contact_person":"Sara"}}'),
    );

    final client = await provider.fetchClient(9);

    expect(client['contact_person'], 'Sara');
  });

  test('updateClientProfile delegates to the repository', () async {
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await provider.updateClientProfile(9, {'contact_person': 'New'});

    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/profile'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
