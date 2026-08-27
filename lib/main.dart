import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show FlutterError, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/api_client.dart';
import 'core/router.dart';
import 'core/locale_provider.dart';
import 'core/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/contract_provider.dart';
import 'providers/approval_provider.dart';
import 'providers/client_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/manager_provider.dart';
import 'providers/meeting_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/signature_provider.dart';
import 'providers/sub_user_provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/env.txt');

  // Fail loudly instead of silently shipping a release build that talks to
  // localhost. assets/env.txt is a local dev file (gitignored) — a real
  // deployment must bundle a production env.txt with a real API_BASE_URL
  // before running `flutter build`. See assets/env.txt.example.
  if (kReleaseMode) {
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final isLocalOrInsecure = apiBaseUrl.contains('localhost') ||
        apiBaseUrl.contains('127.0.0.1') ||
        apiBaseUrl.startsWith('http://');
    if (apiBaseUrl.isEmpty || isLocalOrInsecure) {
      throw StateError(
        'Refusing to run a release build with API_BASE_URL="$apiBaseUrl". '
        'Bundle a production assets/env.txt (HTTPS, real host) before building for release.',
      );
    }
  }

  Map<String, String>? pendingNotifData;
  GoRouter? router;

  if (!kIsWeb) {
    await Firebase.initializeApp();

    // Crashlytics has no web implementation, so this whole block stays
    // inside the !kIsWeb branch. Two handlers are needed and they catch
    // different things: FlutterError.onError covers errors thrown inside
    // the widget/framework layer, while PlatformDispatcher.onError covers
    // everything else that reaches the root zone (async gaps, isolate
    // errors). Wiring only the first one silently misses most real crashes.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // Debug runs would otherwise fill the dashboard with crashes from code
    // that is actively being edited.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(kReleaseMode);

    final notificationService = NotificationService();

    // Called when a notification is tapped (including cold start)
    void handleNotificationData(Map<String, String> data) {
      if (router != null) {
        _navigateFromNotification(data, router);
      } else {
        pendingNotifData = data;
      }
    }

    notificationService.onMessageOpenedApp = (message) {
      handleNotificationData(message.data.cast<String, String>());
    };

    notificationService.onLocalNotificationTapped = handleNotificationData;

    await notificationService.init();
  }

  final api = ApiClient();
  await api.init();
  final token = await api.getToken();
  final loggedIn = token != null;
  String initialLocation;
  if (!loggedIn) {
    initialLocation = '/login';
  } else {
    final role = await api.getRole();
    initialLocation = (role == 'client' || role == 'sub_user') ? '/dashboard' : '/am/dashboard';
  }
  router = createRouter(api, initialLocation: initialLocation);

  if (pendingNotifData != null) {
    await _navigateFromNotification(pendingNotifData!, router);
  }

  final localeProvider = LocaleProvider();
  await localeProvider.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContractProvider()),
        ChangeNotifierProvider(create: (_) => ClientProvider()),
        ChangeNotifierProvider(create: (_) => ManagerProvider()),
        ChangeNotifierProvider(create: (_) => ApprovalProvider()),
        ChangeNotifierProvider(create: (_) => MeetingProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => SubUserProvider()),
        ChangeNotifierProvider(create: (_) => SignatureProvider()),
        ChangeNotifierProvider.value(value: localeProvider),
      ],
      child: ShadApp(router: router, localeProvider: localeProvider),
    ),
  );
}

int _fcmTabIndex(String? type, {bool isClient = false}) {
  if (isClient) {
    // Client tabs: 0=contracts, 1=payments, 2=chat, 3=approvals, 4=files
    if (type == null || type == 'chat') return 2;
    if (type.startsWith('contract')) return 0;
    if (type.startsWith('payment')) return 1;
    if (type.startsWith('approval')) return 3;
    return 0;
  }
  // AM workspace tabs: 0=chat, 1=files, 2=contracts, 3=payments, 4=approvals, 5=meetings
  if (type == null || type == 'chat') return 0;
  if (type.startsWith('contract')) return 2;
  if (type.startsWith('payment')) return 3;
  if (type.startsWith('approval')) return 4;
  if (type.startsWith('meeting')) return 5;
  return 0;
}

Future<void> _navigateFromNotification(Map<String, String> data, GoRouter router) async {
  final workspaceId = data['workspace_id'];
  final type = data['type'];
  final role = await ApiClient().getRole();

  if (role == 'client') {
    router.go('/dashboard?tab=${_fcmTabIndex(type, isClient: true)}');
    return;
  }

  if (workspaceId != null) {
    router.go('/am/workspace/$workspaceId?tab=${_fcmTabIndex(type)}');
  } else {
    router.go('/am/dashboard');
  }
}

class ShadApp extends StatefulWidget {
  final GoRouter router;
  final LocaleProvider localeProvider;

  const ShadApp({super.key, required this.router, required this.localeProvider});

  @override
  State<ShadApp> createState() => _ShadAppState();
}

class _ShadAppState extends State<ShadApp> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.localeProvider,
      builder: (context, _) => MaterialApp.router(
        title: 'ShadApp',
        debugShowCheckedModeBanner: false,
        theme: shadTheme(),
        locale: widget.localeProvider.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        routerConfig: widget.router,
      ),
    );
  }
}
