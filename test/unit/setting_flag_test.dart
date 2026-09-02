import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/features/am/widgets/contract_builder.dart';

// The `show_contract_dates` setting is read in four places across this app and
// the dashboard, each with its own inline parsing expression. This covers the
// mobile one. The previous test for this feature
// (test/unit/new_features_phase4_test.dart) asserted that a mocked
// ApiClient.get returned the JSON it had just been told to return — which
// exercises jsonDecode, not the parsing below, where an actual bug would live.
void main() {
  group('asSettingFlag', () {
    test('accepts the string form the backend actually stores', () {
      // SystemSetting stores '1'/'0' as strings — this is the live case.
      expect(asSettingFlag('1'), isTrue);
      expect(asSettingFlag('0'), isFalse);
    });

    test('accepts a real bool, in case a Laravel cast starts sending one', () {
      expect(asSettingFlag(true), isTrue);
      expect(asSettingFlag(false), isFalse);
    });

    test('accepts an int, in case the column is cast to integer', () {
      expect(asSettingFlag(1), isTrue);
      expect(asSettingFlag(0), isFalse);
    });

    test('accepts "true"/"false" regardless of case or padding', () {
      expect(asSettingFlag('true'), isTrue);
      expect(asSettingFlag('TRUE'), isTrue);
      expect(asSettingFlag(' True '), isTrue);
      expect(asSettingFlag('false'), isFalse);
    });

    test('treats null and unparseable values as false rather than throwing', () {
      // A getter called from build() must not throw on unexpected input —
      // the caller keeps its own default when the setting is absent.
      expect(asSettingFlag(null), isFalse);
      expect(asSettingFlag(''), isFalse);
      expect(asSettingFlag('yes'), isFalse);
      expect(asSettingFlag(<String, dynamic>{}), isFalse);
    });
  });
}
