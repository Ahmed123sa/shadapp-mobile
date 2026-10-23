import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/notification_routing.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
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
  bool _failed = false;

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
      _failed = _notificationProvider.listFailed;
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

  String? _resolveRoute(String? role, String? workspaceId, String? clientId, String? type) {
    final isStaffMember = role == 'staff_member';
    final isAdmin = role == 'account_manager' || role == 'super_admin' || role == 'manager_assistant' || role == 'accountant' || isStaffMember;
    if (isAdmin && workspaceId != null && workspaceId.isNotEmpty) {
      // plans/notifications-badges-toasts-plan.md ن14 — this used to have
      // its own private _tabIndexForType(), which mapped 'workspace_*' types
      // to the contracts tab while fcmTabIndex() (used just below for the
      // client/sub_user branch, and by main.dart for FCM taps) left them
      // falling through to chat. Now both branches share the one mapping.
      return '/am/workspace/$workspaceId?tab=${fcmTabIndex(type)}';
    }
    // Staff have no client detail screen — only the workspace above.
    if (isAdmin && !isStaffMember && role != 'accountant' && clientId != null && clientId.isNotEmpty) {
      return '/am/clients/$clientId';
    }
    if (isStaffMember) return '/staff/dashboard';
    if (role == 'accountant') return '/accountant/dashboard';
    if (isAdmin) return '/am/dashboard';
    return '/dashboard?tab=${fcmTabIndex(type, isClient: true)}';
  }

  Future<void> _delete(String id) async {
    await _notificationProvider.deleteNotification(id);
    if (mounted) _load();
  }

  // Mockup tones: ok = done/approved, wait = waiting, c = needs your action,
  // '' = information.
  String _toneForType(String? type) {
    switch (type) {
      case 'contract_company_approved':
      case 'contract_completed':
      case 'payment_reviewed':
      case 'payment_reviewed_staff':
      case 'approval_responded':
        return 'ok';
      case 'contract_sent':
      case 'contract_client_approved':
      case 'payment_created':
      case 'payment_scheduled':
      case 'payment_reminder':
      case 'payment_overdue_staff':
      case 'payment_schedule_updated':
        return 'w';
      case 'approval_requested':
      case 'payment_schedule_deleted':
        return 'c';
      default:
        return '';
    }
  }

  Color _toneColor(String tone) => switch (tone) {
        'ok' => Lx.ok,
        'w' => Lx.wait,
        'c' => Lx.crimsonInk,
        _ => Lx.muted,
      };

  String _iconForType(String? type) {
    switch (type) {
      case 'contract_sent':
        return 'send';
      case 'contract_client_approved':
        return 'users';
      case 'contract_company_approved':
        return 'verified';
      case 'contract_completed':
        return 'check';
      case 'payment_created':
      case 'payment_reviewed':
      case 'payment_reviewed_staff':
        return 'wallet';
      case 'payment_scheduled':
        return 'cal';
      case 'payment_reminder':
      case 'payment_overdue_staff':
        return 'clock';
      case 'payment_schedule_deleted':
        return 'trash';
      case 'payment_schedule_updated':
        return 'refresh';
      case 'approval_requested':
        return 'check';
      case 'approval_responded':
        return 'reply';
      default:
        return 'bell';
    }
  }

  // Groups by the day already on each notification: today, yesterday,
  // earlier this week, then a plain date.
  String _groupOf(String date, AppLocalizations l10n) {
    final dt = DateTime.tryParse(date)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (days <= 0) return l10n.notificationsGroupToday;
    if (days == 1) return l10n.notificationsGroupYesterday;
    if (days < 7) return l10n.notificationsGroupWeek;
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _header(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(children: [
        InkWell(
          key: const ValueKey('notif-back'),
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Lx.line2)),
            child: Directionality.of(context) == TextDirection.rtl
                ? Transform.flip(flipX: true, child: const LxIcon('back', size: 16, color: Lx.ink))
                : const LxIcon('back', size: 16, color: Lx.ink),
          ),
        ),
        const Spacer(),
        if (_unreadCount > 0 && !_failed)
          InkWell(
            key: const ValueKey('notif-mark-all'),
            onTap: _markAllAsRead,
            child: Container(
              padding: const EdgeInsets.only(bottom: 1),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const LxIcon('checks', size: 13, color: Lx.ink2),
                const SizedBox(width: 6),
                Text(l10n.notifications_markAllRead, style: Lx.text(context, size: 12.5, color: Lx.ink2)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _title(AppLocalizations l10n, {bool withCount = false}) {
    final style = Lx.display(context, size: 30);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: l10n.notifications_title),
            TextSpan(text: '.', style: style.copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
          ]),
          style: style,
        ),
        if (withCount)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _unreadCount > 0 ? l10n.notificationsUnreadCount(_unreadCount) : l10n.notificationsAllRead,
              style: Lx.text(context, size: 12, color: Lx.muted),
            ),
          ),
      ]),
    );
  }

  Widget _row(AppNotification notif) {
    final tone = _toneForType(notif.type);
    final color = _toneColor(tone);
    final isUnread = notif.isUnread;
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(notif.id),
      background: Container(
        color: Lx.page,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const LxIcon('trash', size: 15, color: Lx.danger),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context)!.notificationsDelete, style: Lx.text(context, size: 12, color: Lx.danger)),
        ]),
      ),
      child: InkWell(
        key: ValueKey('notif-${notif.id}'),
        onTap: () {
          if (isUnread) _markAsRead(notif.id);
          _navigateToNotification(notif.workspaceId, notif.clientId, notif.type);
        },
        child: Container(
          color: Lx.page,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Stack(clipBehavior: Clip.none, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tone.isEmpty ? Lx.line2 : color.withAlpha(tone == 'c' ? 115 : 102)),
                ),
                child: LxIcon(_iconForType(notif.type), size: 16, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(notif.title, style: Lx.text(context, size: 14, weight: isUnread ? FontWeight.w500 : FontWeight.w400, color: isUnread ? Lx.ink : Lx.ink2)),
                  if (notif.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(notif.message, style: Lx.text(context, size: 12.5, color: Lx.muted, height: 1.55)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(_formatDate(notif.createdAt), style: Lx.text(context, size: 11, color: Lx.faint)),
                    ),
                  ),
                ]),
              ),
            ]),
            if (isUnread)
              PositionedDirectional(
                key: const ValueKey('notif-unread-dot'),
                top: 7,
                start: -9,
                child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Lx.crimsonInk, shape: BoxShape.circle)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _groupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(children: [
        Text(text.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.4)),
        const SizedBox(width: 12),
        const Expanded(child: Divider(height: 1, color: Lx.line)),
      ]),
    );
  }

  Widget _empty(AppLocalizations l10n) {
    return ListView(children: [
      _title(l10n),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 90, 20, 0),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Lx.line2)),
            child: const LxIcon('bellOff', size: 26, color: Lx.faint),
          ),
          const SizedBox(height: 18),
          Text(l10n.notificationsEmptyTitle, style: Lx.display(context, size: 22)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(l10n.notificationsEmptyHint, textAlign: TextAlign.center, style: Lx.text(context, size: 13, color: Lx.muted)),
          ),
        ]),
      ),
    ]);
  }

  Widget _error(AppLocalizations l10n) {
    return ListView(children: [
      _title(l10n),
      Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Lx.crimsonInk.withAlpha(89)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.notificationsLoadFailed, style: Lx.text(context, size: 13, color: Lx.ink2)),
          const SizedBox(height: 12),
          LuxeButton(
            key: const ValueKey('notif-retry'),
            label: l10n.retry,
            size: LuxeButtonSize.sm,
            kind: LuxeButtonKind.outline,
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ]),
      ),
    ]);
  }

  Widget _skeleton(AppLocalizations l10n) {
    return ListView(children: [
      _title(l10n),
      for (var i = 0; i < 5; i++)
        Container(
          height: 64,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x0DFFFFFF)),
        ),
    ]);
  }

  Widget _list(AppLocalizations l10n) {
    final children = <Widget>[_title(l10n, withCount: true)];
    String? last;
    for (final n in _notifications) {
      final g = _groupOf(n.createdAt, l10n);
      if (g != last) {
        children.add(_groupLabel(g));
        last = g;
      }
      children.add(_row(n));
      children.add(const Divider(height: 1, indent: 16, endIndent: 16, color: Lx.line));
    }
    return ListView(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final Widget body;
    if (_loading) {
      body = _skeleton(l10n);
    } else if (_failed && _notifications.isEmpty) {
      body = _error(l10n);
    } else if (_notifications.isEmpty) {
      body = _empty(l10n);
    } else {
      body = _list(l10n);
    }
    return Scaffold(
      backgroundColor: Lx.page,
      body: SafeArea(
        child: LuxeGlow(
          child: Column(children: [
            _header(l10n),
            Expanded(child: RefreshIndicator(onRefresh: _load, color: Lx.crimsonInk, child: body)),
          ]),
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
