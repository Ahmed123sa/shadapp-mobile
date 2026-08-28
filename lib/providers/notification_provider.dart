import 'package:flutter/material.dart';
import '../data/notification_repository.dart';
import '../models/app_notification.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repo;
  NotificationProvider({NotificationRepository? repository}) : _repo = repository ?? NotificationRepository();

  int _unreadCount = 0;
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  int _serverUnreadCount = 0;

  int get unreadCount => _unreadCount;
  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  /// Server-declared unread count (only populated by [fetchNotificationList]).
  int get serverUnreadCount => _serverUnreadCount;

  /// Badge/preview fetch. Unread count is computed from the fetched batch
  /// itself (read_at == null) — unchanged from before this migration.
  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _repo.fetchAll();
      _notifications = result.notifications;
      _unreadCount = _notifications.where((n) => n.isUnread).length;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Full-list screen fetch (notifications_page.dart). Trusts the server's
  /// own unread_count field instead of counting the current batch — that's
  /// what the original inline _load() in that screen did, as opposed to the
  /// batch-count [fetchNotifications] above uses for the badge.
  Future<void> fetchNotificationList() async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _repo.fetchAll();
      _notifications = result.notifications;
      _serverUnreadCount = result.serverUnreadCount ?? 0;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Raw envelope — see [NotificationRepository.fetchRaw]. Doesn't touch
  /// [_notifications]/[_unreadCount]; the dashboard screens only need the
  /// top-level `unread_count` for their badge.
  Future<Map<String, dynamic>> fetchRaw() => _repo.fetchRaw();

  // These three deliberately don't refetch internally — the original inline
  // code in notifications_page.dart always called its own _load() right
  // after each of these, so refreshing here too would double the GET call.
  // The caller decides when to reload (see notifications_page.dart).
  Future<void> markRead(String id) => _repo.markRead(id);

  Future<void> markAllRead() => _repo.markAllRead();

  Future<void> deleteNotification(String id) => _repo.delete(id);

  void incrementUnread() {
    _unreadCount++;
    notifyListeners();
  }

  void resetUnread() {
    _unreadCount = 0;
    notifyListeners();
  }
}
