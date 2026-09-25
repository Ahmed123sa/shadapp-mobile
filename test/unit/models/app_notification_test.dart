import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/models/app_notification.dart';

void main() {
  group('AppNotification.fromJson', () {
    test('parses a full record including nested data', () {
      final n = AppNotification.fromJson({
        'id': 'abc-123',
        'read_at': null,
        'created_at': '2026-01-01T10:00:00Z',
        'data': {
          'type': 'contract_sent',
          'title': 'New contract',
          'message': 'A contract was sent',
          'workspace_id': 5,
          'client_id': 9,
        },
      });

      expect(n.id, 'abc-123');
      expect(n.type, 'contract_sent');
      expect(n.title, 'New contract');
      expect(n.isUnread, isTrue);
      expect(n.workspaceId, '5');
      expect(n.clientId, '9');
    });

    test('a read notification is not unread', () {
      final n = AppNotification.fromJson({'id': 1, 'read_at': '2026-01-01T10:00:00Z'});
      expect(n.isUnread, isFalse);
    });

    test('missing data/fields fall back to safe defaults', () {
      final n = AppNotification.fromJson({'id': 2});
      expect(n.title, '');
      expect(n.message, '');
      expect(n.type, isNull);
      expect(n.workspaceId, isNull);
      expect(n.isUnread, isTrue);
    });

    test('a numeric id is stringified, not dropped', () {
      final n = AppNotification.fromJson({'id': 42});
      expect(n.id, '42');
    });

    // plans/notifications-badges-toasts-plan.md ن4 — several backend
    // notification types only ever send 'body', not 'message' (and rows
    // stored before ح3 shipped never got backfilled), so this used to
    // render an empty line for those instead of falling back.
    test('falls back to body when message is absent', () {
      final n = AppNotification.fromJson({
        'id': 3,
        'data': {'type': 'payment_reminder', 'title': 'تذكير', 'body': 'دفعة مستحقة اليوم'},
      });
      expect(n.message, 'دفعة مستحقة اليوم');
    });

    test('prefers message over body when both are present', () {
      final n = AppNotification.fromJson({
        'id': 4,
        'data': {'message': 'from message', 'body': 'from body'},
      });
      expect(n.message, 'from message');
    });
  });
}
