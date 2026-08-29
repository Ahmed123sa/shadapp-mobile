import 'package:go_router/go_router.dart';
import 'api_client.dart';
import '../features/auth/login_page.dart';
import '../features/auth/forgot_password_page.dart';
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
import '../features/notifications/notifications_page.dart';
import '../features/am/reports/audit_log_page.dart';
import '../features/profile/profile_page.dart';
import '../features/settings/settings_page.dart';

const _publicLocations = ['/login', '/forgot-password'];

GoRouter createRouter(ApiClient api, {String initialLocation = '/login'}) {
  return GoRouter(
    initialLocation: initialLocation,
    // Guards two cases the old cold-boot-only initialLocation check missed:
    // a stale deep link opened after the token is gone (e.g. tapping an old
    // notification, or api_client.dart's onSessionExpired sending the app to
    // /login mid-session), and a logged-in user landing back on /login (e.g.
    // the same stale-deep-link case, but before login). Runs on every
    // navigation, not just at startup. See docs/mobile-review-2026-08.md, P0 #1.
    redirect: (context, state) async {
      final loggedIn = await api.getToken() != null;
      final goingToPublic = _publicLocations.contains(state.matchedLocation);
      if (!loggedIn) {
        return goingToPublic ? null : '/login';
      }
      if (goingToPublic) {
        final role = await api.getRole();
        return (role == 'client' || role == 'sub_user') ? '/dashboard' : '/am/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(path: '/dashboard', builder: (_, state) {
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 2;
        return DashboardPage(initialTab: tab);
      }),
      GoRoute(path: '/signature', builder: (_, __) => const SignaturePage()),
      GoRoute(path: '/am/dashboard', builder: (_, __) => const AmDashboardPage()),
      GoRoute(path: '/am/clients/create', builder: (_, __) => const CreateClientPage()),
      // int.tryParse(...) ?? -1 rather than int.parse(...)! : a malformed id
      // (stale/hand-edited deep link) now reaches the screen as an
      // obviously-invalid id instead of throwing FormatException out of the
      // builder (a crash screen). Each of these screens already has a tested
      // "fetch failed" error state — -1 just routes into that existing path
      // instead of a new one. See docs/mobile-review-2026-08.md, P1 #5.
      GoRoute(path: '/am/clients/:id', builder: (_, state) => ClientDetailPage(clientId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1)),
      GoRoute(path: '/am/managers', builder: (_, __) => const AccountManagersPage()),
      GoRoute(path: '/am/managers/create', builder: (_, __) => const CreateManagerPage()),
      GoRoute(path: '/am/managers/:id/edit', builder: (_, state) => CreateManagerPage(managerId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1)),
      GoRoute(path: '/am/managers/:id/detail', builder: (_, state) => ManagerDetailPage(managerId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1)),
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
