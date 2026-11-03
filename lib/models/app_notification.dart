/// Data shape for a notification, as returned by `/notifications`. Named
/// AppNotification (not Notification) to avoid colliding with Flutter's own
/// widgets-framework Notification class.
class AppNotification {
  final String id;
  final String? type;
  final String title;
  final String message;
  // English text sent by the server next to the Arabic (null on old rows).
  final String? titleEn;
  final String? messageEn;
  final String? readAt;
  final String createdAt;
  final String? workspaceId;
  final String? clientId;

  const AppNotification({
    required this.id,
    this.type,
    this.title = '',
    this.message = '',
    this.titleEn,
    this.messageEn,
    this.readAt,
    this.createdAt = '',
    this.workspaceId,
    this.clientId,
  });

  bool get isUnread => readAt == null;

  /// The title in [lang] ('ar' or 'en'); English falls back to the stored
  /// Arabic when the row has no English text.
  String titleFor(String lang) => lang == 'en' && (titleEn ?? '').isNotEmpty ? titleEn! : title;

  String messageFor(String lang) => lang == 'en' && (messageEn ?? '').isNotEmpty ? messageEn! : message;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return AppNotification(
      // Ids are route/key identifiers, not content — stringified regardless
      // of whether the backend sends a UUID string or a numeric id, instead
      // of being dropped like a bad content field would be.
      id: _idStr(json['id']) ?? '',
      type: _str(data['type']),
      title: _str(data['title']) ?? '',
      // plans/notifications-badges-toasts-plan.md ن4 — several backend
      // notification types only ever sent 'body', not 'message' (and rows
      // stored before ح3 shipped never got backfilled), so this rendered an
      // empty line for those instead of falling back.
      message: _str(data['message']) ?? _str(data['body']) ?? '',
      titleEn: _str(data['title_en']),
      messageEn: _str(data['message_en']) ?? _str(data['body_en']),
      readAt: _str(json['read_at']),
      createdAt: _str(json['created_at']) ?? '',
      workspaceId: _idStr(data['workspace_id']),
      clientId: _idStr(data['client_id']),
    );
  }
}

String? _str(dynamic value) => value is String ? value : null;

String? _idStr(dynamic value) => value?.toString();
