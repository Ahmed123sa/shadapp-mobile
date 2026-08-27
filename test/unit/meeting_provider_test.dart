import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/meeting_repository.dart';
import 'package:shadapp_client/providers/meeting_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late MeetingProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = MeetingProvider(repository: MeetingRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchForWorkspace populates meetings on success', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"meetings":[{"id":1,"title":"Kickoff"}]}'),
    );

    await provider.fetchForWorkspace(5);

    expect(provider.meetings, hasLength(1));
    expect(provider.error, isNull);
  });

  test('fetchForWorkspace records the error on failure', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );

    await provider.fetchForWorkspace(5);

    expect(provider.error, isNotNull);
  });
}
