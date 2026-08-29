import 'api_client.dart';

// Pulled out of main.dart so it can be unit tested — main.dart itself can
// only be exercised through a full widget/integration test (nothing in this
// codebase does that), so anything left in there had zero coverage. This is
// exactly where P0 #2 (main.dart:144's missing sub_user branch) went
// unnoticed. See docs/mobile-review-2026-08.md, P0 #2 and its "الترتيب
// المقترح" item 7.
//
// Deliberately pure: [fcmTabIndex] is a plain mapping, and
// [notificationTarget] only *resolves* a target path — it does not touch a
// GoRouter. main.dart's `_navigateFromNotification` wrapper is the only
// caller and does the actual `router.go(...)`, so a test here needs no
// GoRouter/widget-tree setup at all.

/// Maps a notification's `type` to the tab index the client dashboard or AM
/// workspace screen should open on. The two screens have unrelated tab
/// orderings (see the inline comments below), which is why this takes
/// [isClient] rather than assuming one layout.
int fcmTabIndex(String? type, {bool isClient = false}) {
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

/// Resolves a tapped notification's payload into the app route it should
/// open. `client` and `sub_user` both land on the client dashboard — see
/// main.dart:93's cold-boot `initialLocation` logic, which this must stay
/// consistent with (the P0 #2 bug was exactly this list missing `sub_user`).
/// Every other role is staff, and goes to the AM workspace for the
/// notification's workspace if one is present, otherwise the AM dashboard.
///
/// [api] is optional so tests can inject an [ApiClient.forTesting] with a
/// role already set, instead of hitting the real singleton/secure storage.
Future<String> notificationTarget(Map<String, String> data, {ApiClient? api}) async {
  final workspaceId = data['workspace_id'];
  final type = data['type'];
  final role = await (api ?? ApiClient()).getRole();

  if (role == 'client' || role == 'sub_user') {
    return '/dashboard?tab=${fcmTabIndex(type, isClient: true)}';
  }

  if (workspaceId != null) {
    return '/am/workspace/$workspaceId?tab=${fcmTabIndex(type)}';
  }
  return '/am/dashboard';
}
