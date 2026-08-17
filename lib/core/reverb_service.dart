import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';

class ReverbService {
  static final ReverbService _instance = ReverbService._();
  factory ReverbService() => _instance;
  ReverbService._();

  String host = 'localhost';
  String port = '8080';
  String key = 'shadapp-key';
  String scheme = 'ws';

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  int? _currentWorkspaceId;
  int? _currentUserId;
  bool _isClientChannel = false;
  String? _socketId;
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
    _currentWorkspaceId = workspaceId;
    _currentUserId = null;
    _isClientChannel = false;
    await _connectAndListen();
  }

  Future<void> connectForUser(int userId) async {
    _currentUserId = userId;
    _isClientChannel = false;
    _currentWorkspaceId = null;
    await _connectAndListen();
    await _subscribePrivateChannel('App.Models.User.$userId');
  }

  Future<void> connectForClient(int clientId) async {
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

      _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          final event = msg['event'] as String?;
          if (event == 'pusher:connection_established') {
            _socketId = _extractSocketId(msg['data']);
            if (_currentUserId != null) {
              final channel = _isClientChannel
                  ? 'App.Models.Client.$_currentUserId'
                  : 'App.Models.User.$_currentUserId';
              _subscribePrivateChannel(channel);
            }
            if (_currentWorkspaceId != null) {
              _subscribe('workspace.$_currentWorkspaceId');
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

  Future<void> _subscribePrivateChannel(String channel) async {
    if (_socketId == null) {
      _subscribe(channel);
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
      } else {
        _subscribe(channel);
      }
    } catch (_) {
      _subscribe(channel);
    }
  }

  void _subscribe(String channel) {
    _send({'event': 'pusher:subscribe', 'data': {'channel': channel}});
  }

  void _send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _reconnect() async {
    await Future.delayed(const Duration(seconds: 10));
    if (_currentWorkspaceId != null) {
      connect(_currentWorkspaceId!);
    } else if (_currentUserId != null) {
      if (_isClientChannel) {
        connectForClient(_currentUserId!);
      } else {
        connectForUser(_currentUserId!);
      }
    }
  }

  Future<void> _disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _socketId = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void disconnect() {
    _currentWorkspaceId = null;
    _currentUserId = null;
    _disconnect();
  }
}
