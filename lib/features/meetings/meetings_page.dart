import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/luxe/tokens.dart';
import '../../core/theme.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../core/helpers/meeting_helpers.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/error_state.dart';
import '../../models/meeting.dart';
import '../../providers/meeting_provider.dart';

class MeetingsPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with a mocked
  // MeetingProvider instead of hitting the network.
  final MeetingProvider? meetingProvider;
  final ApiClient? api;
  const MeetingsPage({super.key, this.meetingProvider, this.api});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final MeetingProvider _meetingProvider = widget.meetingProvider ?? MeetingProvider();
  List<Meeting> _meetings = [];
  bool _loading = true;
  // Kept even though nothing sets it (see below) — matches the original,
  // which declared this but never actually assigned it on a failed fetch
  // either, so ErrorState was always dead code in practice. Not "fixed"
  // here since that's a behavior change, not a relocation.
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = _api.workspaceId;
    setState(() { _loading = true; _error = null; });
    if (wsId != null) {
      await _meetingProvider.fetchForWorkspace(wsId);
      // Same as the original try/catch: a failed fetch just leaves the list
      // empty rather than surfacing _error (see the field comment above).
      _meetings = _meetingProvider.error == null ? _meetingProvider.meetings : [];
    } else {
      // No known workspace yet (see docs/state-layer-migration-plan.md,
      // P0-1) — nothing to fetch, not "assume workspace 1".
      _meetings = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  String _time(String? dt) {
    if (dt == null) return '';
    try {
      // The API sends UTC; show the phone's local time (Egypt), like the
      // calendar block next to it already does.
      final parsed = DateTime.parse(dt).toLocal();
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) { return dt; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final l10n = AppLocalizations.of(context)!;

    final now = DateTime.now();
    final upcoming = _meetings.where((m) {
      if (m.status != 'scheduled') return false;
      try {
        final scheduledAt = DateTime.parse(m.scheduledAt!);
        return scheduledAt.isAfter(now);
      } catch (_) { return true; }
    }).toList();
    final past = _meetings.where((m) {
      if (m.status != 'scheduled') return true;
      try {
        final scheduledAt = DateTime.parse(m.scheduledAt!);
        return scheduledAt.isBefore(now);
      } catch (_) { return false; }
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
          children: [
            LuxePageTitle(l10n.dashboard_meetings),
            if (_meetings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text(l10n.meetings_noMeetings, style: Lx.text(context, size: 14, color: Lx.muted))),
              ),
            if (upcoming.isNotEmpty) ...[
              LuxeKind(l10n.meetings_upcoming),
              const SizedBox(height: 8),
              ...upcoming.map((m) => _meetingCard(m, true)),
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: 8),
              LuxeKind(l10n.meetings_previous),
              const SizedBox(height: 8),
              ...past.map((m) => _meetingCard(m, false)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _calendar(Meeting m) {
    DateTime? d;
    try {
      d = DateTime.parse(m.scheduledAt!).toLocal();
    } catch (_) {}
    if (d == null) return const SizedBox(width: 46);
    final locale = Localizations.localeOf(context).toString();
    return Container(
      width: 58,
      padding: const EdgeInsetsDirectional.only(end: 12),
      decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: Lx.line))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(DateFormat.MMM(locale).format(d).toUpperCase(), style: Lx.text(context, size: 9.5, color: Lx.crimsonInk).copyWith(letterSpacing: 1.9)),
        Text('${d.day}', style: Lx.display(context, size: 26).copyWith(height: 1.1)),
      ]),
    );
  }

  Widget _meetingCard(Meeting m, bool isUpcoming) {
    final l10n = AppLocalizations.of(context)!;
    DateTime? when;
    try {
      when = DateTime.parse(m.scheduledAt!).toLocal();
    } catch (_) {}
    final sub = [
      // Upcoming cards carry the date in the calendar block; past ones show it inline.
      if (!isUpcoming && when != null) DateFormat('EEE d MMM', Localizations.localeOf(context).toString()).format(when),
      _time(m.scheduledAt),
      if (m.durationMinutes != null) '${m.durationMinutes} min',
    ].where((e) => e.isNotEmpty).join(' · ');
    final isDone = m.status == 'completed' || (!isUpcoming && m.status != 'cancelled');
    return LuxeCard(
      key: ValueKey('meeting-card-${m.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (isUpcoming) ...[_calendar(m), const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, style: Lx.text(context, size: isUpcoming ? 15 : 14.5, weight: FontWeight.w500)),
              if (sub.isNotEmpty) Text(sub, style: Lx.text(context, size: 12.5, color: Lx.muted)),
              if (!isUpcoming) ...[
                const SizedBox(height: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  LuxeStatusDot(status: m.status == 'cancelled' ? LxStatus.bad : isDone ? LxStatus.off : LxStatus.wait),
                  const SizedBox(width: 7),
                  Text(statusLabels(l10n)[m.status] ?? m.status, style: Lx.text(context, size: 12, color: Lx.ink2)),
                ]),
              ],
            ]),
          ),
        ]),
        if (m.status == 'scheduled' && m.link != null)
          Builder(
            builder: (ctx) {
              final joinStatus = getMeetingJoinStatus(m.scheduledAt!, AppLocalizations.of(ctx)!);
              // subuser-review-plan.md م٦ — joining a meeting maps to
              // can_join_meetings, per the plan's action table.
              final canJoin = joinStatus.canJoin && _api.canDo('can_join_meetings');
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: canJoin
                    ? SizedBox(
                        width: double.infinity,
                        child: LuxeButton(
                          key: ValueKey('meeting-join-${m.id}'),
                          label: joinStatus.label,
                          lxIcon: 'video',
                          kind: LuxeButtonKind.primary,
                          onPressed: () async {
                            final uri = Uri.tryParse(m.link!);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      )
                    : joinStatus.canJoin
                        // Time-wise this meeting could be joined, but the
                        // sub-user lacks can_join_meetings.
                        ? LuxeHint(AppLocalizations.of(ctx)!.subuserActionNeedsOwner)
                        : Row(children: [
                            const LuxeStatusDot(status: LxStatus.wait),
                            const SizedBox(width: 8),
                            Text(joinStatus.label, style: Lx.text(context, size: 12, color: Lx.ink2)),
                          ]),
              );
            },
          ),
        if (m.status == 'scheduled' && m.link != null && m.passcode != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Passcode: ${m.passcode}', style: Lx.text(context, size: 11, color: Lx.faint)),
          ),
      ]),
    );
  }
}
