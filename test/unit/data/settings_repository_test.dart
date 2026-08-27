import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/settings_repository.dart';
import '../../helpers/mock_http_client.dart';

class _FakeMultipartRequest extends Fake implements http.BaseRequest {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late SettingsRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(_FakeMultipartRequest());
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = SettingsRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchSubUser unwraps the sub_user envelope', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"sub_user":{"id":1,"email":"a@a.com"}}'),
    );

    final su = await repo.fetchSubUser(1);

    expect(su['email'], 'a@a.com');
  });

  test('updateSubUserProfile puts to the sub-user profile endpoint', () async {
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.updateSubUserProfile(1, {'name': 'X'});

    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/sub-users/1/profile'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('fetchClient unwraps the client envelope', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":9,"contact_person":"Sara"}}'),
    );

    final client = await repo.fetchClient(9);

    expect(client['contact_person'], 'Sara');
  });

  test('updateClientProfile puts to the client profile endpoint (not /clients/:id)', () async {
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.updateClientProfile(9, {'contact_person': 'Sara'});

    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/profile'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('uploadClientAvatar sends a multipart request to the client profile endpoint', () async {
    final tmp = await File('${Directory.systemTemp.path}/settings_repo_test.png').create();
    await tmp.writeAsBytes([0, 1, 2]);
    addTearDown(() => tmp.delete());

    when(() => httpClient.send(any())).thenAnswer((inv) async {
      final req = inv.positionalArguments[0] as http.BaseRequest;
      expect(req.url.path, endsWith('/clients/9/profile'));
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
    });

    await repo.uploadClientAvatar(9, tmp);

    verify(() => httpClient.send(any())).called(1);
  });
}
