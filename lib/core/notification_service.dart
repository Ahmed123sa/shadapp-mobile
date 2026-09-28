import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

import 'api_client.dart';
import 'app_log.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final notifService = NotificationService();
  await notifService._initLocalNotifications();
  await notifService._showLocalNotification(message);
}

class NotificationService {
  AppLocalizations? l10n;

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

  /// How long the deferred messaging work waits on the platform before giving
  /// up for this launch. Both the APNs device token and `getInitialMessage()`
  /// normally settle in well under a second; if they haven't after this long,
  /// they are not going to.
  static const _messagingTimeout = Duration(seconds: 10);

  /// Sets up notifications. **Never throws, never blocks on the network.**
  ///
  /// This is awaited by `main()` before `runApp()`, so anything that escapes
  /// here stops the app from ever drawing a frame. That is not hypothetical:
  /// the unguarded `getToken()` this used to start with threw
  /// `[firebase_messaging/apns-token-not-set]` on any build that couldn't
  /// register with APNs, which took `runApp()` down with it and launched the
  /// app to a permanently blank screen — the App Store rejected 1.0 (3) for
  /// exactly that. Push is optional; being able to open the app is not.
  Future<void> init() async {
    if (_initialized) return;

    try {
      await _initLocalNotifications();
      await _requestPermission();
    } catch (e, s) {
      // A device that won't show notifications is still a usable app.
      AppLog.error('NotificationService.init.permissions', e, s);
    }

    // Wired before the token work below: these are local stream hookups that
    // can't fail, and they need to be live whether or not this device ever
    // gets a push token.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _messageSubscription = FirebaseMessaging.onMessage.listen(_showLocalNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onMessageOpenedApp?.call(message);
    });

    _firebaseMessaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _registerToken(token);
    });

    _initialized = true;

    // Deliberately not awaited. Both of these depend on messaging state that
    // a device may never reach; the first screen depends on neither, and must
    // not wait for them.
    unawaited(_handleInitialMessage());
    unawaited(_acquireFcmToken());
  }

  /// Delivers the notification that cold-started the app, if there was one.
  ///
  /// Kept off the startup path and bounded, because on iOS
  /// `getInitialMessage()` can simply never complete — it waits on messaging
  /// state that a device without APNs registration never reaches. Awaiting it
  /// inline was the second of the two ways this method used to stop
  /// `runApp()` from ever running. Routing a tapped notification a moment
  /// late costs nothing: `main` queues it if the router isn't up yet and
  /// replays it once it is.
  Future<void> _handleInitialMessage() async {
    try {
      final initialMessage =
          await _firebaseMessaging.getInitialMessage().timeout(_messagingTimeout);
      if (initialMessage != null) {
        onMessageOpenedApp?.call(initialMessage);
      }
    } on TimeoutException {
      // Expected whenever push isn't wired up on this device. Not a
      // Crashlytics non-fatal — see AppLog.info's doc comment.
      AppLog.info(
        'NotificationService',
        'getInitialMessage() did not settle in $_messagingTimeout; '
        'no cold-start notification to route.',
      );
    } catch (e, s) {
      AppLog.error('NotificationService._handleInitialMessage', e, s);
    }
  }

  /// Registers this device for push, out of band and failure-tolerant.
  ///
  /// On iOS `getToken()` throws until APNs has handed the app a device token,
  /// and on plenty of perfectly good builds that never happens: the simulator
  /// never completes APNs registration, and neither does a build whose
  /// provisioning profile is missing the `aps-environment` entitlement. So
  /// the APNs token is waited for explicitly, with a bound, and everything is
  /// caught. The worst case is an app that runs without push.
  Future<void> _acquireFcmToken() async {
    try {
      if (!kIsWeb && Platform.isIOS && !await _waitForApnsToken()) {
        // Expected on the simulator and on any build without the push
        // entitlement — AppLog.info rather than error, so it stays out of
        // Crashlytics instead of firing a non-fatal on every single launch.
        AppLog.info(
          'NotificationService',
          'No APNs token after $_messagingTimeout — skipping push registration for this launch.',
        );
        return;
      }

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _fcmToken = token;
        await _registerToken(token);
      }
    } catch (e, s) {
      AppLog.error('NotificationService._acquireFcmToken', e, s);
    }
  }

  /// Polls for the iOS APNs token until it shows up or [_messagingTimeout]
  /// elapses. Returns whether one arrived.
  Future<bool> _waitForApnsToken() async {
    final deadline = DateTime.now().add(_messagingTimeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await _firebaseMessaging.getAPNSToken() != null) return true;
      } catch (e, s) {
        AppLog.error('NotificationService._waitForApnsToken', e, s);
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
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
          } catch (e, s) {
            // A malformed payload means the tap can't be routed anywhere.
            // Worth knowing about: it means the sender and this app disagree
            // about the notification data shape.
            AppLog.error('NotificationService.onNotificationTapped', e, s);
          }
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
      NotificationDetails(
        android: AndroidNotificationDetails(
          'shadapp_channel_v2',
          l10n?.notificationChannelName ?? 'ShadApp Notifications',
          channelDescription: l10n?.notificationChannelDescription ?? 'App notifications',
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
    } catch (e, s) {
      AppLog.error('NotificationService._registerToken', e, s);
    }
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
