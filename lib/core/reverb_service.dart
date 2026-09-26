import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting, VoidCallback;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import 'app_log.dart';

class ReverbService {
  static final ReverbService _instance = ReverbService._();
  factory ReverbService() => _instance;
  ReverbService._() : _silent = false;

  /// Test-only constructor. Produces an independent, non-singleton instance
  /// (mirrors [ApiClient.forTesting]) whose connect*() methods never open a
  /// real WebSocket — no dotenv/network access happens. Channel bookkeeping
  /// (joining/leaving, listener registration) still works under this mode,
  /// which is what lets tests exercise the multi-channel behavior below
  /// without a socket; see [debugChannels] and [debugDispatch]. Screens that
  /// accept an optional `ReverbService?` and wire this through can be pumped
  /// in plain `flutter test` without a real socket connection hanging
  /// `pumpAndSettle`.
  @visibleForTesting
  ReverbService.forTesting() : _silent = true;

  final bool _silent;

  String host = 'localhost';
  String port = '8080';
  String key = 'shadapp-key';
  String scheme = 'ws';

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _streamSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  String? _socketId;

  // plans/notifications-badges-toasts-plan.md ن15 — replaces the old
  // _currentWorkspaceId/_currentUserId/_isClientChannel trio, which meant
  // exactly one channel could be "current" on this connection at a time:
  // chat_page.dart calling connect(wsId) while the dashboard already had
  // connectForClient(cid) active silently dropped the client channel (and
  // with it, the dashboard's notification listeners) for as long as chat was
  // open. All channels this service joins now share the one socket
  // connection, tracked here instead of in separate single-value fields.
  final Set<String> _channels = {};

  @visibleForTesting
  Set<String> get debugChannels => Set.unmodifiable(_channels);

  /// Exposed so ApiClient can attach X-Socket-Id to outgoing requests — see
  /// the header wiring in api_client.dart's _headers() for why.
  String? get socketId => _socketId;

  /// Whether the socket is open *and* the handshake finished.
  ///
  /// Both halves matter: `_channel` is non-null from the moment we start
  /// connecting, but no events arrive until Reverb sends
  /// `pusher:connection_established` and we record a socket id. Screens use
  /// this to decide whether they still need to poll the REST API as a
  /// fallback (see RealtimePoller), so reporting "connected" too early would
  /// let them stop polling while events are still going nowhere.
  bool get isConnected => _channel != null && _socketId != null;
  DateTime _lastNotifTime = DateTime.now().subtract(const Duration(seconds: 1));

  // plans/notifications-badges-toasts-plan.md ن15 — these used to be single
  // nullable callback fields (`void Function(...)? onMessageReceived`), so
  // whichever screen called `reverb.onXxx = callback` *last* silently
  // replaced whatever an earlier screen had registered. They're now listener
  // lists: every registered callback fires, and addXxxListener() returns a
  // callback that removes just that one listener again, for use in a
  // screen's dispose().
  final List<void Function(Map<String, dynamic>)> _messageReceivedListeners = [];
  final List<void Function(Map<String, dynamic>)> _messageUpdatedListeners = [];
  final List<void Function()> _contractStatusChangedListeners = [];
  final List<void Function(Map<String, dynamic>)> _paymentScheduleChangedListeners = [];
  final List<void Function(Map<String, dynamic>)> _notificationReceivedListeners = [];
  // REALTIME_PLAN.md Stage 5 — mirrors the dashboard's onWorkspaceStatusChanged
  // / onPaymentStatusChanged (see src/lib/echo.ts's subscribeToWorkspace).
  // Payload shapes match the backend events' broadcastWith():
  // WorkspaceStatusChanged -> {workspace_id, status, activated_at};
  // PaymentStatusChanged -> {payment_id, status, amount, currency}.
  final List<void Function(Map<String, dynamic>)> _workspaceStatusChangedListeners = [];
  final List<void Function(Map<String, dynamic>)> _paymentStatusChangedListeners = [];

  VoidCallback addMessageReceivedListener(void Function(Map<String, dynamic>) listener) {
    _messageReceivedListeners.add(listener);
    return () => _messageReceivedListeners.remove(listener);
  }

  VoidCallback addMessageUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _messageUpdatedListeners.add(listener);
    return () => _messageUpdatedListeners.remove(listener);
  }

  VoidCallback addContractStatusChangedListener(void Function() listener) {
    _contractStatusChangedListeners.add(listener);
    return () => _contractStatusChangedListeners.remove(listener);
  }

  VoidCallback addPaymentScheduleChangedListener(void Function(Map<String, dynamic>) listener) {
    _paymentScheduleChangedListeners.add(listener);
    return () => _paymentScheduleChangedListeners.remove(listener);
  }

  VoidCallback addNotificationReceivedListener(void Function(Map<String, dynamic>) listener) {
    _notificationReceivedListeners.add(listener);
    return () => _notificationReceivedListeners.remove(listener);
  }

  VoidCallback addWorkspaceStatusChangedListener(void Function(Map<String, dynamic>) listener) {
    _workspaceStatusChangedListeners.add(listener);
    return () => _workspaceStatusChangedListeners.remove(listener);
  }

  VoidCallback addPaymentStatusChangedListener(void Function(Map<String, dynamic>) listener) {
    _paymentStatusChangedListeners.add(listener);
    return () => _paymentStatusChangedListeners.remove(listener);
  }

  void configure({String? host, String? port, String? key}) {
    if (host != null) this.host = host;
    if (port != null) this.port = port;
    if (key != null) this.key = key;
  }

  void _autoConfigureFromApi() {
    host = dotenv.env['REVERB_HOST'] ?? host;
    port = dotenv.env['REVERB_PORT'] ?? port;
    key = dotenv.env['REVERB_KEY'] ?? key;
    scheme = dotenv.env['REVERB_SCHEME'] ?? scheme;
    final baseUrl = ApiClient().baseUrl;
    final uri = Uri.tryParse(baseUrl);
    if (uri != null && uri.host.isNotEmpty && uri.host != 'localhost') {
      host = uri.host;
    }
  }

  /// Joins `workspace.{workspaceId}` — additive: any channel already joined
  /// (e.g. a dashboard's own user/client channel) stays joined.
  Future<void> connect(int workspaceId) async {
    await _join('workspace.$workspaceId');
  }

  Future<void> connectForUser(int userId) async {
    await _join('App.Models.User.$userId');
  }

  Future<void> connectForClient(int clientId) async {
    await _join('App.Models.Client.$clientId');
  }

  /// Leaves `workspace.{workspaceId}` without touching any other channel
  /// this service has joined — what chat_page.dart's dispose() now calls
  /// instead of the old "reconnect to the client/user channel to overwrite
  /// the workspace one" workaround, which no longer applies now that joining
  /// a workspace never dropped that other channel in the first place.
  Future<void> leaveWorkspace(int workspaceId) async {
    await _leave('workspace.$workspaceId');
  }

  Future<void> leaveUserChannel(int userId) async {
    await _leave('App.Models.User.$userId');
  }

  Future<void> leaveClientChannel(int clientId) async {
    await _leave('App.Models.Client.$clientId');
  }

  Future<void> _join(String channel) async {
    if (_channels.contains(channel)) return;
    _channels.add(channel);
    if (_silent) return;
    if (_channel == null) {
      await _connectAndListen();
    } else {
      await _subscribePrivateChannel(channel);
    }
  }

  Future<void> _leave(String channel) async {
    if (!_channels.remove(channel)) return;
    if (_silent) return;
    _send({'event': 'pusher:unsubscribe', 'data': {'channel': 'private-$channel'}});
  }

  Future<void> _connectAndListen() async {
    await _disconnectSocket();
    _autoConfigureFromApi();

    final url = '$scheme://$host:$port/app/$key?protocol=7&client=flutter&version=7.6.2';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready;

      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _send({'event': 'pusher:ping', 'data': {}});
      });

      _streamSubscription = _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          _dispatchEvent(msg['event'] as String?, msg['data']);
        },
        onError: (_) => _reconnect(),
        onDone: () => _reconnect(),
      );
    } catch (_) {
      _reconnect();
    }
  }

  /// Handles one decoded socket frame — pulled out of the stream listener
  /// above so [debugDispatch] can feed it a frame directly in tests, without
  /// a real socket. `pusher:connection_established` re-subscribes every
  /// channel currently in [_channels] (not just one), which is also what
  /// makes reconnecting after a drop restore every channel that was joined
  /// before, not only whichever single one the old design remembered.
  void _dispatchEvent(String? event, dynamic rawData) {
    if (event == 'pusher:connection_established') {
      _socketId = _extractSocketId(rawData);
      // A real connection is up — the next drop should retry quickly
      // again, not carry over a long backoff from a previous outage.
      _reconnectAttempts = 0;
      for (final channel in _channels) {
        _subscribePrivateChannel(channel);
      }
    } else if (event == 'message.sent') {
      final payload = jsonDecode(rawData as String) as Map<String, dynamic>;
      for (final l in List.of(_messageReceivedListeners)) {
        l(payload);
      }
    } else if (event == 'message.updated') {
      final payload = jsonDecode(rawData as String) as Map<String, dynamic>;
      for (final l in List.of(_messageUpdatedListeners)) {
        l(payload);
      }
    } else if (event == 'contract.status_changed') {
      for (final l in List.of(_contractStatusChangedListeners)) {
        l();
      }
    } else if (event == 'payment.schedule.changed') {
      final payload = jsonDecode(rawData as String) as Map<String, dynamic>;
      for (final l in List.of(_paymentScheduleChangedListeners)) {
        l(payload);
      }
    } else if (event == 'workspace.status_changed') {
      final payload = jsonDecode(rawData as String) as Map<String, dynamic>;
      for (final l in List.of(_workspaceStatusChangedListeners)) {
        l(payload);
      }
    } else if (event == 'payment.status_changed') {
      final payload = jsonDecode(rawData as String) as Map<String, dynamic>;
      for (final l in List.of(_paymentStatusChangedListeners)) {
        l(payload);
      }
    } else if (event == 'Illuminate\\Notifications\\Events\\BroadcastNotificationCreated') {
      final now = DateTime.now();
      if (now.difference(_lastNotifTime) < const Duration(seconds: 1)) return;
      _lastNotifTime = now;
      final payload = jsonDecode(rawData as String) as Map<String, dynamic>;
      for (final l in List.of(_notificationReceivedListeners)) {
        l(payload);
      }
    }
  }

  /// Test-only: feeds a decoded socket frame straight into [_dispatchEvent],
  /// so a forTesting() instance can prove listener registration/removal and
  /// multi-channel behavior without a real socket. `rawData` should be
  /// whatever the real frame's `data` field would be — a JSON-encoded string
  /// for the payload-carrying events, matching what jsonDecode(data) expects
  /// above (e.g. `jsonEncode({'id': 1})`), or a plain map for
  /// `pusher:connection_established`.
  @visibleForTesting
  void debugDispatch(String event, dynamic rawData) => _dispatchEvent(event, rawData);

  String? _extractSocketId(dynamic data) {
    if (data is String) {
      try {
        final parsed = jsonDecode(data);
        return parsed['socket_id'] as String?;
      } catch (_) {
        return null;
      }
    }
    if (data is Map) {
      return data['socket_id'] as String?;
    }
    return null;
  }

  /// Subscribes to `private-{channel}` after authorizing with the backend.
  ///
  /// Every channel this app uses (`App.Models.User.*`, `App.Models.Client.*`,
  /// `workspace.*`) is declared private in routes/channels.php on the server,
  /// which is where the actual access check happens — a workspace channel is
  /// only granted to the manager or client who owns it. This method has no
  /// fallback to a plain/public subscription on purpose: subscribing to the
  /// public channel name skips that check completely, so silently falling
  /// back to it on any failure (missing socket id, auth error, network
  /// error) would mean "couldn't prove I'm allowed in" quietly turns into
  /// "let me in anyway". If auth fails, retry once the socket is ready
  /// rather than degrade to an unauthenticated subscription.
  Future<void> _subscribePrivateChannel(String channel) async {
    if (_socketId == null) {
      // Not connected yet — pusher:connection_established will retry this
      // once we have a socket id.
      return;
    }
    try {
      final api = ApiClient();
      final response = await api.post('/broadcasting/auth', {
        'channel_name': 'private-$channel',
        'socket_id': _socketId,
      });
      final auth = response['auth'] as String?;
      if (auth != null) {
        _send({'event': 'pusher:subscribe', 'data': {'channel': 'private-$channel', 'auth': auth}});
      }
    } catch (e, s) {
      // Intentionally no fallback subscription — see the doc comment above.
      // Still logged: "realtime silently stopped working" is otherwise one
      // of the hardest things in this app to diagnose from a bug report.
      AppLog.error('ReverbService._subscribePrivateChannel($channel)', e, s);
    }
  }

  void _send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {
      // Deliberately silent, and deliberately not reported: this fires on
      // every keepalive ping that lands on a socket which closed a moment
      // ago. onDone/onError already trigger a reconnect, so there is
      // nothing to do here and reporting it would just be noise.
    }
  }

  /// The WebSocket's `onError` and `onDone` handlers in [_connectAndListen]
  /// both call this — a real socket drop typically fires both, not just one.
  /// Without the cancel-and-replace below, that used to schedule two
  /// independent 10-second timers; both would eventually fire and each would
  /// open its own connection, since [_connectAndListen] reassigning
  /// `_channel` does not by itself stop the *previous* connection's stream
  /// subscription from still delivering events. Two live connections meant
  /// every server broadcast arrived twice — this is what caused chat
  /// messages to appear duplicated (see docs/mobile-review-2026-08-round2.md,
  /// #2 and #3). Cancelling any pending timer here means only the most
  /// recent onError/onDone call ends up scheduling the reconnect.
  ///
  /// Backoff (10s, 20s, 40s, capped at 60s) exists so a genuinely-down
  /// server doesn't get hit every 10 seconds forever; it resets to 10s the
  /// moment a connection actually succeeds (see `_reconnectAttempts = 0`
  /// above), so a single blip doesn't leave the app slow to recover later.
  void _reconnect() {
    _reconnectTimer?.cancel();
    final delaySeconds = (10 * (1 << _reconnectAttempts)).clamp(10, 60);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_channels.isNotEmpty) {
        _connectAndListen();
      }
    });
  }

  Future<void> _disconnectSocket() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _socketId = null;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  /// Full teardown — every joined channel and every registered listener is
  /// dropped, and the socket (if any) is closed. Used at logout, where the
  /// identity everything was authorized under is about to disappear. Screens
  /// leaving a *single* channel of their own (e.g. chat closing) should use
  /// leaveWorkspace()/leaveUserChannel()/leaveClientChannel() instead — this
  /// method is deliberately not selective.
  void disconnect() {
    _channels.clear();
    _messageReceivedListeners.clear();
    _messageUpdatedListeners.clear();
    _contractStatusChangedListeners.clear();
    _paymentScheduleChangedListeners.clear();
    _notificationReceivedListeners.clear();
    _workspaceStatusChangedListeners.clear();
    _paymentStatusChangedListeners.clear();
    _reconnectAttempts = 0;
    _disconnectSocket();
  }
}
