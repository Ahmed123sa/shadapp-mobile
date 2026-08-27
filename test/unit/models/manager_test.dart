import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/models/manager.dart';

void main() {
  group('Manager.fromJson', () {
    test('parses a full record', () {
      final manager = Manager.fromJson({
        'id': 1,
        'name': 'Ahmed',
        'email': 'ahmed@shad.com',
        'phone': '0500000000',
        'avatar_url': 'https://x/a.png',
        'date_of_birth': '1990-01-01',
        'managed_clients_count': 4,
      });

      expect(manager.id, 1);
      expect(manager.name, 'Ahmed');
      expect(manager.managedClientsCount, 4);
    });

    test('missing fields fall back to safe defaults', () {
      final manager = Manager.fromJson({'id': 2, 'name': 'Bare'});

      expect(manager.managedClientsCount, 0);
      expect(manager.email, isNull);
      expect(manager.avatarUrl, isNull);
    });

    test('a stringified count is parsed instead of thrown', () {
      final manager = Manager.fromJson({'id': 3, 'name': 'X', 'managed_clients_count': '7'});

      expect(manager.managedClientsCount, 7);
    });

    test('a wrong-typed name is dropped, not thrown', () {
      final manager = Manager.fromJson({'id': 4, 'name': 123});

      expect(manager.name, '');
    });
  });
}
