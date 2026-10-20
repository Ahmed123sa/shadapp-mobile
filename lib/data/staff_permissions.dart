/// Per-client permissions of a company staff member (PLAN_2_MANAGER_TEAMS.md
/// ق٣). Mirrors `User::STAFF_PERMISSION_KEYS` on the backend, which stays the
/// authority — this is only the shape the screens work with.
library;

const staffPermissionKeys = [
  'can_view_chat',
  'can_send_chat',
  'can_view_approvals',
  'can_request_approvals',
  'can_view_meetings',
  'can_join_meetings',
];

/// One group of the sheet / the chips: a "see" switch and the action under it.
class StaffPermissionGroup {
  final String id; // chat | approvals | meetings
  final String view;
  final String act;
  const StaffPermissionGroup(this.id, this.view, this.act);
}

const staffPermissionGroups = [
  StaffPermissionGroup('chat', 'can_view_chat', 'can_send_chat'),
  StaffPermissionGroup('approvals', 'can_view_approvals', 'can_request_approvals'),
  StaffPermissionGroup('meetings', 'can_view_meetings', 'can_join_meetings'),
];

Map<String, bool> allStaffPermissions() => {for (final k in staffPermissionKeys) k: true};

/// Fills missing keys with `true` (null = everything) and switches an action
/// off when its "see" is off.
Map<String, bool> normalizeStaffPermissions(dynamic raw) {
  final map = allStaffPermissions();
  if (raw is Map) {
    for (final k in staffPermissionKeys) {
      if (raw.containsKey(k)) map[k] = raw[k] == true;
    }
  }
  for (final g in staffPermissionGroups) {
    if (map[g.view] != true) map[g.act] = false;
  }
  return map;
}

/// Sets one key and keeps the dependency rule (turning "see" off turns its
/// action off).
Map<String, bool> setStaffPermission(Map<String, bool> map, String key, bool value) =>
    normalizeStaffPermissions({...map, key: value});
