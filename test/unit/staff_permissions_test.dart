import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/data/staff_permissions.dart';

void main() {
  test('null means everything is allowed', () {
    final p = normalizeStaffPermissions(null);
    expect(p.length, 6);
    expect(p.values.every((v) => v), isTrue);
  });

  test('missing keys default to true, given keys are kept', () {
    final p = normalizeStaffPermissions({'can_send_chat': false});
    expect(p['can_send_chat'], isFalse);
    expect(p['can_view_chat'], isTrue);
    expect(p['can_join_meetings'], isTrue);
  });

  test('turning a "see" off turns its action off', () {
    final p = setStaffPermission(allStaffPermissions(), 'can_view_approvals', false);
    expect(p['can_view_approvals'], isFalse);
    expect(p['can_request_approvals'], isFalse);
    expect(p['can_view_chat'], isTrue);
  });

  test('an action cannot be on while its "see" is off', () {
    final p = normalizeStaffPermissions({'can_view_meetings': false, 'can_join_meetings': true});
    expect(p['can_join_meetings'], isFalse);
  });
}
