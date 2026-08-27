import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/helpers/meeting_helpers.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/status_badge.dart';
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
    final wsId = _api.workspaceIdSafe;
    setState(() { _loading = true; _error = null; });
    await _meetingProvider.fetchForWorkspace(wsId);
    // Same as the original try/catch: a failed fetch just leaves the list
    // empty rather than surfacing _error (see the field comment above).
    _meetings = _meetingProvider.error == null ? _meetingProvider.meetings : [];
    if (mounted) setState(() => _loading = false);
  }

  String _time(String? dt) {
    if (dt == null) return '';
    try {
      final parsed = DateTime.parse(dt);
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: _meetings.isEmpty
          ? EmptyState(icon: Icons.videocam_outlined, title: l10n.meetings_noMeetings)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (upcoming.isNotEmpty) ...[
                  Text(l10n.meetings_upcoming, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                  const SizedBox(height: 12),
                  ...upcoming.map((m) => _meetingCard(m, true)),
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(l10n.meetings_previous, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                  const SizedBox(height: 12),
                  ...past.map((m) => _meetingCard(m, false)),
                ],
              ],
            ),
      ),
    );
  }

  Widget _meetingCard(Meeting m, bool isUpcoming) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 44,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(_time(m.scheduledAt), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isUpcoming ? ShadColors.gold : ShadColors.textSecondary, fontFamily: 'Archivo')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ShadColors.card.withAlpha(isUpcoming ? 255 : 180),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ShadColors.cardBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 3, height: 32, decoration: BoxDecoration(
                  color: isUpcoming ? ShadColors.gold : ShadColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                )),
                const SizedBox(width: 12),
                Expanded(child: Text(m.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo'))),
                // Meeting.status defaults to 'scheduled' when the API omits
                // it, so this always renders now — a minor behavior change
                // from the original (which hid the badge entirely on a null
                // status). Accepted rather than threading an extra
                // "was this field present" flag through the model for an
                // edge case that shouldn't occur in real responses.
                StatusBadge(status: m.status),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.schedule, size: 12, color: ShadColors.textSecondary),
                const SizedBox(width: 4),
                Text(_time(m.scheduledAt), style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                if (m.durationMinutes != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.timer, size: 12, color: ShadColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${m.durationMinutes} min', style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                ],
              ]),
              if (m.status == 'scheduled' && m.link != null) ...[
                const SizedBox(height: 10),
                Builder(
                  builder: (ctx) {
                    final joinStatus = getMeetingJoinStatus(m.scheduledAt!, AppLocalizations.of(ctx)!);
                    return SizedBox(
                      width: double.infinity,
                      child: joinStatus.canJoin
                          ? OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.tryParse(m.link!);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.videocam, size: 16),
                              label: Text(joinStatus.label),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ShadColors.success,
                                side: const BorderSide(color: ShadColors.success),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8)),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: ShadColors.meetingBlueBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ShadColors.meetingBlueBorder.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.schedule, size: 14, color: ShadColors.meetingBlue),
                                  const SizedBox(width: 6),
                                  Text(joinStatus.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.meetingBlue)),
                                ],
                              ),
                            ),
                    );
                  },
                ),
                if (m.passcode != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.lock, size: 12, color: ShadColors.textDisabled),
                    const SizedBox(width: 4),
                    Text('Passcode: ${m.passcode}', style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                  ]),
                ],
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}


