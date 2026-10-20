import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/staff_permissions.dart';
import '../../../data/staff_repository.dart';
import 'team_widgets.dart';

/// The account manager's "Team" screen (PLAN_2_MANAGER_TEAMS.md ف٦): the
/// company staff in his team, the clients each one is linked to with their
/// permissions, and a toggleable list of the other company staff to add from.
/// Built in the app's current look; Plan 1 re-skins it without touching logic.
class MyTeamPage extends StatefulWidget {
  final StaffRepository? repository;
  final ApiClient? api;
  const MyTeamPage({super.key, this.repository, this.api});

  @override
  State<MyTeamPage> createState() => _MyTeamPageState();
}

class _MyTeamPageState extends State<MyTeamPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final StaffRepository _repo = widget.repository ?? StaffRepository(api: _api);

  List<Map<String, dynamic>> _team = [];
  List<Map<String, dynamic>> _others = [];
  bool _loading = true;
  bool _failed = false;
  String? _error;
  bool _showOthers = false;
  final Set<int> _picked = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _maps(dynamic v) => safeList(v).whereType<Map<String, dynamic>>().toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final res = await _repo.myTeam();
      if (!mounted) return;
      setState(() {
        _team = _maps(res['team']);
        _others = _maps(res['others']);
        _loading = false;
      });
    } catch (e, s) {
      AppLog.error('my_team_page._load', e, s);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Runs a mutation, then reloads; shows a generic message when it fails.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
    } catch (e, s) {
      AppLog.error('my_team_page._run', e, s);
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.mtSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPicked() => _run(() async {
        for (final id in _picked.toList()) {
          await _repo.addToTeam(id);
        }
        _picked.clear();
        _showOthers = false;
      });

  Future<void> _remove(Map<String, dynamic> m) async {
    final l10n = AppLocalizations.of(context)!;
    final id = m['id'] as int;
    Map<String, dynamic> impact;
    try {
      impact = await _repo.removalImpact(id);
    } catch (e, s) {
      AppLog.error('my_team_page._remove.impact', e, s);
      if (mounted) setState(() => _error = l10n.mtSaveFailed);
      return;
    }
    if (!mounted) return;
    final count = (impact['count'] as num?)?.toInt() ?? 0;
    final names = safeList(impact['clients']).map((e) => '$e').join('، ');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('mt-remove-dialog'),
        title: Text(l10n.mtRemoveTitle),
        content: Text(count == 0 ? l10n.mtRemoveBodyNone : l10n.mtRemoveBody(count, names)),
        actions: [
          TextButton(key: const ValueKey('mt-remove-cancel'), onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.mtCancel)),
          TextButton(
            key: const ValueKey('mt-remove-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.mtRemoveConfirm, style: const TextStyle(color: ShadColors.crimson)),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _repo.removeFromTeam(id));
  }

  Future<void> _link(Map<String, dynamic> m) async {
    final id = m['id'] as int;
    final linked = _maps(m['assignments']).map((a) => a['workspace_id']).toSet();
    List<Map<String, dynamic>> choices;
    try {
      choices = (await _repo.workspaceChoices()).where((c) => !linked.contains(c['workspace_id'])).toList();
    } catch (e, s) {
      AppLog.error('my_team_page._link.choices', e, s);
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.mtLoadFailed);
      return;
    }
    if (!mounted) return;
    final res = await showPermissionsSheet(context, memberName: '${m['name']}', clients: choices);
    if (res != null) await _run(() => _repo.assign(res.workspaceId, id, permissions: res.permissions));
  }

  Future<void> _edit(Map<String, dynamic> m, Map<String, dynamic> a) async {
    final res = await showPermissionsSheet(
      context,
      memberName: '${m['name']}',
      fixedWorkspaceId: a['workspace_id'] as int,
      fixedClientName: '${a['name'] ?? ''}',
      initial: normalizeStaffPermissions(a['permissions']),
    );
    if (res != null) await _run(() => _repo.assign(res.workspaceId, m['id'] as int, permissions: res.permissions));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mtTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay', color: ShadColors.gold))),
      body: _body(l10n),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_loading) return const LoadingState();
    if (_failed) return ErrorState(message: l10n.mtLoadFailed, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.mtSubtitle, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const ValueKey('mt-toggle-company'),
              onPressed: () => setState(() => _showOthers = !_showOthers),
              icon: Icon(_showOthers ? Icons.expand_less : Icons.person_add_alt_1_outlined, size: 18),
              label: Text(_showOthers ? l10n.mtHideCompany : l10n.mtAddFromCompany),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, key: const ValueKey('mt-error'), style: const TextStyle(fontSize: 13, color: ShadColors.crimson)),
            ),
          if (_showOthers) _othersPanel(l10n),
          const SizedBox(height: 16),
          Row(children: [
            Text(l10n.mtMyTeam, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('${_team.length}', key: const ValueKey('mt-team-count'), style: const TextStyle(fontSize: 13, color: ShadColors.gold, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          if (_team.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text(l10n.mtEmptyTeam, key: const ValueKey('mt-empty'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: ShadColors.textDisabled))),
            ),
          for (final m in _team) _memberCard(m, l10n),
        ],
      ),
    );
  }

  Widget _othersPanel(AppLocalizations l10n) {
    return Container(
      key: const ValueKey('mt-company-panel'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ShadColors.cardAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: ShadColors.gold.withAlpha(90))),
      // The tiles paint on the nearest Material, which the decorated box would hide.
      child: Material(
        type: MaterialType.transparency,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.mtCompanyStaffTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.gold)),
        if (_others.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(l10n.mtNoOtherStaff, key: const ValueKey('mt-no-others'), style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
          ),
        for (final o in _others)
          CheckboxListTile(
            key: ValueKey('mt-pick-${o['id']}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _picked.contains(o['id']),
            onChanged: (v) => setState(() => v == true ? _picked.add(o['id'] as int) : _picked.remove(o['id'])),
            title: Text('${o['name']}', style: const TextStyle(fontSize: 13)),
            subtitle: Text(_teamsLine(o, l10n), style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
          ),
        if (_others.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const ValueKey('mt-add-selected'),
              onPressed: _picked.isEmpty || _busy ? null : _addPicked,
              child: Text(l10n.mtAddN(_picked.length)),
            ),
          ),
        ]),
      ),
    );
  }

  String _teamsLine(Map<String, dynamic> m, AppLocalizations l10n) {
    final teams = _maps(m['other_teams']);
    if (teams.isEmpty) return l10n.mtNotInAnyTeam;
    return l10n.mtInTeams(teams.map((t) => '${t['name']}').join('، '));
  }

  Widget _memberCard(Map<String, dynamic> m, AppLocalizations l10n) {
    final id = m['id'];
    final name = (m['name'] as String?) ?? '';
    final assignments = _maps(m['assignments']);
    final others = _maps(m['other_teams']);
    return Card(
      key: ValueKey('mt-member-$id'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: ShadColors.crimson.withAlpha(40),
              backgroundImage: (m['avatar_url'] as String?)?.isNotEmpty == true ? NetworkImage(_api.resolveFileUrl(m['avatar_url'] as String)) : null,
              child: (m['avatar_url'] as String?)?.isNotEmpty == true
                  ? null
                  : Text(name.isEmpty ? '?' : name.substring(0, 1), style: const TextStyle(color: ShadColors.crimson, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${m['email'] ?? ''}', style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
                if (others.isNotEmpty)
                  Text(l10n.mtInTeams(others.map((t) => '${t['name']}').join('، ')), style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          if (assignments.isEmpty)
            Text(l10n.mtNoClientsLinked, key: ValueKey('mt-no-links-$id'), style: const TextStyle(fontSize: 12, color: ShadColors.textDisabled)),
          for (final a in assignments)
            Container(
              key: ValueKey('mt-link-row-$id-${a['workspace_id']}'),
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ShadColors.cardAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: ShadColors.cardBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${a['name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                PermissionChips(permissions: normalizeStaffPermissions(a['permissions'])),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(key: ValueKey('mt-edit-$id-${a['workspace_id']}'), onPressed: _busy ? null : () => _edit(m, a), child: Text(l10n.mtEdit)),
                  TextButton(
                    key: ValueKey('mt-unlink-$id-${a['workspace_id']}'),
                    onPressed: _busy ? null : () => _run(() => _repo.unassign(a['workspace_id'] as int, id as int)),
                    child: Text(l10n.mtUnlink, style: const TextStyle(color: ShadColors.crimson)),
                  ),
                ]),
              ]),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            OutlinedButton(key: ValueKey('mt-link-$id'), onPressed: _busy ? null : () => _link(m), child: Text(l10n.mtLinkClient, style: const TextStyle(fontSize: 12))),
            OutlinedButton(
              key: ValueKey('mt-remove-$id'),
              onPressed: _busy ? null : () => _remove(m),
              style: OutlinedButton.styleFrom(foregroundColor: ShadColors.crimson, side: BorderSide(color: ShadColors.crimson.withAlpha(120))),
              child: Text(l10n.mtRemoveFromTeam, style: const TextStyle(fontSize: 12)),
            ),
          ]),
        ]),
      ),
    );
  }
}
