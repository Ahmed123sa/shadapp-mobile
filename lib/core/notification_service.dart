import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final notifService = NotificationService();
  await notifService._initLocalNotifications();
  await notifService._showLocalNotification(message);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  NotificationService._();

  factory NotificationService() => _instance;

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _api = ApiClient();

  String? _fcmToken;
  bool _initialized = false;
  StreamSubscription? _messageSubscription;

  void Function(RemoteMessage)? onMessageOpenedApp;
  void Function(Map<String, String>)? onLocalNotificationTapped;

  Future<void> init() async {
    if (_initialized) return;

    await _initLocalNotifications();
    await _requestPermission();

    _fcmToken = await _firebaseMessaging.getToken();
    if (_fcmToken != null) {
      _registerToken(_fcmToken!);
    }

    _firebaseMessaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _registerToken(token);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _messageSubscription = FirebaseMessaging.onMessage.listen(_showLocalNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onMessageOpenedApp?.call(message);
    });

    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      onMessageOpenedApp?.call(initialMessage);
    }

    _initialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        final payloadStr = response.payload;
        if (payloadStr != null) {
          try {
            final data = Map<String, String>.from(jsonDecode(payloadStr));
            onLocalNotificationTapped?.call(data);
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _requestPermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] as String? ?? 'ShadApp';
    final body = notification?.body ?? data['body'] as String?;
    if (body == null) return;

    final payload = data.isNotEmpty ? jsonEncode(data) : null;

    final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'shadapp_channel_v2',
          'إشعارات ShadApp',
          channelDescription: 'إشعارات التطبيق',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> _registerToken(String token) async {
    final deviceType = _getDeviceType();
    try {
      await _api.post('/notifications/register-token', {
        'token': token,
        'device_type': deviceType,
      });
    } catch (_) {}
  }

  String _getDeviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  String? get fcmToken => _fcmToken;

  void dispose() {
    _messageSubscription?.cancel();
  }
}
