import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';

class FilesTab extends StatefulWidget {
  final int? workspaceId;
  const FilesTab({super.key, this.workspaceId});

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  final _api = ApiClient();
  List<dynamic> _definitions = [];
  List<dynamic> _files = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    setState(() { if (_files.isEmpty) _loading = true; _error = null; });
    try {
      final data = await _api.get('/workspaces/$wsId/files');
      _files = data['files'] as List<dynamic>? ?? [];
      _definitions = data['definitions'] as List<dynamic>? ?? [];
    } catch (_) {
      _error = AppLocalizations.of(context)?.filesLoadFailed;
    }
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> get _filteredFiles {
    if (_filter == 'all') return _files;
    return _files.where((f) => f['status'] == _filter).toList();
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
    );
    if (result == null || result.files.isEmpty || widget.workspaceId == null) return;
    final file = File(result.files.single.path!);
    try {
      await _api.multipartPost('/workspaces/${widget.workspaceId}/files', {}, file: file);
      if (mounted)           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.filesUploadSuccess)])));
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.filesUploadFailed)));
    }
  }

  Future<void> _addDefinition() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final isRequired = ValueNotifier<bool>(false);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (_, setDlgState) => AlertDialog(
            title: Text(l10n.filesAddDefinitionTitle),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: l10n.filesNameLabel, hintText: l10n.filesNameHint)),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: InputDecoration(labelText: l10n.filesDescription, hintText: l10n.filesDescriptionHint), maxLines: 2),
              const SizedBox(height: 12),
              Row(children: [
                Checkbox(value: isRequired.value, onChanged: (v) => setDlgState(() => isRequired.value = v ?? false)),
                Text(l10n.filesRequired),
              ]),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.filesAdd)),
            ],
          ),
        );
      },
    );
    if (result != true || nameCtrl.text.trim().isEmpty || widget.workspaceId == null) return;
    try {
      await _api.post('/workspaces/${widget.workspaceId}/document-definitions', {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'is_required': isRequired.value,
      });
      if (mounted)           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.filesDefinitionAdded)])));
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.filesDefinitionAddFailed)));
    }
  }

  Future<void> _deleteDefinition(int defId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.filesDeleteDefinitionTitle),
          content: Text(l10n.filesDeleteDefinitionConfirm),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error), child: Text(l10n.delete)),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      await _api.delete('/workspaces/${widget.workspaceId}/document-definitions/$defId');
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.filesDefinitionDeleted)])));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.filesDefinitionDeleteFailed)));
    }
  }

  Future<void> _reviewFile(int fileId, String action) async {
    String? reason;
    if (action == 'rejected') {
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final c = TextEditingController();
          final l10n = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text(l10n.filesRejectionReasonTitle),
            content: TextField(controller: c, maxLines: 3, decoration: InputDecoration(hintText: l10n.filesRejectionReasonHint)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(l10n.filesConfirmRejection)),
            ],
          );
        },
      );
      if (reason == null) return;
    }
    try {
      await _api.post('/files/$fileId/review', {
        'action': action,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.filesActionFailed)));
    }
  }

  String _formatFileSize(dynamic bytes) {
    if (bytes == null) return '';
    final b = (double.tryParse(bytes?.toString() ?? '') ?? 0);
    if (b < 1024) return '${b.toStringAsFixed(0)} B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final isSA = _api.role == 'super_admin';
    final filtered = _filteredFiles;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Add definition button
            if (!isSA)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OutlinedButton.icon(
                  onPressed: _addDefinition,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.filesAddDefinitionTitle),
                ),
              ),
            if (_definitions.isNotEmpty) ...[
              Text(l10n.filesRequiredDefinitions, style: ShadTypography.sectionHeader),
              const SizedBox(height: 8),
              ..._definitions.map((d) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.description, color: ShadColors.primary),
                  title: Text(d['name'] ?? '', style: ShadTypography.cardTitle),
                  subtitle: d['description'] != null ? Text(d['description'], style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary)) : null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (d['is_required'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: ShadColors.errorLight, borderRadius: BorderRadius.circular(12)),
                        child: Text(l10n.filesRequired, style: ShadTypography.caption.copyWith(color: ShadColors.error)),
                      ),
                    if (!isSA) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: ShadColors.error),
                        onPressed: () => _deleteDefinition(d['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ]),
                ),
              )),
              const SizedBox(height: 16),
            ],
            // Filter chips
            Row(children: [
              _filterChip(l10n.all, 'all'),
              const SizedBox(width: 6),
              _filterChip(l10n.pending, 'pending'),
              const SizedBox(width: 6),
              _filterChip(l10n.approved, 'approved'),
              const SizedBox(width: 6),
              _filterChip(l10n.rejected, 'rejected'),
            ]),
            const SizedBox(height: 12),
            Text(l10n.filesUploaded, style: ShadTypography.sectionHeader),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              EmptyState(icon: Icons.folder_outlined, title: l10n.filesEmpty)
            else
              ...filtered.map((f) {
                final statusColors = {'pending': ShadColors.warning, 'approved': ShadColors.success, 'rejected': ShadColors.error};
                final sc = statusColors[f['status']] ?? ShadColors.textDisabled;
                final fileSize = _formatFileSize(f['file_size']);
                final fileType = (f['file_type'] as String? ?? '').toUpperCase();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: f['file_url'] != null ? () async {
                      final url = _api.resolveFileUrl(f['file_url'] as String);
                      final uri = Uri.tryParse(url);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.filesFileOpenFailed)));
                      }
                    } : null,
                    leading: const Icon(Icons.attach_file, color: ShadColors.primary),
                    title: Text(f['name'] ?? '', style: ShadTypography.cardTitle, overflow: TextOverflow.ellipsis),
                    subtitle: Row(children: [
                      if (fileType.isNotEmpty)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Text(fileType, style: ShadTypography.caption.copyWith(color: ShadColors.textDisabled, fontSize: 10)),
                        ),
                      if (fileSize.isNotEmpty)
                        Text(fileSize, style: ShadTypography.caption.copyWith(color: ShadColors.textDisabled, fontSize: 10)),
                      if (f['status'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: sc.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            statusLabels(AppLocalizations.of(context)!)[f['status']] ?? f['status'],
                            style: ShadTypography.caption.copyWith(color: sc, fontSize: 10),
                          ),
                        ),
                      ],
                    ]),
                    trailing: f['status'] == 'pending' && isSA
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: ShadColors.success),
                            onPressed: () => _reviewFile(f['id'], 'approved'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: ShadColors.error),
                            onPressed: () => _reviewFile(f['id'], 'rejected'),
                          ),
                        ])
                      : null,
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: isSA
        ? null
        : FloatingActionButton(
            onPressed: _uploadFile,
            child: const Icon(Icons.upload_file),
          ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? ShadColors.primary : ShadColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? ShadColors.primary : ShadColors.cardBorder),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: selected ? Colors.white : ShadColors.textSecondary)),
      ),
    );
  }
}
