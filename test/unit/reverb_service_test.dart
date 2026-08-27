// Step 0 of the state-layer migration plan (docs/state-layer-migration-plan.md,
// "الخطوة صفر"): ReverbService.forTesting() mirrors ApiClient.forTesting() —
// an independent, non-singleton instance whose connect*() methods never open
// a real WebSocket. This is what will let Path D's six realtime screens
// accept an optional `ReverbService? reverb` and be pumped in plain
// `flutter test` without hanging on a real network connection.
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/reverb_service.dart';

void main() {
  test('forTesting() instance starts out disconnected', () {
    final reverb = ReverbService.forTesting();

    expect(reverb.isConnected, isFalse);
  });

  test('forTesting() instance is independent from the real singleton', () {
    final silent = ReverbService.forTesting();
    final real = ReverbService();

    expect(identical(silent, real), isFalse);
  });

  test('connect() on a forTesting() instance is a no-op — no socket opens', () async {
    final reverb = ReverbService.forTesting();

    await reverb.connect(5);

    expect(reverb.isConnected, isFalse);
  });

  test('connectForUser() on a forTesting() instance is a no-op', () async {
    final reverb = ReverbService.forTesting();

    await reverb.connectForUser(9);

    expect(reverb.isConnected, isFalse);
  });

  test('connectForClient() on a forTesting() instance is a no-op', () async {
    final reverb = ReverbService.forTesting();

    await reverb.connectForClient(3);

    expect(reverb.isConnected, isFalse);
  });

  test('disconnect() on a forTesting() instance does not throw', () {
    final reverb = ReverbService.forTesting();

    expect(() => reverb.disconnect(), returnsNormally);
  });
}
