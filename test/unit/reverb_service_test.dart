// Step 0 of the state-layer migration plan (docs/state-layer-migration-plan.md,
// "الخطوة صفر"): ReverbService.forTesting() mirrors ApiClient.forTesting() —
// an independent, non-singleton instance whose connect*() methods never open
// a real WebSocket. This is what let Path D's six realtime screens accept an
// optional `ReverbService? reverb` and be pumped in plain `flutter test`
// without hanging on a real network connection.
import 'dart:convert';
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

  test('addWorkspaceStatusChangedListener can be registered and unsubscribed', () {
    final reverb = ReverbService.forTesting();

    final unsubscribe = reverb.addWorkspaceStatusChangedListener((payload) {});

    expect(unsubscribe, returnsNormally);
  });

  test('addPaymentStatusChangedListener can be registered and unsubscribed', () {
    final reverb = ReverbService.forTesting();

    final unsubscribe = reverb.addPaymentStatusChangedListener((payload) {});

    expect(unsubscribe, returnsNormally);
  });

  // ---------------------------------------------------------------
  // plans/notifications-badges-toasts-plan.md ن15 — the actual bug: only one
  // channel could be "current" at a time, so chat_page.dart calling
  // connect(wsId) after the dashboard had already called connectForClient()
  // silently dropped the client channel (and with it, the notifications
  // listener) for as long as chat stayed open.
  // ---------------------------------------------------------------

  group('multi-channel — joining one channel does not drop another', () {
    test('connecting to a workspace after a client channel keeps both joined', () async {
      final reverb = ReverbService.forTesting();

      await reverb.connectForClient(9);
      await reverb.connect(5);

      expect(reverb.debugChannels, containsAll(<String>['App.Models.Client.9', 'workspace.5']));
    });

    test('connecting to a workspace after a user channel keeps both joined', () async {
      final reverb = ReverbService.forTesting();

      await reverb.connectForUser(3);
      await reverb.connect(7);

      expect(reverb.debugChannels, containsAll(<String>['App.Models.User.3', 'workspace.7']));
    });

    test('leaving the workspace channel does not touch the client channel', () async {
      final reverb = ReverbService.forTesting();
      await reverb.connectForClient(9);
      await reverb.connect(5);

      await reverb.leaveWorkspace(5);

      expect(reverb.debugChannels, contains('App.Models.Client.9'));
      expect(reverb.debugChannels, isNot(contains('workspace.5')));
    });

    test('leaving the workspace channel does not touch the user channel', () async {
      final reverb = ReverbService.forTesting();
      await reverb.connectForUser(3);
      await reverb.connect(7);

      await reverb.leaveWorkspace(7);

      expect(reverb.debugChannels, contains('App.Models.User.3'));
      expect(reverb.debugChannels, isNot(contains('workspace.7')));
    });

    test('disconnect() clears every joined channel', () async {
      final reverb = ReverbService.forTesting();
      await reverb.connectForClient(9);
      await reverb.connect(5);

      reverb.disconnect();

      expect(reverb.debugChannels, isEmpty);
    });

    test('joining the same channel twice does not duplicate it', () async {
      final reverb = ReverbService.forTesting();

      await reverb.connect(5);
      await reverb.connect(5);

      expect(reverb.debugChannels.where((c) => c == 'workspace.5').length, 1);
    });
  });

  // ---------------------------------------------------------------
  // Listener lists — every registered callback must fire, and removing one
  // must not affect the others. debugDispatch() feeds a decoded frame
  // straight into the same handling a real socket message goes through,
  // without opening a socket (still available on forTesting() instances —
  // channel/listener bookkeeping is pure Dart state, not network I/O).
  // ---------------------------------------------------------------

  group('listener lists — replacing the old single-callback fields', () {
    test('two message-received listeners both fire for the same event', () {
      final reverb = ReverbService.forTesting();
      var firstCalls = 0;
      var secondCalls = 0;
      reverb.addMessageReceivedListener((payload) => firstCalls++);
      reverb.addMessageReceivedListener((payload) => secondCalls++);

      reverb.debugDispatch('message.sent', jsonEncode({'id': 1}));

      expect(firstCalls, 1);
      expect(secondCalls, 1);
    });

    test('unsubscribing one listener does not stop the other from firing', () {
      final reverb = ReverbService.forTesting();
      var firstCalls = 0;
      var secondCalls = 0;
      final unsubscribeFirst = reverb.addMessageReceivedListener((payload) => firstCalls++);
      reverb.addMessageReceivedListener((payload) => secondCalls++);

      unsubscribeFirst();
      reverb.debugDispatch('message.sent', jsonEncode({'id': 1}));

      expect(firstCalls, 0);
      expect(secondCalls, 1);
    });

    test('contract status listener fires with no payload', () {
      final reverb = ReverbService.forTesting();
      var calls = 0;
      reverb.addContractStatusChangedListener(() => calls++);

      reverb.debugDispatch('contract.status_changed', null);

      expect(calls, 1);
    });

    test('notification listener receives the decoded payload', () {
      final reverb = ReverbService.forTesting();
      Map<String, dynamic>? received;
      reverb.addNotificationReceivedListener((payload) => received = payload);

      reverb.debugDispatch('Illuminate\\Notifications\\Events\\BroadcastNotificationCreated', jsonEncode({'id': 'n1'}));

      expect(received, {'id': 'n1'});
    });
  });
}
