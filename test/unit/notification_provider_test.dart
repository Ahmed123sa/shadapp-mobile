import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/notification_repository.dart';
import 'package:shadapp_client/providers/notification_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late NotificationProvider provider;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    provider = NotificationProvider(repository: NotificationRepository(api: buildTestApiClient(client: httpClient)));
  });

  test('fetchNotifications counts only unread (read_at == null) items', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(
        '{"notifications":[{"id":1,"read_at":null},{"id":2,"read_at":"2026-01-01"},{"id":3,"read_at":null}]}',
      ),
    );

    await provider.fetchNotifications();

    expect(provider.notifications, hasLength(3));
    expect(provider.unreadCount, 2);
  });

  test('accepts the paginated {data: [...]} shape as an alternative to "notifications"', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"data":[{"id":1,"read_at":null}]}'),
    );

    await provider.fetchNotifications();

    expect(provider.unreadCount, 1);
  });

  test('a failed fetch is swallowed silently, leaving prior state alone', () async {
    provider.incrementUnread();
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"nope"}', 500),
    );

    await provider.fetchNotifications();

    expect(provider.isLoading, isFalse);
    expect(provider.unreadCount, 1); // untouched by the failed fetch
  });

  test('incrementUnread / resetUnread update the counter directly', () {
    provider.incrementUnread();
    provider.incrementUnread();
    expect(provider.unreadCount, 2);

    provider.resetUnread();
    expect(provider.unreadCount, 0);
  });
}
