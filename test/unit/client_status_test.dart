import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/helpers/client_status.dart';

void main() {
  test('uses has_signed_contract, not the profile signature', () {
    expect(clientHasSignedContract({'has_signed_contract': true, 'signed_at': null}), isTrue);
    expect(clientHasSignedContract({'has_signed_contract': false, 'signed_at': '2026-09-01'}), isFalse);
  });

  test('an active workspace always counts as contracted', () {
    expect(clientHasSignedContract({'has_signed_contract': false, 'workspace': {'status': 'active'}}), isTrue);
  });

  test('accepts 0/1 from the server', () {
    expect(clientHasSignedContract({'has_signed_contract': 1}), isTrue);
    expect(clientHasSignedContract({'has_signed_contract': 0}), isFalse);
  });

  test('falls back to signed_at when the server does not send the flag', () {
    expect(clientHasSignedContract({'signed_at': '2026-09-01'}), isTrue);
    expect(clientHasSignedContract({}), isFalse);
  });
}
