import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/helpers/realtime_poller.dart';

// The point of RealtimePoller is that it does *less* work while the Reverb
// socket is healthy. That's invisible at a glance — a bug here looks like
// "chat is slightly stale" or "the app is quietly burning data", neither of
// which anyone notices quickly. Hence the tests.
void main() {
  final tick = RealtimePoller.tick;
  final safetyEvery = RealtimePoller.ticksBetweenSafetyRefreshes;

  test('refreshes on every tick while the socket is down', () {
    fakeAsync((async) {
      var refreshes = 0;
      RealtimePoller(onRefresh: () => refreshes++, isLive: () => false).start();

      async.elapse(tick * 5);

      expect(refreshes, 5);
    });
  });

  test('stays quiet between safety refreshes while the socket is healthy', () {
    fakeAsync((async) {
      var refreshes = 0;
      RealtimePoller(onRefresh: () => refreshes++, isLive: () => true).start();

      // One tick short of the safety refresh: the socket is delivering
      // updates, so the poller should not have hit the API at all yet.
      async.elapse(tick * (safetyEvery - 1));
      expect(refreshes, 0);

      // ...but it still heals a possibly-missed event once a minute.
      async.elapse(tick);
      expect(refreshes, 1);
    });
  });

  test('picks the fast path back up the moment the socket drops', () {
    fakeAsync((async) {
      var refreshes = 0;
      var live = true;
      RealtimePoller(onRefresh: () => refreshes++, isLive: () => live).start();

      async.elapse(tick * 3);
      expect(refreshes, 0);

      live = false;
      async.elapse(tick * 3);
      expect(refreshes, 3);
    });
  });

  test('stop() cancels the timer', () {
    fakeAsync((async) {
      var refreshes = 0;
      final poller =
          RealtimePoller(onRefresh: () => refreshes++, isLive: () => false);
      poller.start();

      async.elapse(tick * 2);
      expect(refreshes, 2);

      poller.stop();
      async.elapse(tick * 10);
      expect(refreshes, 2, reason: 'no further refreshes after stop()');
    });
  });

  test('start() on an already-running poller does not double up', () {
    fakeAsync((async) {
      var refreshes = 0;
      final poller =
          RealtimePoller(onRefresh: () => refreshes++, isLive: () => false);
      poller.start();
      // didChangeAppLifecycleState calls _startPolling() on resume without
      // stopping first, so this has to be safe.
      poller.start();

      async.elapse(tick * 4);

      expect(refreshes, 4, reason: 'one timer, not two');
      poller.stop();
    });
  });
}
