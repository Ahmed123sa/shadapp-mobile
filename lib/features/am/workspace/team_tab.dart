import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/staff_repository.dart';

/// The "Team" tab inside a client's workspace (STAFF_TEAMS_PLAN.md ف٦): the
/// client's account manager — or the super admin — picks which company staff
/// members work on this client. Every active staff member is listed with an
/// assign / remove button. The backend decides who may do this.
class TeamTab extends StatefulWidget {
  final int? workspaceId;
  final StaffRepository? repository;
  final ApiClient? api;
  const TeamTab({super.key, this.workspaceId, this.repository, this.api});

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
      setState(() => m['assigned'] = !assigned);
    } catch (e, s) {
      AppLog.error('team_tab._toggle', e, s);
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.teamTabSaveFailed);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return const LoadingState();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.teamTabHint, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
          const SizedBox(height: 12),
          if (_loadFailed)
            Text(l10n.teamTabLoadFailed, style: const TextStyle(fontSize: 13, color: ShadColors.crimson)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: ShadColors.crimson)),
            ),
          if (!_loadFailed && _staff.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(l10n.teamTabEmpty, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: ShadColors.textDisabled))),
            ),
          for (final m in _staff) _row(m, l10n),
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
          backgroundColor: ShadColors.crimson.withAlpha(40),
          backgroundImage: (m['avatar_url'] as String?)?.isNotEmpty == true ? NetworkImage(_api.resolveFileUrl(m['avatar_url'] as String)) : null,
          child: (m['avatar_url'] as String?)?.isNotEmpty == true
              ? null
              : Text(name.isEmpty ? '?' : name.substring(0, 1), style: const TextStyle(color: ShadColors.crimson, fontWeight: FontWeight.w700)),
        ),
        title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text((m['email'] as String?) ?? '', style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
        trailing: OutlinedButton(
          key: ValueKey('team-toggle-${m['id']}'),
          onPressed: _busyId == m['id'] ? null : () => _toggle(m),
          style: OutlinedButton.styleFrom(
            foregroundColor: assigned ? ShadColors.crimson : ShadColors.success,
            side: BorderSide(color: (assigned ? ShadColors.crimson : ShadColors.success).withAlpha(120)),
          ),
          child: Text(assigned ? l10n.teamTabUnassign : l10n.teamTabAssign, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
