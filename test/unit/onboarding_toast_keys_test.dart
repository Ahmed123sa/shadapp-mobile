import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/features/onboarding/onboarding_toast_keys.dart';

void main() {
  group('toast keys match across Reverb and FCM', () {
    test('contract received', () {
      expect(toastKeyFromBroadcast({'type': 'App\\Notifications\\ContractReceivedNotification', 'contract_id': 5}), 'contract:5');
      expect(toastKeyFromFcm({'type': 'contract.received', 'id': '5'}), 'contract:5');
    });
    test('contract company approved', () {
      expect(toastKeyFromBroadcast({'contract_id': 7}), 'contract:7');
      expect(toastKeyFromFcm({'type': 'contract.company_approved', 'id': '7'}), 'contract:7');
    });
    test('payment reviewed', () {
      expect(toastKeyFromBroadcast({'payment_id': 12}), 'payment:12');
      expect(toastKeyFromFcm({'type': 'payment.approved', 'id': '12'}), 'payment:12');
    });
    test('workspace activation broadcast has no id -> any', () {
      expect(toastKeyFromBroadcast({'type': 'workspace_activated', 'workspace_id': 3}), 'any');
    });
    test('unknown FCM type or missing id -> any', () {
      expect(toastKeyFromFcm({'type': 'workspace.activated'}), 'any');
      expect(toastKeyFromFcm({'type': 'contract.received'}), 'any');
    });
  });

  group('shouldShowToast', () {
    final t0 = DateTime(2026, 1, 1, 12);
    test('same key twice within the window shows once', () {
      final recent = <String, DateTime>{};
      expect(shouldShowToast(recent, 'contract:5', t0), isTrue);
      expect(shouldShowToast(recent, 'contract:5', t0.add(const Duration(seconds: 2))), isFalse);
    });
    test('same key after the window shows again', () {
      final recent = <String, DateTime>{};
      shouldShowToast(recent, 'contract:5', t0);
      expect(shouldShowToast(recent, 'contract:5', t0.add(const Duration(seconds: 6))), isTrue);
    });
    test('different entities both show', () {
      final recent = <String, DateTime>{};
      expect(shouldShowToast(recent, 'contract:5', t0), isTrue);
      expect(shouldShowToast(recent, 'contract:6', t0), isTrue);
    });
    test('a key between two copies does not break the dedupe', () {
      final recent = <String, DateTime>{};
      shouldShowToast(recent, 'contract:5', t0);
      shouldShowToast(recent, 'payment:1', t0);
      expect(shouldShowToast(recent, 'contract:5', t0.add(const Duration(seconds: 1))), isFalse);
    });
    test('any is dropped after a recent toast, and blocks the next one', () {
      final recent = <String, DateTime>{};
      shouldShowToast(recent, 'payment:12', t0);
      expect(shouldShowToast(recent, 'any', t0.add(const Duration(seconds: 1))), isFalse);
      final r2 = <String, DateTime>{};
      shouldShowToast(r2, 'any', t0);
      expect(shouldShowToast(r2, 'payment:12', t0.add(const Duration(seconds: 1))), isFalse);
    });
  });
}