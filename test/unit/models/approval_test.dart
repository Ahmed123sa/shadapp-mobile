import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/models/approval.dart';

void main() {
  group('Approval.fromJson', () {
    test('parses a full record including nested certificate', () {
      final a = Approval.fromJson({
        'id': 1,
        'status': 'pending',
        'title': 'Q1 report',
        'description': 'Please review',
        'created_at': '2026-01-01T00:00:00Z',
        'requested_by_name': 'Ahmed',
        'reference_no': 42,
        'action_taken': false,
        'certificate': {'pdf_url': 'https://x/cert.pdf'},
      });

      expect(a.id, 1);
      expect(a.referenceNo, '42');
      expect(a.hasCertificate, isTrue);
      expect(a.isCompleted, isFalse);
    });

    test('missing fields fall back to safe defaults', () {
      final a = Approval.fromJson({'id': 2});

      expect(a.status, 'pending');
      expect(a.title, '');
      expect(a.hasCertificate, isFalse);
      expect(a.isCompleted, isFalse);
    });

    test('isCompleted is true for approved, completed, and edit_requested', () {
      for (final s in ['approved', 'completed', 'edit_requested']) {
        final a = Approval.fromJson({'id': 1, 'status': s});
        expect(a.isCompleted, isTrue, reason: 'status=$s should be completed');
      }
      final pending = Approval.fromJson({'id': 1, 'status': 'pending'});
      expect(pending.isCompleted, isFalse);
    });

    test('a certificate with no pdf_url does not count as having one', () {
      final a = Approval.fromJson({'id': 1, 'certificate': {}});
      expect(a.hasCertificate, isFalse);
    });

    test('parses requested_by as the raw requester id', () {
      final a = Approval.fromJson({'id': 1, 'requested_by': 9});
      expect(a.requestedBy, 9);
    });

    test('requestedBy is null when absent', () {
      final a = Approval.fromJson({'id': 1});
      expect(a.requestedBy, isNull);
    });
  });
}
