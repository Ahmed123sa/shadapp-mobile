import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import 'app_log.dart';

class ReverbService {
  static final ReverbService _instance = ReverbService._();
  factory ReverbService() => _instance;
  ReverbService._() : _silent = false;

  /// Test-only constructor. Produces an independent, non-singleton instance
  /// (mirrors [ApiClient.forTesting]) whose connect*() methods are no-ops —
  /// no WebSocket is ever opened, no dotenv/network access happens. Screens
  /// that accept an optional `ReverbService?` and wire this through can be
  /// pumped in plain `flutter test` without a real socket connection hanging
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
  int? _currentWorkspaceId;
  int? _currentUserId;
  bool _isClientChannel = false;
  String? _socketId;

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
  void Function(Map<String, dynamic>)? onMessageReceived;
  void Function(Map<String, dynamic>)? onMessageUpdated;
  void Function()? onContractStatusChanged;
  void Function(Map<String, dynamic>)? onPaymentScheduleChanged;
  void Function(Map<String, dynamic>)? onNotificationReceived;

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

  Future<void> connect(int workspaceId) async {
    if (_silent) return;
    _currentWorkspaceId = workspaceId;
    _currentUserId = null;
    _isClientChannel = false;
    await _connectAndListen();
  }

  Future<void> connectForUser(int userId) async {
    if (_silent) return;
    _currentUserId = userId;
    _isClientChannel = false;
    _currentWorkspaceId = null;
    await _connectAndListen();
    await _subscribePrivateChannel('App.Models.User.$userId');
  }

  Future<void> connectForClient(int clientId) async {
    if (_silent) return;
    _currentUserId = clientId;
    _isClientChannel = true;
    _currentWorkspaceId = null;
    await _connectAndListen();
    await _subscribePrivateChannel('App.Models.Client.$clientId');
  }

  Future<void> _connectAndListen() async {
    await _disconnect();
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
          final event = msg['event'] as String?;
          if (event == 'pusher:connection_established') {
            _socketId = _extractSocketId(msg['data']);
            // A real connection is up — the next drop should retry quickly
            // again, not carry over a long backoff from a previous outage.
            _reconnectAttempts = 0;
            if (_currentUserId != null) {
              final channel = _isClientChannel
                  ? 'App.Models.Client.$_currentUserId'
                  : 'App.Models.User.$_currentUserId';
              _subscribePrivateChannel(channel);
            }
            if (_currentWorkspaceId != null) {
              // Must go through the authenticated path — see
              // _subscribePrivateChannel for why. This used to call
              // _subscribe() directly, which asked Reverb for the *public*
              // "workspace.{id}" channel and skipped auth entirely: with the
              // server broadcasting on the matching private channel, that
              // meant workspace chat/payment events were reachable by
              // anyone who could guess a workspace id.
              _subscribePrivateChannel('workspace.$_currentWorkspaceId');
            }
          } else if (event == 'message.sent') {
            final payload = jsonDecode(msg['data'] as String) as Map<String, dynamic>;
            onMessageReceived?.call(payload);
          } else if (event == 'message.updated') {
            final payload = jsonDecode(msg['data'] as String) as Map<String, dynamic>;
            onMessageUpdated?.call(payload);
          } else if (event == 'contract.status_changed') {
            onContractStatusChanged?.call();
          } else if (event == 'payment.schedule.changed') {
            final payload = jsonDecode(msg['data'] as String) as Map<String, dynamic>;
            onPaymentScheduleChanged?.call(payload);
          } else if (event == 'Illuminate\\Notifications\\Events\\BroadcastNotificationCreated') {
            final now = DateTime.now();
            if (now.difference(_lastNotifTime) < const Duration(seconds: 1)) return;
            _lastNotifTime = now;
            final payload = jsonDecode(msg['data'] as String) as Map<String, dynamic>;
            onNotificationReceived?.call(payload);
          }
        },
        onError: (_) => _reconnect(),
        onDone: () => _reconnect(),
      );
    } catch (_) {
      _reconnect();
    }
  }

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
      if (_currentWorkspaceId != null) {
        connect(_currentWorkspaceId!);
      } else if (_currentUserId != null) {
        if (_isClientChannel) {
          connectForClient(_currentUserId!);
        } else {
          connectForUser(_currentUserId!);
        }
      }
    });
  }

  Future<void> _disconnect() async {
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

  void disconnect() {
    _currentWorkspaceId = null;
    _currentUserId = null;
    _reconnectAttempts = 0;
    _disconnect();
  }
}
