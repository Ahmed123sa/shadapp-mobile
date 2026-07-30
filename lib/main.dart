import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'providers/client_provider.dart';
import 'providers/notification_provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/env.txt');

  Map<String, String>? pendingNotifData;
  GoRouter? router;

  if (!kIsWeb) {
    await Firebase.initializeApp();
    final notificationService = NotificationService();

    // تُستدعى هذه الدالة عند الضغط على الإشعار (بما في ذلك cold start)
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
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
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
  void initState() {
    super.initState();
    widget.localeProvider.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.localeProvider.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
    );
  }
}
