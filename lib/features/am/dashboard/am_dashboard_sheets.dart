// Extracted from am_dashboard_page.dart as part of بند ٨ (file splitting).
// Three self-contained bottom-sheet widgets that only ever talked to the
// parent page via constructor params/callbacks — made public (renamed from
// their original private names) since a public widget is required to live in
// its own file, same reasoning as contract_detail_sheet.dart's extraction.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../providers/meeting_provider.dart';

/// Mockup sheet header: `.grab` (38×4, margin-bottom 16) + h3 serif 22.
Widget _sheetHead(BuildContext context, String title, {Widget? trailing}) => Column(children: [
      Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Lx.line2, borderRadius: BorderRadius.circular(2)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Expanded(child: Text(title, style: Lx.display(context, size: 22))),
          if (trailing != null) trailing,
        ]),
      ),
    ]);

class ManagerClientsSheet extends StatelessWidget {
  final String managerName;
  final List<dynamic> clients;
  final void Function(Map<String, dynamic> client) onClientTap;
  const ManagerClientsSheet({super.key, required this.managerName, required this.clients, required this.onClientTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sheetHead(context, managerName),
        if (clients.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(l10n.amNoClientsAvailable, style: Lx.text(context, size: 13.5, color: Lx.faint))),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: clients.length,
              itemBuilder: (_, i) {
                final c = clients[i];
                final ws = c['workspace'] as Map<String, dynamic>?;
                final active = ws?['status'] == 'active';
                final name = c['company_name'] as String? ?? '';
                // Mockup `.doc` row.
                return InkWell(
                  onTap: () => onClientTap(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: i == clients.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
                    child: Row(children: [
                      LuxeAvatar(initial: name.isEmpty ? '?' : name[0].toUpperCase(), size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(name, style: Lx.text(context, size: 13.5))),
                            const SizedBox(width: 6),
                            ClientTypeBadge(clientType: c['client_type'] as String?, compact: true),
                          ]),
                          Text(c['contact_person'] ?? '', style: Lx.text(context, size: 12.5, color: Lx.muted)),
                        ]),
                      ),
                      LuxeStatusDot(status: active ? LxStatus.ok : LxStatus.off),
                      const SizedBox(width: 7),
                      Text(active ? l10n.amStatusActive : l10n.amStatusInactive, style: Lx.text(context, size: 12, color: Lx.ink2)),
                    ]),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}

class AllMeetingsSheet extends StatelessWidget {
  final List<dynamic> meetings;
  final VoidCallback? onCreate;
  const AllMeetingsSheet({super.key, required this.meetings, this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.88,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sheetHead(
            context,
            l10n.amStatMeetings,
            trailing: onCreate == null
                ? null
                : LuxeButton(
                    label: l10n.createMeeting,
                    lxIcon: 'plus',
                    size: LuxeButtonSize.sm,
                    kind: LuxeButtonKind.primary,
                    onPressed: () {
                      Navigator.pop(context);
                      onCreate?.call();
                    },
                  ),
          ),
          Expanded(
            child: meetings.isEmpty
                ? Center(child: Text(l10n.amNoMeetings, style: Lx.text(context, size: 13.5, color: Lx.faint)))
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 28),
                    itemCount: meetings.length,
                    itemBuilder: (_, i) {
                      final m = meetings[i];
                      final client = m['workspace']?['client'] as Map<String, dynamic>?;
                      final status = m['status'] as String? ?? '';
                      final statusLabel = status == 'scheduled' ? l10n.scheduled : status == 'completed' ? l10n.completed : status == 'cancelled' ? l10n.cancelled : status;
                      final dt = DateTime.tryParse(m['scheduled_at']?.toString() ?? '')?.toLocal();
                      final wsId = m['workspace_id'] ?? m['workspace']?['id'];
                      final sub = [
                        '${client?['company_name'] ?? ''}',
                        if (dt != null) DateFormat('EEE d MMM · h:mm a', locale).format(dt),
                      ].where((e) => e.isNotEmpty).join(' · ');
                      // Mockup meeting card: `.meet` (`.cal` month + day) and
                      // title / sub, then the status (`.st2`).
                      return LuxeCard(
                        onTap: () {
                          Navigator.pop(context);
                          if (wsId != null) context.push('/am/workspace/$wsId?tab=5');
                        },
                        child: Row(children: [
                          Container(
                            width: 46,
                            padding: const EdgeInsetsDirectional.only(end: 12),
                            decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: Lx.line))),
                            child: Column(children: [
                              Text(dt == null ? '—' : DateFormat.MMM(locale).format(dt).toUpperCase(),
                                  style: Lx.text(context, size: 9.5, color: Lx.crimsonInk).copyWith(letterSpacing: 1.9)),
                              Text(dt == null ? '' : '${dt.day}', style: Lx.display(context, size: 26).copyWith(height: 1.1)),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m['title'] ?? '', style: Lx.text(context, size: 16)),
                              if (sub.isNotEmpty) Text(sub, style: Lx.text(context, size: 12.5, color: Lx.muted)),
                              const SizedBox(height: 6),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                LuxeStatusDot(status: status == 'completed' ? LxStatus.ok : status == 'cancelled' ? LxStatus.off : LxStatus.wait),
                                const SizedBox(width: 7),
                                Text(statusLabel, style: Lx.text(context, size: 12, color: Lx.ink2)),
                              ]),
                            ]),
                          ),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class CreateMeetingSheet extends StatefulWidget {
  final List<dynamic> clients;
  final VoidCallback onCreated;
  // Optional so this sheet can be pumped in a widget test with a mocked
  // MeetingProvider instead of hitting the network. Defaults to a fresh
  // MeetingProvider() (same as every other unseamed default in this file) —
  // zero behavior change for the real call site, which now passes the
  // parent's already-seamed _meetingProvider.
  final MeetingProvider? meetingProvider;
  const CreateMeetingSheet({super.key, required this.clients, required this.onCreated, this.meetingProvider});

  @override
  State<CreateMeetingSheet> createState() => _CreateMeetingSheetState();
}

class _CreateMeetingSheetState extends State<CreateMeetingSheet> {
  late final MeetingProvider _meetingProvider = widget.meetingProvider ?? MeetingProvider();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int? _duration;
  dynamic _selectedClient;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ws = _selectedClient?['workspace'] as Map<String, dynamic>?;
    if (_titleController.text.trim().isEmpty || ws == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.amMeetingValidation)));
      return;
    }
    setState(() => _saving = true);
    final dt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    final tzOffset = dt.timeZoneOffset;
    final tzSign = tzOffset.isNegative ? '-' : '+';
    final tzHours = tzOffset.inHours.abs().toString().padLeft(2, '0');
    final tzMinutes = (tzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final scheduledAtIso = '${dt.toIso8601String()}$tzSign$tzHours:$tzMinutes';
    try {
      await _meetingProvider.createMeeting(ws['id'] as int, {
        'title': _titleController.text.trim(),
        'scheduled_at': scheduledAtIso,
        'duration_minutes': _duration ?? 30,
        'notes': _notesController.text.trim(),
      });
      widget.onCreated();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.amMeetingCreateFailed)));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: LuxeFormTheme(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sheetHead(context, l10n.createMeeting),
        DropdownButtonFormField(
          decoration: InputDecoration(labelText: l10n.amClientRequired),
          items: widget.clients.map((c) => DropdownMenuItem(
            value: c,
            child: Text(c['company_name'] ?? ''),
          )).toList(),
          onChanged: (v) => setState(() => _selectedClient = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(labelText: l10n.amMeetingTitle, hintText: l10n.amMeetingTitleHint),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _selectedDate = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: l10n.amDate),
                child: Text('${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _selectedTime);
                if (t != null) setState(() => _selectedTime = t);
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: l10n.amTime),
                child: Text('${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(labelText: l10n.amDurationMinutes),
          initialValue: _duration,
          items: [15, 30, 45, 60, 90, 120].map((d) => DropdownMenuItem(value: d, child: Text('$d ${l10n.amMinutes}'))).toList(),
          onChanged: (v) => setState(() => _duration = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(labelText: l10n.amNotes),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: LuxeButton(
            label: l10n.createMeeting,
            kind: LuxeButtonKind.primary,
            size: LuxeButtonSize.lg,
            onPressed: _saving ? null : _save,
          ),
        ),
        ],
      )),
      ),
    );
  }
}
