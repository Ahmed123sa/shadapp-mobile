import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/notification_routing.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';

class NotificationsPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with a mocked
  // NotificationProvider instead of hitting the network — same pattern used
  // for LoginPage/CreateClientPage/AccountManagersPage.
  final NotificationProvider? notificationProvider;
  // Only used to read the current role for navigation routing (_resolveRoute)
  // — the provider owns the actual /notifications calls now.
  final ApiClient? api;
  const NotificationsPage({super.key, this.notificationProvider, this.api});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final NotificationProvider _notificationProvider =
      widget.notificationProvider ?? NotificationProvider();
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _notificationProvider.fetchNotificationList();
    if (!mounted) return;
    setState(() {
      _notifications = _notificationProvider.notifications;
      _unreadCount = _notificationProvider.serverUnreadCount;
      _loading = false;
    });
  }

  Future<void> _markAsRead(String id) async {
    await _notificationProvider.markRead(id);
    _load();
  }

  Future<void> _markAllAsRead() async {
    await _notificationProvider.markAllRead();
    _load();
  }

  void _navigateToNotification(String? workspaceId, String? clientId, String? type) {
    if (!mounted) return;
    final role = _api.role;
    final route = _resolveRoute(role, workspaceId, clientId, type);
    if (route != null) context.push(route);
  }

  int _tabIndexForType(String? type) {
    if (type == null || type == 'chat') return 0;
    if (type.startsWith('contract') || type.startsWith('workspace')) return 2;
    if (type.startsWith('payment')) return 3;
    if (type.startsWith('approval')) return 4;
    if (type.startsWith('meeting')) return 5;
    return 0;
  }

  String? _resolveRoute(String? role, String? workspaceId, String? clientId, String? type) {
    final isAdmin = role == 'account_manager' || role == 'super_admin';
    if (isAdmin && workspaceId != null && workspaceId.isNotEmpty) {
      return '/am/workspace/$workspaceId?tab=${_tabIndexForType(type)}';
    }
    if (isAdmin && clientId != null && clientId.isNotEmpty) {
      return '/am/clients/$clientId';
    }
    if (isAdmin) return '/am/dashboard';
    return '/dashboard?tab=${fcmTabIndex(type, isClient: true)}';
  }

  Future<void> _delete(String id) async {
    await _notificationProvider.deleteNotification(id);
    if (mounted) _load();
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'contract_sent':
      case 'contract_client_approved':
      case 'contract_company_approved':
      case 'contract_completed':
        return Colors.blue;
      case 'payment_created':
      case 'payment_reviewed':
      case 'payment_scheduled':
      case 'payment_reminder':
        return Colors.green;
      case 'payment_schedule_deleted':
        return Colors.red;
      case 'payment_schedule_updated':
        return Colors.blue;
      case 'approval_requested':
      case 'approval_responded':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'contract_sent':
        return Icons.send;
      case 'contract_client_approved':
        return Icons.person;
      case 'contract_company_approved':
        return Icons.verified;
      case 'contract_completed':
        return Icons.check_circle;
      case 'payment_created':
        return Icons.payment;
      case 'payment_reviewed':
        return Icons.rate_review;
      case 'payment_scheduled':
        return Icons.schedule;
      case 'payment_reminder':
        return Icons.notifications_active;
      case 'payment_schedule_deleted':
        return Icons.delete_outline;
      case 'payment_schedule_updated':
        return Icons.edit_calendar;
      case 'approval_requested':
        return Icons.approval;
      case 'approval_responded':
        return Icons.reply;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications_title),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(l10n.notifications_markAllRead),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(l10n.notifications_empty, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final type = notif.type;
                      final title = notif.title;
                      final message = notif.message;
                      final isUnread = notif.isUnread;
                      final id = notif.id;
                      final createdAt = notif.createdAt;

                      return Dismissible(
                        key: Key(id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _delete(id),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsetsDirectional.only(end: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          color: isUnread ? ShadColors.primary.withAlpha(20) : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _colorForType(type).withAlpha(30),
                              child: Icon(_iconForType(type), color: _colorForType(type), size: 20),
                            ),
                            title: Text(title, style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(message),
                                const SizedBox(height: 4),
                                Text(_formatDate(createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              ],
                            ),
                            trailing: isUnread
                                ? Container(width: 10, height: 10, decoration: BoxDecoration(color: ShadColors.primary, shape: BoxShape.circle))
                                : null,
                            onTap: () {
                              if (isUnread) _markAsRead(id);
                              _navigateToNotification(notif.workspaceId, notif.clientId, notif.type);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(String date) {
    final l10n = AppLocalizations.of(context)!;
    try {
      final dt = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return l10n.notifications_minutesAgo(diff.inMinutes);
      if (diff.inHours < 24) return l10n.notifications_hoursAgo(diff.inHours);
      if (diff.inDays < 7) return l10n.notifications_daysAgo(diff.inDays);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return date;
    }
  }
}
