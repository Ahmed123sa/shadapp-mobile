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

  test('fetchForWorkspaceRaw returns the raw meeting maps without touching .meetings', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"meetings":[{"id":1,"notes":"bring laptop"}]}'),
    );

    final meetings = await provider.fetchForWorkspaceRaw(5);

    expect(meetings.first['notes'], 'bring laptop');
    expect(provider.meetings, isEmpty);
  });

  test('cancelMeeting hits the cancel endpoint', () async {
    when(() => httpClient.patch(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));

    await provider.cancelMeeting(9);

    verify(() => httpClient.patch(any(that: predicate<Uri>((u) => u.path.endsWith('/meetings/9/cancel'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('createMeeting posts to /workspaces/:id/meetings', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));

    await provider.createMeeting(5, {'title': 'Kickoff'});

    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/meetings'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
