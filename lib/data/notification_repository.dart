import '../core/api_client.dart';
import '../models/app_notification.dart';

/// A fetched page of notifications plus the server's own unread_count field
/// — kept separate from a client-computed count because the two call sites
/// that used to inline this (NotificationProvider's old fetchNotifications
/// and notifications_page.dart's _load) trusted different sources for it,
/// and that distinction is preserved rather than silently merged.
class NotificationListResult {
  final List<AppNotification> notifications;
  final int? serverUnreadCount;
  const NotificationListResult(this.notifications, this.serverUnreadCount);
}

class NotificationRepository {
  final ApiClient _api;
  NotificationRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<NotificationListResult> fetchAll() async {
    final res = await _api.get('/notifications');
    // Two different shapes have been observed at this endpoint across the
    // app's call sites — a plain "notifications" key and a paginated "data"
    // envelope. Both are supported, same as the pre-migration inline code.
    final raw = (res['notifications'] ?? res['data']) as List<dynamic>? ?? [];
    final notifications = raw.map((j) => AppNotification.fromJson(j as Map<String, dynamic>)).toList();
    final unreadCount = int.tryParse(res['unread_count']?.toString() ?? '');
    return NotificationListResult(notifications, unreadCount);
  }

  /// Raw `/notifications` envelope — the dashboard screens' badge only needs
  /// the top-level `unread_count` field, not a fully parsed notification
  /// list, so this skips [AppNotification.fromJson] entirely.
  Future<Map<String, dynamic>> fetchRaw() => _api.get('/notifications');

  Future<void> markRead(String id) => _api.post('/notifications/$id/read');

  Future<void> markAllRead() => _api.post('/notifications/read-all');

  Future<void> delete(String id) => _api.delete('/notifications/$id');
}
