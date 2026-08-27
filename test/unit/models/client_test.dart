import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/models/client.dart';

void main() {
  group('Client.fromJson', () {
    test('parses a full record', () {
      final client = Client.fromJson({
        'id': 1,
        'company_name': 'Acme',
        'contact_person': 'Sara',
        'email': 'sara@acme.com',
        'phone': '0100000000',
        'country': 'EG',
        'industry': 'Retail',
        'address': 'Cairo',
        'date_of_birth': '1990-01-01',
        'status': 'active',
        'client_type': 'business',
        'avatar_url': 'https://x/a.png',
        'created_at': '2026-01-01',
      });

      expect(client.id, 1);
      expect(client.companyName, 'Acme');
      expect(client.status, 'active');
      expect(client.clientType, 'business');
    });

    test('missing optional fields fall back to safe defaults instead of throwing', () {
      final client = Client.fromJson({'id': 2, 'company_name': 'Bare Co'});

      expect(client.id, 2);
      expect(client.companyName, 'Bare Co');
      expect(client.status, 'inactive');
      expect(client.contactPerson, isNull);
      expect(client.avatarUrl, isNull);
    });

    test('a wrong-typed optional field is dropped, not thrown', () {
      // company_name arriving as a number (bad data from the API) should not
      // crash the whole list — it falls back to '' like the old inline `?? ''`
      // handling used to.
      final client = Client.fromJson({'id': 3, 'company_name': 123});

      expect(client.id, 3);
      expect(client.companyName, '');
    });
  });
}
