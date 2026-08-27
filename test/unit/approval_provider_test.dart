import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/approval_repository.dart';
import 'package:shadapp_client/providers/approval_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ApprovalProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = ApprovalProvider(repository: ApprovalRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchApprovals populates approvals on success', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"approvals":[{"id":1,"title":"Q1 report"}]}'),
    );

    await provider.fetchApprovals(5);

    expect(provider.approvals, hasLength(1));
    expect(provider.error, isNull);
  });

  test('fetchApprovals records the error on failure', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );

    await provider.fetchApprovals(5);

    expect(provider.error, isNotNull);
  });

  test('create posts the payload to /workspaces/:id/approvals', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await provider.create(5, {'title': 'Q1 report'});

    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/workspaces/5/approvals'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
