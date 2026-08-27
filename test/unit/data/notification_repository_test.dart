import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/notification_repository.dart';
import '../../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late NotificationRepository repo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    repo = NotificationRepository(api: buildTestApiClient(client: httpClient));
  });

  test('fetchAll parses the "notifications" shape plus unread_count', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"notifications":[{"id":1,"read_at":null}],"unread_count":4}'),
    );

    final result = await repo.fetchAll();

    expect(result.notifications, hasLength(1));
    expect(result.serverUnreadCount, 4);
  });

  test('fetchAll falls back to the paginated "data" shape', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"data":[{"id":1,"read_at":null}]}'),
    );

    final result = await repo.fetchAll();

    expect(result.notifications, hasLength(1));
    expect(result.serverUnreadCount, isNull);
  });

  test('markRead posts to the read endpoint', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.markRead('abc-1');

    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/notifications/abc-1/read'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('markAllRead posts to the read-all endpoint', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.markAllRead();

    verify(() => httpClient.post(any(that: predicate<Uri>((u) => u.path.endsWith('/notifications/read-all'))),
        headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  test('delete calls DELETE on the notification endpoint', () async {
    when(() => httpClient.delete(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{}'),
    );

    await repo.delete('abc-1');

    verify(() => httpClient.delete(any(that: predicate<Uri>((u) => u.path.endsWith('/notifications/abc-1'))),
        headers: any(named: 'headers'))).called(1);
  });
}
