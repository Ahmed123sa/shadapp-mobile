import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/staff_permissions.dart';
import '../../../data/staff_repository.dart';
import '../staff/team_widgets.dart';

/// The "Team" tab inside a client's workspace (STAFF_TEAMS_PLAN.md ف٦): the
/// client's account manager — or the super admin — picks which company staff
/// members work on this client. Every active staff member is listed with an
/// assign / remove button. The backend decides who may do this.
class TeamTab extends StatefulWidget {
  final int? workspaceId;
  final StaffRepository? repository;
  final ApiClient? api;
  // Shown in the permissions sheet when the super admin edits one assignment.
  final String? clientName;
  const TeamTab({super.key, this.workspaceId, this.repository, this.api, this.clientName});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final StaffRepository _repo = widget.repository ?? StaffRepository(api: _api);
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  bool _loadFailed = false;
  String? _error;
  int? _busyId;

  bool get _isManager => _api.role == 'account_manager';

  int? get _wsId => widget.workspaceId ?? _api.workspaceId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = _wsId;
    if (wsId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final rows = await _repo.forWorkspace(wsId);
      if (!mounted) return;
      setState(() {
        _staff = rows;
        _loading = false;
      });
    } catch (e, s) {
      AppLog.error('team_tab._load', e, s);
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _toggle(Map<String, dynamic> m) async {
    final wsId = _wsId;
    if (wsId == null) return;
    final id = m['id'] as int;
    final assigned = m['assigned'] == true;
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      if (assigned) {
        await _repo.unassign(wsId, id);
      } else {
        await _repo.assign(wsId, id);
      }
      if (!mounted) return;
      setState(() {
        if (assigned && m['in_my_team'] == false) {
          _staff.remove(m);
        } else {
          m['assigned'] = !assigned;
          m['permissions'] = assigned ? null : allStaffPermissions();
        }
      });
    } catch (e, s) {
      AppLog.error('team_tab._toggle', e, s);
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.teamTabSaveFailed);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// A manager's "not in your team" row: add the person to his team.
  Future<void> _addToMyTeam(Map<String, dynamic> m) async {
    final id = m['id'] as int;
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await _repo.addToTeam(id);
      if (!mounted) return;
      setState(() => m['in_my_team'] = true);
    } catch (e, s) {
      AppLog.error('team_tab._addToMyTeam', e, s);
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.teamTabSaveFailed);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Super admin: edit one assignment's permissions in a bottom sheet.
  Future<void> _editPermissions(Map<String, dynamic> m) async {
    final wsId = _wsId;
    if (wsId == null) return;
    final res = await showPermissionsSheet(
      context,
      memberName: '${m['name']}',
      fixedWorkspaceId: wsId,
      fixedClientName: widget.clientName ?? '',
      initial: normalizeStaffPermissions(m['permissions']),
    );
    if (res == null) return;
    try {
      await _repo.assign(wsId, m['id'] as int, permissions: res.permissions);
      if (mounted) setState(() => m['permissions'] = res.permissions);
    } catch (e, s) {
      AppLog.error('team_tab._editPermissions', e, s);
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.teamTabSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return const LoadingState();
    final outsiders = _staff.where((m) => m['assigned'] == true && m['in_my_team'] == false).toList();
    final regular = _staff.where((m) => !(m['assigned'] == true && m['in_my_team'] == false)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_isManager ? l10n.teamTabHintManager : l10n.teamTabHint, style: const TextStyle(fontSize: 12, color: Lx.muted)),
          if (_isManager)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('team-open-page'),
                onPressed: () => context.push('/am/my-team'),
                child: Text(l10n.mtOpenTeamPage),
              ),
            ),
          const SizedBox(height: 12),
          if (_loadFailed)
            Text(l10n.teamTabLoadFailed, style: const TextStyle(fontSize: 13, color: Lx.crimson)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: Lx.crimson)),
            ),
          if (!_loadFailed && _staff.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(_isManager ? l10n.teamTabEmptyManager : l10n.teamTabEmpty, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Lx.faint))),
            ),
          for (final m in regular) _row(m, l10n),
          for (final m in outsiders) _outsiderRow(m, l10n),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> m, AppLocalizations l10n) {
    final assigned = m['assigned'] == true;
    final name = (m['name'] as String?) ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Lx.crimson.withAlpha(40),
          backgroundImage: (m['avatar_url'] as String?)?.isNotEmpty == true ? NetworkImage(_api.resolveFileUrl(m['avatar_url'] as String)) : null,
          child: (m['avatar_url'] as String?)?.isNotEmpty == true
              ? null
              : Text(name.isEmpty ? '?' : name.substring(0, 1), style: const TextStyle(color: Lx.crimson, fontWeight: FontWeight.w700)),
        ),
        title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((m['email'] as String?) ?? '', style: const TextStyle(fontSize: 11, color: Lx.muted)),
          if (assigned && m['permissions'] != null) ...[
            const SizedBox(height: 4),
            PermissionChips(permissions: normalizeStaffPermissions(m['permissions'])),
          ],
          if (assigned && _api.role == 'super_admin')
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: ValueKey('team-edit-${m['id']}'),
                onPressed: () => _editPermissions(m),
                child: Text(l10n.mtEditPerms, style: const TextStyle(fontSize: 11)),
              ),
            ),
        ]),
        trailing: OutlinedButton(
          key: ValueKey('team-toggle-${m['id']}'),
          onPressed: _busyId == m['id'] ? null : () => _toggle(m),
          style: OutlinedButton.styleFrom(
            foregroundColor: assigned ? Lx.crimson : Lx.ok,
            side: BorderSide(color: (assigned ? Lx.crimson : Lx.ok).withAlpha(120)),
          ),
          child: Text(assigned ? l10n.teamTabUnassign : l10n.teamTabAssign, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  /// Someone assigned before this client moved to the manager, who is not in
  /// his team (PLAN_2 ق٤): shown apart, with "Add to my team" and "Remove".
  Widget _outsiderRow(Map<String, dynamic> m, AppLocalizations l10n) {
    final name = (m['name'] as String?) ?? '';
    return Card(
      key: ValueKey('team-outsider-${m['id']}'),
      margin: const EdgeInsets.only(bottom: 8),
      color: Lx.wait.withAlpha(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Lx.wait.withAlpha(90))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text((m['email'] as String?) ?? '', style: const TextStyle(fontSize: 11, color: Lx.muted)),
          const SizedBox(height: 4),
          Text('${l10n.mtNotMine} — ${l10n.mtNotMineHint}', style: const TextStyle(fontSize: 11, color: Lx.wait)),
          if (m['permissions'] != null) ...[
            const SizedBox(height: 6),
            PermissionChips(permissions: normalizeStaffPermissions(m['permissions'])),
          ],
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            OutlinedButton(
              key: ValueKey('team-add-mine-${m['id']}'),
              onPressed: _busyId == m['id'] ? null : () => _addToMyTeam(m),
              child: Text(l10n.mtAddMine, style: const TextStyle(fontSize: 12)),
            ),
            OutlinedButton(
              key: ValueKey('team-toggle-${m['id']}'),
              onPressed: _busyId == m['id'] ? null : () => _toggle(m),
              style: OutlinedButton.styleFrom(foregroundColor: Lx.crimson, side: BorderSide(color: Lx.crimson.withAlpha(120))),
              child: Text(l10n.teamTabUnassign, style: const TextStyle(fontSize: 12)),
            ),
          ]),
        ]),
      ),
    );
  }
}
