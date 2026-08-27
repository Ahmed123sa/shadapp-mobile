import 'dart:convert';

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

  test('fetchForWorkspaceRaw returns raw maps, preserving fields not on the Meeting model', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"meetings":[{"id":1,"title":"Kickoff","notes":"bring laptop","passcode":"1234"}]}'),
    );

    final meetings = await repo.fetchForWorkspaceRaw(5);

    expect(meetings, hasLength(1));
    expect(meetings.first['notes'], 'bring laptop');
    expect(meetings.first['passcode'], '1234');
  });

  test('fetchAllWorkspacesRaw returns raw maps from /all-meetings', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"meetings":[{"id":1,"contract":{"title":"MSA"}}]}'),
    );

    final meetings = await repo.fetchAllWorkspacesRaw();

    expect(meetings.first['contract']['title'], 'MSA');
  });

  test('cancel hits PATCH /meetings/:id/cancel', () async {
    when(() => httpClient.patch(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));

    await repo.cancel(9);

    verify(() => httpClient.patch(any(that: predicate<Uri>((u) => u.path.endsWith('/meetings/9/cancel'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('complete hits PATCH /meetings/:id/complete', () async {
    when(() => httpClient.patch(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse('{}'));

    await repo.complete(9);

    verify(() => httpClient.patch(any(that: predicate<Uri>((u) => u.path.endsWith('/meetings/9/complete'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('create posts to /workspaces/:id/meetings with the given payload', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.create(5, {'title': 'Kickoff'});

    expect(sentBody, {'title': 'Kickoff'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/meetings'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('update puts to /workspaces/:id/meetings/:id with the given payload', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.update(5, 9, {'title': 'Renamed'});

    expect(sentBody, {'title': 'Renamed'});
    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/meetings/9'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
