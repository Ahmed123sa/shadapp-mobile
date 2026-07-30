import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/helpers/meeting_helpers.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/status_badge.dart';

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  final _api = ApiClient();
  List<dynamic> _meetings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = _api.workspaceIdSafe;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.get('/workspaces/$wsId/meetings');
      _meetings = safeList(data['meetings']);
    } catch (_) {
      _meetings = [];
    }
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

    final now = DateTime.now();
    final upcoming = _meetings.where((m) {
      if (m['status'] != 'scheduled') return false;
      try {
        final scheduledAt = DateTime.parse(m['scheduled_at']);
        return scheduledAt.isAfter(now);
      } catch (_) { return true; }
    }).toList();
    final past = _meetings.where((m) {
      if (m['status'] != 'scheduled') return true;
      try {
        final scheduledAt = DateTime.parse(m['scheduled_at']);
        return scheduledAt.isBefore(now);
      } catch (_) { return false; }
    }).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _meetings.isEmpty
          ? const EmptyState(icon: Icons.videocam_outlined, title: 'لا توجد اجتماعات')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (upcoming.isNotEmpty) ...[
                  Text('Upcoming / القادمة', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                  const SizedBox(height: 12),
                  ...upcoming.map((m) => _meetingCard(m, true)),
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Previous / السابقة', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                  const SizedBox(height: 12),
                  ...past.map((m) => _meetingCard(m, false)),
                ],
              ],
            ),
      ),
    );
  }

  Widget _meetingCard(dynamic m, bool isUpcoming) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 44,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(_time(m['scheduled_at']), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isUpcoming ? ShadColors.gold : ShadColors.textSecondary, fontFamily: 'Archivo')),
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
                Expanded(child: Text(m['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo'))),
                if (m['status'] != null) StatusBadge(status: m['status']),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.schedule, size: 12, color: ShadColors.textSecondary),
                const SizedBox(width: 4),
                Text(_time(m['scheduled_at']), style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                if (m['duration_minutes'] != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.timer, size: 12, color: ShadColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${m['duration_minutes']} min', style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                ],
              ]),
              if (m['status'] == 'scheduled' && m['link'] != null) ...[
                const SizedBox(height: 10),
                Builder(
                  builder: (ctx) {
                    final joinStatus = getMeetingJoinStatus(m['scheduled_at']);
                    return SizedBox(
                      width: double.infinity,
                      child: joinStatus.canJoin
                          ? OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.tryParse(m['link'] as String);
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
                if (m['passcode'] != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.lock, size: 12, color: ShadColors.textDisabled),
                    const SizedBox(width: 4),
                    Text('Passcode: ${m['passcode']}', style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
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


