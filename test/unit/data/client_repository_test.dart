import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/client_repository.dart';
import '../../helpers/mock_http_client.dart';

class _FakeMultipartRequest extends Fake implements http.BaseRequest {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ClientRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(_FakeMultipartRequest());
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = ClientRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchAllPaginatedRaw loops through every page and combines results', () async {
    var call = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      call++;
      final uri = inv.positionalArguments[0] as Uri;
      expect(uri.query, 'page=$call');
      if (call == 1) {
        return jsonResponse('{"clients":{"data":[{"id":1}],"last_page":2}}');
      }
      return jsonResponse('{"clients":{"data":[{"id":2}],"last_page":2}}');
    });

    final all = await repo.fetchAllPaginatedRaw();

    expect(all, hasLength(2));
    expect(call, 2);
  });

  test('fetchAllPaginatedRaw stops on the first empty page', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients":[]}'),
    );

    final all = await repo.fetchAllPaginatedRaw();

    expect(all, isEmpty);
    verify(() => httpClient.get(any(), headers: any(named: 'headers'))).called(1);
  });

  test('fetchProfile hits /clients/:id/profile', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":9},"stats":{},"location":{}}'),
    );

    final data = await repo.fetchProfile(9);

    expect(data['client']['id'], 9);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/profile'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('updateLocation omits address when not provided', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.updateLocation(9, latitude: 24.7, longitude: 46.6);

    expect(sentBody, {'latitude': 24.7, 'longitude': 46.6});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9/location'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('updateLocation includes address when provided', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.updateLocation(9, latitude: 24.7, longitude: 46.6, address: 'Riyadh');

    expect(sentBody, {'latitude': 24.7, 'longitude': 46.6, 'address': 'Riyadh'});
  });

  test('fetchAll parses the client list', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients":[{"id":1,"company_name":"Acme"},{"id":2,"company_name":"Beta"}]}'),
    );

    final clients = await repo.fetchAll();

    expect(clients, hasLength(2));
    expect(clients.first.companyName, 'Acme');
  });

  test('fetchAll on a paginated response reads the data key via safeList', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"clients":{"data":[{"id":1,"company_name":"Acme"}],"last_page":1}}'),
    );

    final clients = await repo.fetchAll();

    expect(clients, hasLength(1));
  });

  test('fetchOne unwraps the client envelope', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":5,"company_name":"Acme","status":"active"}}'),
    );

    final client = await repo.fetchOne(5);

    expect(client.id, 5);
    expect(client.status, 'active');
  });

  test('fetchOneRaw returns the raw envelope, including nested workspace', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":5,"workspace":{"id":12,"status":"active"}}}'),
    );

    final raw = await repo.fetchOneRaw(5);

    expect(raw['client']['workspace']['id'], 12);
    expect(raw['client']['workspace']['status'], 'active');
  });

  test('create posts the body and returns the raw response (credentials included)', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":9,"company_name":"New Co"},"credentials":{"email":"e@x.com","password":"pw"}}'),
    );

    final res = await repo.create({'company_name': 'New Co'});

    expect(res['client']['id'], 9);
    expect(res['credentials']['email'], 'e@x.com');
  });

  test('update puts the body and returns the parsed client', () async {
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{"client":{"id":9,"company_name":"Renamed"}}'),
    );

    final client = await repo.update(9, {'company_name': 'Renamed'});

    expect(client.companyName, 'Renamed');
  });

  test('uploadAvatar sends a multipart request to the profile endpoint', () async {
    final tmp = await File('${Directory.systemTemp.path}/avatar_test.png').create();
    await tmp.writeAsBytes([0, 1, 2]);
    addTearDown(() => tmp.delete());

    when(() => httpClient.send(any())).thenAnswer((inv) async {
      final req = inv.positionalArguments[0] as http.BaseRequest;
      expect(req.url.path, endsWith('/clients/7/profile'));
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
    });

    await repo.uploadAvatar(7, tmp);

    verify(() => httpClient.send(any())).called(1);
  });

  test('delete calls DELETE on the client endpoint', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.delete(9);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/clients/9'))),
        headers: any(named: 'headers'))).called(1);
  });
}
