// Extracted from am_dashboard_page.dart as part of بند ٨ (file splitting).
// Three self-contained bottom-sheet widgets that only ever talked to the
// parent page via constructor params/callbacks — made public (renamed from
// their original private names) since a public widget is required to live in
// its own file, same reasoning as contract_detail_sheet.dart's extraction.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../providers/meeting_provider.dart';

class ManagerClientsSheet extends StatelessWidget {
  final String managerName;
  final List<dynamic> clients;
  final void Function(Map<String, dynamic> client) onClientTap;
  const ManagerClientsSheet({super.key, required this.managerName, required this.clients, required this.onClientTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${l10n.amClients} $managerName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
        if (clients.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(l10n.amNoClientsAvailable, style: const TextStyle(color: ShadColors.textSecondary))),
          )
        else
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: clients.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = clients[i];
                final ws = c['workspace'] as Map<String, dynamic>?;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: ShadColors.cardBorder,
                    child: Text((c['company_name'] as String? ?? '')[0].toUpperCase(), style: const TextStyle(color: ShadColors.textSecondary)),
                  ),
                  title: Row(children: [
                    Flexible(child: Text(c['company_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                    const SizedBox(width: 6),
                    ClientTypeBadge(clientType: c['client_type'] as String?, compact: true),
                  ]),
                  subtitle: Text(c['contact_person'] ?? '', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ws?['status'] == 'active' ? ShadColors.success.withAlpha(25) : ShadColors.cardBorder,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(ws?['status'] == 'active' ? l10n.amStatusActive : l10n.amStatusInactive, style: TextStyle(fontSize: 10, color: ws?['status'] == 'active' ? ShadColors.success : ShadColors.textSecondary)),
                  ),
                  onTap: () => onClientTap(c),
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
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: ShadColors.cardBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text(l10n.amStatMeetings, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: ShadColors.crimson.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Text('${meetings.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, size: 20, color: ShadColors.textSecondary), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: meetings.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(l10n.amNoMeetings, style: const TextStyle(fontSize: 13, color: ShadColors.textDisabled, fontFamily: 'Archivo')),
                      if (onCreate != null) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () { Navigator.pop(context); onCreate?.call(); },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(l10n.createMeeting),
                        ),
                      ],
                    ]),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: meetings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m = meetings[i];
                      final client = m['workspace']?['client'] as Map<String, dynamic>?;
                      final status = m['status'] as String? ?? '';
                      final statusColor = status == 'completed' ? ShadColors.success : status == 'scheduled' ? ShadColors.sent : ShadColors.textSecondary;
                      final statusLabel = status == 'scheduled' ? l10n.scheduled : status == 'completed' ? l10n.completed : status == 'cancelled' ? l10n.cancelled : status;
                      String? dateStr;
                      try {
                        final dt = DateTime.parse(m['scheduled_at'] ?? '');
                        dateStr = '${dt.year}/${dt.month}/${dt.day}';
                      } catch (_) {
                        // A meeting with no/invalid date just renders without
                        // one. Not reported: this is normal for drafts, and
                        // it runs inside a list builder, so a bad record
                        // would report on every rebuild.
                      }
                      final wsId = m['workspace_id'] ?? m['workspace']?['id'];
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.pop(context);
                          if (wsId != null) context.push('/am/workspace/$wsId?tab=5');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ShadColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ShadColors.cardBorder),
                          ),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: ShadColors.gold.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.videocam, size: 18, color: ShadColors.gold),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
                                const SizedBox(height: 2),
                                Text('${client?['company_name'] ?? ''} • ${dateStr ?? ''}', style: const TextStyle(fontSize: 10, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor, fontFamily: 'Archivo')),
                            ),
                          ]),
                        ),
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
      padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l10n.createMeeting, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
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
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(l10n.createMeeting),
          ),
        ),
        ],
      ),
      ),
    );
  }
}
