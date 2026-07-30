import 'package:flutter/material.dart';
import '../core/api_client.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  int _unreadCount = 0;
  List<dynamic> _notifications = [];
  bool _isLoading = false;

  int get unreadCount => _unreadCount;
  List<dynamic> get notifications => _notifications;
  bool get isLoading => _isLoading;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get('/notifications');
      _notifications = (res['notifications'] ?? res['data']) as List<dynamic>;
      _unreadCount = _notifications.where((n) => n['read_at'] == null).length;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void incrementUnread() {
    _unreadCount++;
    notifyListeners();
  }

  void resetUnread() {
    _unreadCount = 0;
    notifyListeners();
  }
}
