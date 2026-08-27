import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/meeting_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late MeetingRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = MeetingRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchForWorkspace parses the meeting list for a workspace', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"meetings":[{"id":1,"title":"Kickoff"}]}'),
    );

    final meetings = await repo.fetchForWorkspace(5);

    expect(meetings, hasLength(1));
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/meetings'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('fetchAllWorkspaces hits /all-meetings', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"meetings":[{"id":1,"title":"Kickoff"},{"id":2,"title":"Follow-up"}]}'),
    );

    final meetings = await repo.fetchAllWorkspaces();

    expect(meetings, hasLength(2));
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/all-meetings'))),
        headers: any(named: 'headers'))).called(1);
  });
}
