import 'package:go_router/go_router.dart';
import 'api_client.dart';
import '../features/auth/login_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/am/dashboard/am_dashboard_page.dart';
import '../features/am/clients/create_client_page.dart';
import '../features/am/clients/client_detail_page.dart';
import '../features/am/managers/account_managers_page.dart';
import '../features/am/managers/create_manager_page.dart';
import '../features/am/managers/manager_detail_page.dart';
import '../features/am/workspace/am_workspace_page.dart';
import '../features/am/reports/reports_page.dart';
import '../features/am/settings/admin_settings_page.dart';
import '../features/signature/signature_page.dart';
import '../features/preview/preview_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/am/reports/audit_log_page.dart';
import '../features/profile/profile_page.dart';
import '../features/settings/settings_page.dart';

GoRouter createRouter(ApiClient api, {String initialLocation = '/login'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/preview', builder: (_, __) => const PreviewPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/dashboard', builder: (_, state) {
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 2;
        return DashboardPage(initialTab: tab);
      }),
      GoRoute(path: '/signature', builder: (_, __) => const SignaturePage()),
      GoRoute(path: '/am/dashboard', builder: (_, __) => const AmDashboardPage()),
      GoRoute(path: '/am/clients/create', builder: (_, __) => const CreateClientPage()),
      GoRoute(path: '/am/clients/:id', builder: (_, state) => ClientDetailPage(clientId: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/am/managers', builder: (_, __) => const AccountManagersPage()),
      GoRoute(path: '/am/managers/create', builder: (_, __) => const CreateManagerPage()),
      GoRoute(path: '/am/managers/:id/edit', builder: (_, state) => CreateManagerPage(managerId: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/am/managers/:id/detail', builder: (_, state) => ManagerDetailPage(managerId: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/am/workspace/:id', builder: (_, state) {
        final wsId = int.tryParse(state.pathParameters['id'] ?? '');
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '');
        return AmWorkspacePage(workspaceId: wsId, initialTabIndex: tab ?? 0);
      }),
      GoRoute(path: '/am/reports', builder: (_, __) => const ReportsPage()),
      GoRoute(path: '/am/audit-logs', builder: (_, __) => const AuditLogPage()),
      GoRoute(path: '/am/settings', builder: (_, __) => const AdminSettingsPage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
    ],
  );
}
