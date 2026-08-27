import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/approval_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ApprovalRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = ApprovalRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchAll parses the approvals list for a workspace', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"approvals":[{"id":1,"title":"Q1 report","status":"pending"}]}'),
    );

    final approvals = await repo.fetchAll(5);

    expect(approvals, hasLength(1));
    expect(approvals.first.title, 'Q1 report');
    verify(() => httpClient.get(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/approvals'))),
        headers: any(named: 'headers'))).called(1);
  });

  test('respond sends only "action" when no reason is given', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.respond(1, action: 'approved');

    expect(sentBody, {'action': 'approved'});
  });

  test('respond includes the reason when one is given', () async {
    Map<String, dynamic>? sentBody;
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer((inv) async {
      sentBody = jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
      return jsonResponse('{}');
    });

    await repo.respond(1, action: 'edit_requested', reason: 'please fix the total');

    expect(sentBody, {'action': 'edit_requested', 'reason': 'please fix the total'});
  });
}
