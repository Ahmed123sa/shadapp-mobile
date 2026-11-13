import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/models/app_notification.dart';

void main() {
  AppNotification make(Map<String, dynamic> data) =>
      AppNotification.fromJson({'id': '1', 'created_at': '2026-01-01T00:00:00Z', 'data': data});

  test('English app reads the English text, Arabic app reads the Arabic', () {
    final n = make({
      'title': 'عقد جديد',
      'title_en': 'New contract',
      'message': 'تم إرسال عقد',
      'message_en': 'Contract sent',
    });

    expect(n.titleFor('en'), 'New contract');
    expect(n.messageFor('en'), 'Contract sent');
    expect(n.titleFor('ar'), 'عقد جديد');
    expect(n.messageFor('ar'), 'تم إرسال عقد');
  });

  test('a row without English text falls back to the Arabic in the English app', () {
    final n = make({'title': 'عقد جديد', 'message': 'تم إرسال عقد'});

    expect(n.titleFor('en'), 'عقد جديد');
    expect(n.messageFor('en'), 'تم إرسال عقد');
  });

  test('body_en is used when a type only sends body', () {
    final n = make({'title': 'تذكير', 'body': 'دفعة اليوم', 'title_en': 'Reminder', 'body_en': 'Payment due today'});

    expect(n.messageFor('en'), 'Payment due today');
    expect(n.messageFor('ar'), 'دفعة اليوم');
  });
}
