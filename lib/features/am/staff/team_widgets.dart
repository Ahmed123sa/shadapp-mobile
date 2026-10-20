import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/luxe/tokens.dart';
import '../../../data/staff_permissions.dart';

/// Shared by the manager's Team screen and the workspace Team tab
/// (PLAN_2_MANAGER_TEAMS.md ف٦). Every widget has a fixed [ValueKey] so the
/// tests survive the Luxe re-skin (Plan 1).

String _groupLabel(AppLocalizations l10n, String id) =>
    id == 'chat' ? l10n.mtPermChat : id == 'approvals' ? l10n.mtPermApprovals : l10n.mtPermMeetings;

String _actLabel(AppLocalizations l10n, String id) =>
    id == 'chat' ? l10n.mtSend : id == 'approvals' ? l10n.mtRequest : l10n.mtJoin;

/// What a staff member may do on one client, as chips: "Chat · view + send".
/// A group that is off is struck through; with nothing on it says "No access".
class PermissionChips extends StatelessWidget {
  final Map<String, bool> permissions;
  const PermissionChips({super.key, required this.permissions});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final anyOn = staffPermissionGroups.any((g) => permissions[g.view] == true);
    if (!anyOn) {
      return Text(l10n.mtNone, key: const ValueKey('permission-chips-none'), style: const TextStyle(fontSize: 11, color: Lx.muted));
    }
    return Wrap(
      key: const ValueKey('permission-chips'),
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final g in staffPermissionGroups)
          if (permissions[g.view] != true)
            Container(
              key: ValueKey('chip-off-${g.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Lx.line2)),
              child: Text(_groupLabel(l10n, g.id),
                  style: const TextStyle(fontSize: 10, color: Lx.faint, decoration: TextDecoration.lineThrough)),
            )
          else
            Container(
              key: ValueKey('chip-on-${g.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Lx.wait.withAlpha(90))),
              child: Text(
                '${_groupLabel(l10n, g.id)} · ${l10n.mtView}${permissions[g.act] == true ? ' + ${_actLabel(l10n, g.id)}' : ''}',
                style: const TextStyle(fontSize: 10, color: Lx.muted),
              ),
            ),
      ],
    );
  }
}

/// The result of [showPermissionsSheet].
class PermissionsResult {
  final int workspaceId;
  final Map<String, bool> permissions;
  const PermissionsResult(this.workspaceId, this.permissions);
}

/// Bottom sheet that links a staff member to one of the manager's clients and
/// sets what they may do there. With [fixedWorkspaceId] (editing an existing
/// link, or the super admin inside a workspace) the client is shown, not chosen.
Future<PermissionsResult?> showPermissionsSheet(
  BuildContext context, {
  required String memberName,
  List<Map<String, dynamic>> clients = const [], // [{workspace_id, name}]
  int? fixedWorkspaceId,
  String? fixedClientName,
  Map<String, bool>? initial,
}) {
  return showModalBottomSheet<PermissionsResult>(
    context: context,
    backgroundColor: Lx.sheet,
    isScrollControlled: true,
    builder: (_) => _PermissionsSheet(
      memberName: memberName,
      clients: clients,
      fixedWorkspaceId: fixedWorkspaceId,
      fixedClientName: fixedClientName,
      initial: initial,
    ),
  );
}

class _PermissionsSheet extends StatefulWidget {
  final String memberName;
  final List<Map<String, dynamic>> clients;
  final int? fixedWorkspaceId;
  final String? fixedClientName;
  final Map<String, bool>? initial;
  const _PermissionsSheet({required this.memberName, required this.clients, this.fixedWorkspaceId, this.fixedClientName, this.initial});

  @override
  State<_PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends State<_PermissionsSheet> {
  late Map<String, bool> _perms = normalizeStaffPermissions(widget.initial);
  int? _wsId;

  @override
  void initState() {
    super.initState();
    _wsId = widget.fixedWorkspaceId;
  }

  String _rowLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'can_view_chat': return l10n.mtSeeChat;
      case 'can_send_chat': return l10n.mtSendChat;
      case 'can_view_approvals': return l10n.mtSeeApprovals;
      case 'can_request_approvals': return l10n.mtRequestApprovals;
      case 'can_view_meetings': return l10n.mtSeeMeetings;
      default: return l10n.mtJoinMeetings;
    }
  }

  Widget _switch(AppLocalizations l10n, String key, {bool indent = false, bool enabled = true}) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent ? 16 : 0),
      child: SwitchListTile(
        key: ValueKey('mt-sw-$key'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(_rowLabel(l10n, key), style: TextStyle(fontSize: 13, color: enabled ? Lx.ink : Lx.faint)),
        value: _perms[key] == true,
        onChanged: enabled ? (v) => setState(() => _perms = setStaffPermission(_perms, key, v)) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fixed = widget.fixedWorkspaceId != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(widget.memberName, style: const TextStyle(fontSize: 11, color: Lx.faint)),
            const SizedBox(height: 2),
            Text(l10n.mtLinkClient, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Text(l10n.mtPickClient, style: const TextStyle(fontSize: 11, color: Lx.muted)),
            const SizedBox(height: 4),
            if (fixed)
              Container(
                key: const ValueKey('mt-client-fixed'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Lx.surface, borderRadius: BorderRadius.circular(10)),
                child: Text(widget.fixedClientName ?? ''),
              )
            else if (widget.clients.isEmpty)
              Text(l10n.mtNoClientsToLink, key: const ValueKey('mt-no-clients'), style: const TextStyle(fontSize: 12, color: Lx.muted))
            else
              DropdownButtonFormField<int>(
                key: const ValueKey('mt-client-select'),
                initialValue: _wsId,
                isExpanded: true,
                hint: Text(l10n.mtPickClientHint),
                items: [
                  for (final c in widget.clients)
                    DropdownMenuItem<int>(value: c['workspace_id'] as int, child: Text('${c['name']}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _wsId = v),
              ),
            const SizedBox(height: 16),
            Text(l10n.mtPermOnClient, style: const TextStyle(fontSize: 11, color: Lx.muted)),
            for (final g in staffPermissionGroups) ...[
              const SizedBox(height: 8),
              Text(_groupLabel(l10n, g.id), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Lx.wait)),
              _switch(l10n, g.view),
              _switch(l10n, g.act, indent: true, enabled: _perms[g.view] == true),
            ],
            const SizedBox(height: 8),
            Text(l10n.mtDepNote, style: const TextStyle(fontSize: 11, color: Lx.muted)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('mt-save'),
                  onPressed: _wsId == null ? null : () => Navigator.pop(context, PermissionsResult(_wsId!, _perms)),
                  child: Text(l10n.mtSave),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(key: const ValueKey('mt-cancel'), onPressed: () => Navigator.pop(context), child: Text(l10n.mtCancel)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
