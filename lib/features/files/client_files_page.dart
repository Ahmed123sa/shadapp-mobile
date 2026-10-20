import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/theme.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../providers/file_provider.dart';

class ClientFilesPage extends StatefulWidget {
  // Optional so this screen can be pumped in a widget test with a mocked
  // FileProvider instead of hitting the network.
  final FileProvider? fileProvider;
  final ApiClient? api;
  final ValueNotifier<int>? refreshNotifier;
  const ClientFilesPage({super.key, this.fileProvider, this.api, this.refreshNotifier});

  @override
  State<ClientFilesPage> createState() => _ClientFilesPageState();
}

class _ClientFilesPageState extends State<ClientFilesPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final FileProvider _fileProvider = widget.fileProvider ?? FileProvider();
  List<dynamic> _files = [];
  List<dynamic> _definitions = [];
  List<dynamic> _paymentFiles = [];
  bool _loading = true;
  bool _uploading = false;
  VoidCallback? _refreshListener;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.refreshNotifier != null) {
      _refreshListener = () {
        if (mounted) _load();
      };
      widget.refreshNotifier!.addListener(_refreshListener!);
    }
  }

  @override
  void dispose() {
    if (_refreshListener != null) {
      widget.refreshNotifier?.removeListener(_refreshListener!);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    setState(() => _loading = true);
    try {
      final data = await _fileProvider.fetchWorkspaceFiles(wsId);
      _files = safeList(data['files']);
      _definitions = safeList(data['definitions']);
      _paymentFiles = safeList(data['paymentFiles']);
    } catch (e, s) {
      AppLog.error('client_files_page._load', e, s);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upload() async {
    final l10n = AppLocalizations.of(context)!;
    if (_definitions.isEmpty) {
      await _pickAndUpload(null);
      return;
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: Lx.sheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet))),
      builder: (ctx) {
        int? selectedDef;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(l10n.files_chooseDocType, style: Lx.display(context, size: 18)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              ..._definitions.map((d) {
                final isSelected = selectedDef == d['id'];
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Lx.crimsonInk : Lx.faint,
                  ),
                  title: Text('${d['name']}${d['is_required'] == true ? ' *' : ''}',
                      style: Lx.text(context, size: 14)),
                  onTap: () => setSheetState(() => selectedDef = d['id'] as int),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: LuxeButton(
                  label: l10n.files_chooseAndUpload,
                  kind: LuxeButtonKind.primary,
                  size: LuxeButtonSize.lg,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickAndUpload(selectedDef);
                  },
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(int? definitionId) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    final wsId = _api.workspaceId;
    if (wsId == null) return;

    setState(() => _uploading = true);
    try {
      final fields = <String, dynamic>{};
      if (definitionId != null) fields['document_definition_id'] = definitionId;
      await _fileProvider.uploadFile(wsId, fields, file: file);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.files_uploadFailed}: $e')));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _deleteFile(dynamic file) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.files_deleteTitle),
        content: Text(l10n.deleteFileConfirmation(file['name'] ?? '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Lx.crimson, foregroundColor: Colors.white),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    try {
      await _fileProvider.deleteFile(wsId, file['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.files_deleted)));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fileDeleteFailed(e))));
    }
  }

  Future<void> _open(BuildContext context, String? fileUrl) async {
    if (fileUrl == null) return;
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.tryParse(_api.resolveFileUrl(fileUrl));
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fileOpenFailed)));
    }
  }

  /// Mockup `.fic`: a 34×42 outlined page with the extension underneath.
  Widget _fic(String name) {
    final dot = name.lastIndexOf('.');
    final ext = (dot >= 0 && dot < name.length - 1 ? name.substring(dot + 1) : 'FILE').toUpperCase();
    return Container(
      width: 34,
      height: 42,
      padding: const EdgeInsets.only(bottom: 5),
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Lx.line2)),
      child: Text(ext.length > 4 ? ext.substring(0, 4) : ext, style: Lx.text(context, size: 8.5, color: Lx.muted).copyWith(letterSpacing: 0.9)),
    );
  }

  String _sizeLabel(dynamic size) {
    final n = num.tryParse('$size');
    if (n == null) return '';
    if (n >= 1024 * 1024) return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(n / 1024).toStringAsFixed(0)} KB';
  }

  Widget _fileCard({
    required Key key,
    required String name,
    required String meta,
    required String? fileUrl,
    Widget? status,
    String? note,
    VoidCallback? onDelete,
  }) {
    return LuxeCard(
      key: key,
      child: Row(children: [
        _fic(name),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: fileUrl != null ? () => _open(context, fileUrl) : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: Lx.text(context, size: 13.5), overflow: TextOverflow.ellipsis),
              if (meta.isNotEmpty) Text(meta, style: Lx.text(context, size: 11, color: Lx.faint), overflow: TextOverflow.ellipsis),
              if (status != null) Padding(padding: const EdgeInsets.only(top: 6), child: status),
              if (note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note, style: Lx.text(context, size: 11, color: Lx.danger))),
            ]),
          ),
        ),
        if (onDelete != null)
          GestureDetector(
            onTap: onDelete,
            child: const Padding(padding: EdgeInsetsDirectional.only(start: 4, end: 4), child: Icon(Icons.close, size: 17, color: Lx.faint)),
          ),
        if (fileUrl != null)
          InkWell(
            key: ValueKey('${(key as ValueKey).value}-download'),
            customBorder: const CircleBorder(),
            onTap: () => _open(context, fileUrl),
            child: const SizedBox(width: 38, height: 38, child: Center(child: LxIcon('down', size: 19, color: Lx.muted))),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: _load,
      color: Lx.crimsonInk,
      backgroundColor: Lx.surface,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        children: [
          LuxePageTitle(l10n.dashboard_tab_files),
          // subuser-review-plan.md م٦ — uploading a file maps to
          // can_upload_files, per the plan's action table.
          if (_api.canDo('can_upload_files'))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: LuxeButton(
                  key: const ValueKey('files-upload'),
                  label: _uploading ? l10n.files_uploading : l10n.files_uploadFile,
                  lxIcon: 'up',
                  kind: LuxeButtonKind.primary,
                  size: LuxeButtonSize.lg,
                  onPressed: _uploading ? () {} : _upload,
                ),
              ),
            ),
          if (_definitions.isNotEmpty) ...[
            LuxeKind(l10n.files_docDefinitions),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _definitions.map<Widget>((d) {
              final req = d['is_required'] == true;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Lx.rPill),
                  border: Border.all(color: req ? const Color(0x80941414) : Lx.line2),
                ),
                child: Text('${d['name']}${req ? ' *' : ''}', style: Lx.text(context, size: 11.5, color: Lx.ink2)),
              );
            }).toList()),
            const SizedBox(height: 14),
          ],
          if (_files.isEmpty && _paymentFiles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(l10n.files_noFiles, style: Lx.text(context, size: 14, color: Lx.muted))),
            )
          else
            ..._files.map((f) {
              final status = f['status'] as String? ?? 'pending';
              final tag = f['tag'] as String? ?? '';
              final date = (f['created_at'] as String?)?.split('T').first;
              final meta = [
                if (f['definition_name'] != null) f['definition_name'].toString(),
                if (tag.isNotEmpty) tag,
                if (date != null) date,
                if (f['size'] != null) _sizeLabel(f['size']),
              ].join(' · ');
              final dotStatus = status == 'approved' ? LxStatus.ok : status == 'rejected' ? LxStatus.bad : LxStatus.wait;
              return _fileCard(
                key: ValueKey('file-card-${f['id']}'),
                name: f['name'] ?? '',
                meta: meta,
                fileUrl: f['file_url'] as String?,
                status: Row(mainAxisSize: MainAxisSize.min, children: [
                  LuxeStatusDot(status: dotStatus),
                  const SizedBox(width: 7),
                  Text(statusLabels(l10n)[status] ?? status, style: Lx.text(context, size: 11.5, color: Lx.ink2)),
                ]),
                note: f['rejection_reason'] != null ? l10n.rejectionReason(f['rejection_reason']) : null,
                onDelete: status != 'approved' ? () => _deleteFile(f) : null,
              );
            }),
          if (_paymentFiles.isNotEmpty) ...[
            const SizedBox(height: 14),
            LuxeKind(l10n.files_paymentProofs),
            const SizedBox(height: 8),
            ..._paymentFiles.map((pf) {
              final status = pf['status'] as String? ?? 'pending';
              final date = (pf['created_at'] as String?)?.split('T').first;
              final amount = num.tryParse('${pf['amount'] ?? ''}');
              final meta = [
                l10n.files_paymentProof,
                if (date != null) date,
                if (amount != null) '${lxFormatMoney(amount)} ${pf['currency'] ?? 'SAR'}',
              ].join(' · ');
              final dotStatus = status == 'approved' ? LxStatus.ok : status == 'rejected' ? LxStatus.bad : LxStatus.wait;
              return _fileCard(
                key: ValueKey('payment-file-card-${pf['id']}'),
                name: pf['name'] ?? '',
                meta: meta,
                fileUrl: pf['file_url'] as String?,
                status: Row(mainAxisSize: MainAxisSize.min, children: [
                  LuxeStatusDot(status: dotStatus),
                  const SizedBox(width: 7),
                  Text(statusLabels(l10n)[status] ?? status, style: Lx.text(context, size: 11.5, color: Lx.ink2)),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }
}
