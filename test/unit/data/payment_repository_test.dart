import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/payment_repository.dart';
import '../../helpers/mock_http_client.dart';

class _FakeMultipartRequest extends Fake implements http.BaseRequest {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late PaymentRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(_FakeMultipartRequest());
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = PaymentRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchForWorkspace hits the workspace-scoped endpoint', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"payments":[{"id":1}]}'),
    );

    final payments = await repo.fetchForWorkspace(5);

    expect(payments, hasLength(1));
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('handles a paginated {data: [...]} response shape via safeList', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"payments":{"data":[{"id":1}]}}'),
    );

    final payments = await repo.fetchForWorkspace(5);

    expect(payments, hasLength(1));
  });

  test('fetchPending includes the page number in the query', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"payments":[]}'),
    );

    await repo.fetchPending(page: 2);

    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/payments/pending') && u.query == 'page=2')),
        headers: any(named: 'headers'))).called(1);
  });

  test('fetchAllPendingRaw loops through every page and combines results', () async {
    var call = 0;
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      call++;
      if (call == 1) {
        return jsonResponse('{"payments":{"data":[{"id":1}],"last_page":2}}');
      }
      return jsonResponse('{"payments":{"data":[{"id":2}],"last_page":2}}');
    });

    final all = await repo.fetchAllPendingRaw();

    expect(all, hasLength(2));
    expect(call, 2);
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/payments/pending'))),
        headers: any(named: 'headers'))).called(2);
  });

  test('create posts plain JSON when there are no proof files', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.create(5, {'amount': 100, 'currency': 'EGP', 'method_type': 'cash'});

    expect(sentBody, {'amount': 100, 'currency': 'EGP', 'method_type': 'cash'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('create sends a multipart request with native files, preferring them over bytes', () async {
    final tmp = await File('${Directory.systemTemp.path}/payment_proof.png').create();
    await tmp.writeAsBytes([0, 1, 2]);
    addTearDown(() => tmp.delete());

    when(() => httpClient.send(any())).thenAnswer((inv) async {
      final req = inv.positionalArguments[0] as http.MultipartRequest;
      expect(req.url.path, endsWith('/workspaces/5/payments'));
      expect(req.files, hasLength(1));
      expect(req.files.first.field, 'proof_files[]');
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
    });

    await repo.create(5, {'amount': 100, 'currency': 'EGP'}, files: [tmp], bytesFiles: [Uint8List.fromList([9])]);

    verify(() => httpClient.send(any())).called(1);
  });

  test('create sends a multipart request with in-memory bytes when no native files are given', () async {
    when(() => httpClient.send(any())).thenAnswer((inv) async {
      final req = inv.positionalArguments[0] as http.MultipartRequest;
      expect(req.files, hasLength(2));
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
    });

    await repo.create(
      5,
      {'amount': 50, 'currency': 'EGP'},
      bytesFiles: [Uint8List.fromList([1]), Uint8List.fromList([2])],
      bytesNames: ['a.jpg', 'b.jpg'],
    );

    verify(() => httpClient.send(any())).called(1);
  });

  test('uploadProof puts plain JSON when there are no files', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.uploadProof(5, 9, 'cash');

    expect(sentBody, {'method_type': 'cash'});
    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments/9'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('uploadProof sends a multipart PUT with native files', () async {
    final tmp = await File('${Directory.systemTemp.path}/payment_proof2.png').create();
    await tmp.writeAsBytes([0, 1, 2]);
    addTearDown(() => tmp.delete());

    when(() => httpClient.send(any())).thenAnswer((inv) async {
      final req = inv.positionalArguments[0] as http.MultipartRequest;
      expect(req.method, 'PUT');
      expect(req.url.path, endsWith('/workspaces/5/payments/9'));
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
    });

    await repo.uploadProof(5, 9, 'bank_transfer', files: [tmp]);

    verify(() => httpClient.send(any())).called(1);
  });

  test('review posts the action to /payments/:id/review', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{"workspace":{"status":"active"}}');
    });

    final res = await repo.review(9, 'approved');

    expect(sentBody, {'action': 'approved'});
    expect(res['workspace']['status'], 'active');
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/payments/9/review'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('schedule posts the installments list', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.schedule(5, [
      {'amount': 100, 'due_date': '2026-09-01'},
    ]);

    expect(sentBody, {
      'installments': [
        {'amount': 100, 'due_date': '2026-09-01'},
      ],
    });
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments/schedule'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('updateSchedule puts the payload to /payments/:id/schedule', () async {
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.updateSchedule(9, {'amount': 200});

    verify(() => httpClient.put(any(that: predicate<Uri>((u) => u.path.endsWith('/payments/9/schedule'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('deleteSchedule calls DELETE on /payments/:id/schedule', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.deleteSchedule(9);

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/payments/9/schedule'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('requestPayment omits notes when empty', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.requestPayment(5, 250.0, 'EGP', notes: '');

    expect(sentBody, {'amount': 250.0, 'currency': 'EGP'});
  });

  test('requestPayment includes notes when provided', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.requestPayment(5, 250.0, 'EGP', notes: 'please pay soon');

    expect(sentBody, {'amount': 250.0, 'currency': 'EGP', 'notes': 'please pay soon'});
    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/payments/request'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
