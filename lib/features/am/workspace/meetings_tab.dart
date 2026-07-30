import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/helpers/meeting_helpers.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/status_badge.dart';

class MeetingsTab extends StatefulWidget {
  final int? workspaceId;
  const MeetingsTab({super.key, this.workspaceId});

  @override
  State<MeetingsTab> createState() => _MeetingsTabState();
}

class _MeetingsTabState extends State<MeetingsTab> {
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
    final isSA = _api.role == 'super_admin';
    setState(() { _loading = true; _error = null; });
    try {
      final data = isSA
          ? await _api.get('/all-meetings')
          : await _api.get('/workspaces/${widget.workspaceId ?? _api.workspaceId}/meetings');
      _meetings = safeList(data['meetings']);
    } catch (_) {
      _error = 'فشل تحميل الاجتماعات';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CreateMeetingForm(workspaceId: widget.workspaceId, onCreated: _load),
    );
  }

  void _showEditSheet(dynamic m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _EditMeetingForm(meeting: m, workspaceId: widget.workspaceId, onUpdated: _load),
    );
  }

  Future<void> _cancelMeeting(dynamic m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الاجتماع'),
        content: Text('هل تريد إلغاء "${m['title']}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ابقاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error),
            child: const Text('إلغاء الاجتماع', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.patch('/meetings/${m['id']}/cancel', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إلغاء الاجتماع')));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إلغاء الاجتماع')));
    }
  }

  Future<void> _completeMeeting(dynamic m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إكمال الاجتماع'),
        content: Text('هل تريد تحويل "${m['title']}" إلى مكتمل؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.success),
            child: const Text('نعم، انتهى', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.patch('/meetings/${m['id']}/complete', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إكمال الاجتماع')));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إكمال الاجتماع')));
    }
  }

  String _formatDate(String? dt) {
    if (dt == null) return '';
    try {
      final parsed = DateTime.parse(dt);
      final time = '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      return '${parsed.year}/${parsed.month}/${parsed.day} $time';
    } catch (_) { return dt; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState(itemCount: 3);
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
                  Text('الاجتماعات القادمة', style: ShadTypography.sectionHeader),
                  const SizedBox(height: 8),
                  ...upcoming.map(_meetingCard),
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('الاجتماعات السابقة', style: ShadTypography.sectionHeader),
                  const SizedBox(height: 8),
                  ...past.map(_meetingCard),
                ],
              ],
            ),
      ),
      floatingActionButton: _api.role == 'super_admin'
          ? null
          : FloatingActionButton(
              onPressed: _showCreateSheet,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _meetingCard(dynamic m) {
    final isScheduled = m['status'] == 'scheduled';
    final isSA = _api.role == 'super_admin';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.videocam, size: 20, color: ShadColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(m['title'] ?? '', style: ShadTypography.cardTitle)),
            if (m['status'] != null) StatusBadge(status: m['status']),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.schedule, size: 14, color: ShadColors.textSecondary),
            const SizedBox(width: 4),
            Text(_formatDate(m['scheduled_at']), style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
            if (m['duration_minutes'] != null) ...[
              const SizedBox(width: 12),
              const Icon(Icons.timer, size: 14, color: ShadColors.textSecondary),
              const SizedBox(width: 4),
              Text('${m['duration_minutes']} دقيقة', style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
            ],
          ]),
          if (m['notes'] != null) ...[
            const SizedBox(height: 6),
            Text(m['notes'], style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
          ],
          if (m['contract'] != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.description, size: 14, color: ShadColors.textSecondary),
              const SizedBox(width: 4),
              Text('العقد: ${m['contract']['title'] ?? m['contract']['reference_no'] ?? ''}', style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
            ]),
          ],
          if (m['passcode'] != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.lock, size: 14, color: ShadColors.textSecondary),
              const SizedBox(width: 4),
              Text('رمز المرور: ${m['passcode']}', style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: m['passcode']));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم نسخ رمز المرور')));
                },
                child: const Icon(Icons.copy, size: 14, color: ShadColors.primary),
              ),
            ]),
          ],
          if (m['status'] == 'scheduled' && m['link'] != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (ctx) {
                final joinStatus = getMeetingJoinStatus(m['scheduled_at']);
                return Row(children: [
                  Expanded(
                    child: joinStatus.canJoin
                        ? OutlinedButton.icon(
                            onPressed: () => launchUrl(Uri.parse(m['link']), mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.videocam, size: 18),
                            label: Text(joinStatus.label),
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
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: m['link']));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم نسخ الرابط')));
                    },
                    tooltip: 'نسخ الرابط',
                  ),
                ]);
              },
            ),
          ],
          if (isScheduled && !isSA) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditSheet(m),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _completeMeeting(m),
                  icon: const Icon(Icons.check_circle_outline, size: 16, color: ShadColors.success),
                  label: const Text('انتهى', style: TextStyle(color: ShadColors.success)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _cancelMeeting(m),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: ShadColors.error),
                  label: Text('إلغاء', style: TextStyle(color: ShadColors.error)),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _CreateMeetingForm extends StatefulWidget {
  final int? workspaceId;
  final VoidCallback onCreated;
  const _CreateMeetingForm({this.workspaceId, required this.onCreated});

  @override
  State<_CreateMeetingForm> createState() => _CreateMeetingFormState();
}

class _CreateMeetingFormState extends State<_CreateMeetingForm> {
  final _api = ApiClient();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  int _duration = 30;
  int? _selectedContractId;
  List<dynamic> _contracts = [];
  bool _loadingContracts = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    try {
      final data = await _api.get('/workspaces/$wsId/contracts');
      if (mounted) {
        setState(() {
          _contracts = safeList(data['contracts'])
              .where((c) => c['status'] == 'active' || c['status'] == 'company_approved')
              .toList();
          _loadingContracts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContracts = false);
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || (widget.workspaceId ?? _api.workspaceId) == null) return;
    setState(() => _saving = true);
    final scheduledAt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final tzOffset = scheduledAt.timeZoneOffset;
    final tzSign = tzOffset.isNegative ? '-' : '+';
    final tzHours = tzOffset.inHours.abs().toString().padLeft(2, '0');
    final tzMinutes = (tzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final scheduledAtIso = '${scheduledAt.toIso8601String()}$tzSign$tzHours:$tzMinutes';
    try {
      await _api.post('/workspaces/${widget.workspaceId ?? _api.workspaceId}/meetings', {
        'title': _titleController.text.trim(),
        'scheduled_at': scheduledAtIso,
        'duration_minutes': _duration,
        'notes': _notesController.text.trim(),
        if (_selectedContractId != null) 'contract_id': _selectedContractId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إنشاء الاجتماع')));
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إنشاء الاجتماع')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('إنشاء اجتماع جديد', style: ShadTypography.cardTitle),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'عنوان الاجتماع *', hintText: 'مثال: مناقشة العقد'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'التاريخ'),
                  child: Text('${_date.year}/${_date.month}/${_date.day}'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _time);
                  if (t != null) setState(() => _time = t);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'الوقت'),
                  child: Text('${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _duration,
            decoration: const InputDecoration(labelText: 'المدة (دقيقة)'),
            items: [15, 30, 45, 60, 90, 120].map((d) => DropdownMenuItem(value: d, child: Text('$d دقيقة'))).toList(),
            onChanged: (v) { if (v != null) setState(() => _duration = v); },
          ),
          const SizedBox(height: 12),
          if (!_loadingContracts && _contracts.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: _selectedContractId,
              decoration: const InputDecoration(labelText: 'العقد المرتبط'),
              items: _contracts.map((c) => DropdownMenuItem(value: c['id'] as int?, child: Text(c['title'] ?? '#${c['id']}'))).toList(),
              onChanged: (v) { if (v != null) setState(() => _selectedContractId = v); },
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'ملاحظات', hintText: 'رابط الاجتماع أو ملاحظات إضافية...'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                   : const Text('إنشاء الاجتماع'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _EditMeetingForm extends StatefulWidget {
  final dynamic meeting;
  final int? workspaceId;
  final VoidCallback onUpdated;
  const _EditMeetingForm({required this.meeting, this.workspaceId, required this.onUpdated});

  @override
  State<_EditMeetingForm> createState() => _EditMeetingFormState();
}

class _EditMeetingFormState extends State<_EditMeetingForm> {
  final _api = ApiClient();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _date;
  late TimeOfDay _time;
  late int _duration;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.meeting;
    _titleController = TextEditingController(text: m['title'] ?? '');
    _notesController = TextEditingController(text: m['notes'] ?? '');
    try {
      _date = DateTime.parse(m['scheduled_at']);
      _time = TimeOfDay(hour: _date.hour, minute: _date.minute);
      _date = DateTime(_date.year, _date.month, _date.day);
    } catch (_) {
      _date = DateTime.now().add(const Duration(days: 1));
      _time = const TimeOfDay(hour: 10, minute: 0);
    }
    _duration = m['duration_minutes'] ?? 30;
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final scheduledAt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final tzOffset = scheduledAt.timeZoneOffset;
    final tzSign = tzOffset.isNegative ? '-' : '+';
    final tzHours = tzOffset.inHours.abs().toString().padLeft(2, '0');
    final tzMinutes = (tzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final scheduledAtIso = '${scheduledAt.toIso8601String()}$tzSign$tzHours:$tzMinutes';
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    try {
      await _api.put('/workspaces/$wsId/meetings/${widget.meeting['id']}', {
        'title': _titleController.text.trim(),
        'scheduled_at': scheduledAtIso,
        'duration_minutes': _duration,
        'notes': _notesController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تحديث الاجتماع')));
        Navigator.pop(context);
        widget.onUpdated();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحديث الاجتماع')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('تعديل الاجتماع', style: ShadTypography.cardTitle),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'عنوان الاجتماع *'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'التاريخ'),
                  child: Text('${_date.year}/${_date.month}/${_date.day}'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _time);
                  if (t != null) setState(() => _time = t);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'الوقت'),
                  child: Text('${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _duration,
            decoration: const InputDecoration(labelText: 'المدة (دقيقة)'),
            items: [15, 30, 45, 60, 90, 120].map((d) => DropdownMenuItem(value: d, child: Text('$d دقيقة'))).toList(),
            onChanged: (v) { if (v != null) setState(() => _duration = v); },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ التعديلات'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
