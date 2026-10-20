import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../providers/file_provider.dart';

class FilesTab extends StatefulWidget {
  final int? workspaceId;
  // Optional so this screen can be pumped in a widget test with a mocked
  // FileProvider instead of hitting the network.
  final FileProvider? fileProvider;
  final ApiClient? api;
  const FilesTab({super.key, this.workspaceId, this.fileProvider, this.api});

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final FileProvider _fileProvider = widget.fileProvider ?? FileProvider();
  List<dynamic> _definitions = [];
  List<dynamic> _files = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  bool _managersCanReviewFiles = false;

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
      final data = await _fileProvider.fetchWorkspaceFiles(wsId);
      _files = data['files'] as List<dynamic>? ?? [];
      _definitions = data['definitions'] as List<dynamic>? ?? [];
    } catch (_) {
      if (mounted) _error = AppLocalizations.of(context)?.filesLoadFailed;
    }
    if (_api.role != 'super_admin') {
      try {
        final res = await _api.get('/settings');
        final settings = res['settings'] as Map<String, dynamic>?;
        final val = settings?['managers_can_review_files']?['value'];
        _managersCanReviewFiles = val == true || val == 1 || val == '1' || val.toString().toLowerCase() == 'true';
      } catch (_) {}
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
      await _fileProvider.uploadFile(widget.workspaceId!, {}, file: file);
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
      await _fileProvider.createDefinition(widget.workspaceId!, {
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
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Lx.crimson, foregroundColor: Colors.white), child: Text(l10n.delete)),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      await _fileProvider.deleteDefinition(widget.workspaceId!, defId);
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
      await _fileProvider.reviewFile(fileId, action: action, reason: reason);
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
    final canReview = isSA || (_managersCanReviewFiles && _api.canDo('can_review_files'));
    // A manager allowed to approve contracts may also review the documents
    // attached to those contracts, whatever the global setting says
    // (mirrors FileController::review on the backend).
    bool canReviewFile(Map f) =>
        canReview ||
        (!isSA && _api.canCompanyApprove && (f['contract_id'] != null || f['contract_required_document_id'] != null));
    final filtered = _filteredFiles;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LuxeFormTheme(
        child: RefreshIndicator(
          onRefresh: _load,
          color: Lx.crimsonInk,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              // Mockup: primary full-width upload button (not for super admin).
              if (!isSA)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: LuxeButton(
                      key: const ValueKey('files-upload'),
                      label: l10n.files_uploadFile,
                      lxIcon: 'up',
                      kind: LuxeButtonKind.primary,
                      size: LuxeButtonSize.lg,
                      onPressed: _uploadFile,
                    ),
                  ),
                ),
              if (!isSA)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  // Not in the mockup (required-document definitions are a
                  // real feature); styled as the mockup's outline `.btn.lg`.
                  child: SizedBox(
                    width: double.infinity,
                    child: LuxeButton(
                      label: l10n.filesAddDefinitionTitle,
                      lxIcon: 'plus',
                      size: LuxeButtonSize.lg,
                      onPressed: _addDefinition,
                    ),
                  ),
                ),
              if (_definitions.isNotEmpty) ...[
                LuxeKind(l10n.filesRequiredDefinitions),
                const SizedBox(height: 8),
                ..._definitions.map((d) => LuxeCard(
                      child: Row(children: [
                        const LxIcon('doc', size: 20, color: Lx.ink2),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d['name'] ?? '', style: Lx.text(context, size: 14)),
                            if (d['description'] != null) Text(d['description'], style: Lx.text(context, size: 12, color: Lx.muted)),
                          ]),
                        ),
                        if (d['is_required'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: const Color(0x80941414))),
                            child: Text(l10n.filesRequired, style: Lx.text(context, size: 10.5, color: Lx.crimsonInk)),
                          ),
                        if (!isSA) ...[
                          const SizedBox(width: 6),
                          InkResponse(
                            key: ValueKey('file-def-delete-${d['id']}'),
                            onTap: () => _deleteDefinition(d['id']),
                            radius: 18,
                            child: const SizedBox(width: 32, height: 32, child: Center(child: LxIcon('trash', size: 17, color: Lx.danger))),
                          ),
                        ],
                      ]),
                    )),
                const SizedBox(height: 14),
              ],
              // Filter chips (mockup `.chip`)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _filterChip(l10n.all, 'all'),
                  const SizedBox(width: 8),
                  _filterChip(l10n.pending, 'pending'),
                  const SizedBox(width: 8),
                  _filterChip(l10n.approved, 'approved'),
                  const SizedBox(width: 8),
                  _filterChip(l10n.rejected, 'rejected'),
                ]),
              ),
              const SizedBox(height: 14),
              LuxeKind(l10n.filesUploaded),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text(l10n.filesEmpty, style: Lx.text(context, size: 14, color: Lx.muted))),
                )
              else
                ...filtered.map((f) {
                  final status = f['status'] as String? ?? '';
                  final dot = status == 'approved' ? LxStatus.ok : status == 'rejected' ? LxStatus.bad : LxStatus.wait;
                  final fileSize = _formatFileSize(f['file_size']);
                  final fileType = (f['file_type'] as String? ?? '').toUpperCase();
                  final name = f['name'] ?? '';
                  // Mockup `.fs`: "uploader · date · size".
                  final uploader = f['uploaded_by'] is Map ? (f['uploaded_by'] as Map)['name']?.toString() : null;
                  final created = DateTime.tryParse(f['created_at']?.toString() ?? '')?.toLocal();
                  final dateText = created == null ? null : DateFormat('d MMM', Localizations.localeOf(context).toString()).format(created);
                  final meta = [uploader, dateText, fileSize].where((e) => e != null && e.isNotEmpty).join(' · ');
                  Future<void> open() async {
                    if (f['file_url'] == null) return;
                    final uri = Uri.tryParse(_api.resolveFileUrl(f['file_url'] as String));
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.filesFileOpenFailed)));
                    }
                  }

                  return LuxeCard(
                    key: ValueKey('file-card-${f['id']}'),
                    onTap: f['file_url'] != null ? open : null,
                    child: Row(children: [
                      // Mockup `.fic`
                      Container(
                        width: 34,
                        height: 42,
                        padding: const EdgeInsets.only(bottom: 5),
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Lx.line2)),
                        child: Text(fileType.isEmpty ? 'FILE' : (fileType.length > 4 ? fileType.substring(0, 4) : fileType), style: Lx.text(context, size: 8.5, color: Lx.muted).copyWith(letterSpacing: 0.9)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$name', style: Lx.text(context, size: 13.5), overflow: TextOverflow.ellipsis),
                          if (meta.isNotEmpty) Text(meta, style: Lx.text(context, size: 11, color: Lx.faint)),
                          if (status.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                LuxeStatusDot(status: dot),
                                const SizedBox(width: 7),
                                Text(statusLabels(AppLocalizations.of(context)!)[status] ?? status, style: Lx.text(context, size: 11.5, color: Lx.ink2)),
                              ]),
                            ),
                        ]),
                      ),
                      if (f['status'] == 'pending' && canReviewFile(f)) ...[
                        InkResponse(
                          key: ValueKey('file-approve-${f['id']}'),
                          onTap: () => _reviewFile(f['id'], 'approved'),
                          radius: 20,
                          child: const SizedBox(width: 38, height: 38, child: Center(child: Icon(Icons.check, size: 18, color: Lx.ok))),
                        ),
                        InkResponse(
                          key: ValueKey('file-reject-${f['id']}'),
                          onTap: () => _reviewFile(f['id'], 'rejected'),
                          radius: 20,
                          child: const SizedBox(width: 38, height: 38, child: Center(child: Icon(Icons.close, size: 18, color: Lx.danger))),
                        ),
                      ] else if (f['file_url'] != null)
                        InkResponse(
                          onTap: open,
                          radius: 20,
                          child: const SizedBox(width: 38, height: 38, child: Center(child: LxIcon('down', size: 18, color: Lx.muted))),
                        ),
                    ]),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F0F0) : null,
          borderRadius: BorderRadius.circular(Lx.rPill),
          border: Border.all(color: selected ? const Color(0xFFF0F0F0) : Lx.line2),
        ),
        child: Text(label, style: Lx.text(context, size: 12, color: selected ? const Color(0xFF111111) : Lx.muted)),
      ),
    );
  }
}
