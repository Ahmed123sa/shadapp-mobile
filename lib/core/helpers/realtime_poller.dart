import 'dart:async';

import '../reverb_service.dart';

/// Periodic fallback refresh for screens that also receive live updates over
/// the Reverb WebSocket.
///
/// The socket is the primary transport. Polling exists only because it can
/// drop — app backgrounded, flaky mobile network, server restart — and
/// [ReverbService] waits ten seconds before each reconnect attempt, so
/// without a fallback a user could sit on a silent screen. The chat screens
/// used to poll unconditionally every 5s / 15s *on top of* a healthy socket,
/// which meant almost every one of those requests re-fetched data the socket
/// had already delivered.
///
/// So: tick often, but only actually refetch when the socket is down. While
/// it is up, refetch rarely — just often enough to heal a genuinely missed
/// event without the caller having to trust the socket completely.
class RealtimePoller {
  /// How often the timer wakes up. A tick is nearly free when the socket is
  /// healthy: it increments a counter and returns.
  static const Duration tick = Duration(seconds: 5);

  /// While the socket is healthy, refresh once every this many ticks
  /// (12 x 5s = once a minute).
  static const int ticksBetweenSafetyRefreshes = 12;

  final void Function() onRefresh;
  final bool Function() _isLive;

  Timer? _timer;
  int _tickCount = 0;

  /// [isLive] is injectable so this can be tested without a real socket;
  /// production callers leave it null and get the shared [ReverbService].
  RealtimePoller({required this.onRefresh, bool Function()? isLive})
      : _isLive = isLive ?? (() => ReverbService().isConnected);

  /// Safe to call when already running — restarts from a clean tick count.
  void start() {
    stop();
    _tickCount = 0;
    _timer = Timer.periodic(tick, (_) => _onTick());
  }

  void _onTick() {
    _tickCount++;
    final dueForSafetyRefresh = _tickCount % ticksBetweenSafetyRefreshes == 0;
    if (!_isLive() || dueForSafetyRefresh) {
      onRefresh();
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
