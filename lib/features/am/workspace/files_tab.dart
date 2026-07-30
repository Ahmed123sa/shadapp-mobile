import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.get('/workspaces/$wsId/files');
      _files = data['files'] as List<dynamic>? ?? [];
      _definitions = data['definitions'] as List<dynamic>? ?? [];
    } catch (_) {
      _error = 'فشل تحميل الملفات';
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم رفع الملف')));
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الملف')));
    }
  }

  Future<void> _addDefinition() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final isRequired = ValueNotifier<bool>(false);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDlgState) => AlertDialog(
          title: const Text('إضافة تعريف مستند'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المستند *', hintText: 'مثال: عقد التأسيس')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'الوصف', hintText: 'وصف المستند...'), maxLines: 2),
            const SizedBox(height: 12),
            Row(children: [
              Checkbox(value: isRequired.value, onChanged: (v) => setDlgState(() => isRequired.value = v ?? false)),
              const Text('مطلوب'),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (result != true || nameCtrl.text.trim().isEmpty || widget.workspaceId == null) return;
    try {
      await _api.post('/workspaces/${widget.workspaceId}/document-definitions', {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'is_required': isRequired.value,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إضافة التعريف')));
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إضافة التعريف')));
    }
  }

  Future<void> _deleteDefinition(int defId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف تعريف المستند'),
        content: const Text('هل أنت متأكد من حذف هذا التعريف؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/workspaces/${widget.workspaceId}/document-definitions/$defId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حذف التعريف')));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حذف التعريف')));
    }
  }

  Future<void> _reviewFile(int fileId, String action) async {
    String? reason;
    if (action == 'rejected') {
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final c = TextEditingController();
          return AlertDialog(
            title: const Text('سبب الرفض'),
            content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'اذكر سبب الرفض...')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('تأكيد الرفض')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تنفيذ الإجراء')));
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
                  label: const Text('إضافة تعريف مستند'),
                ),
              ),
            if (_definitions.isNotEmpty) ...[
              Text('تعريفات المستندات المطلوبة', style: ShadTypography.sectionHeader),
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
                        child: Text('مطلوب', style: ShadTypography.caption.copyWith(color: ShadColors.error)),
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
              _filterChip('الكل', 'all'),
              const SizedBox(width: 6),
              _filterChip('قيد المراجعة', 'pending'),
              const SizedBox(width: 6),
              _filterChip('مقبول', 'approved'),
              const SizedBox(width: 6),
              _filterChip('مرفوض', 'rejected'),
            ]),
            const SizedBox(height: 12),
            Text('الملفات المرفوعة', style: ShadTypography.sectionHeader),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const EmptyState(icon: Icons.folder_outlined, title: 'لا توجد ملفات')
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                      }
                    } : null,
                    leading: const Icon(Icons.attach_file, color: ShadColors.primary),
                    title: Text(f['name'] ?? '', style: ShadTypography.cardTitle, overflow: TextOverflow.ellipsis),
                    subtitle: Row(children: [
                      if (fileType.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
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
                            statusLabels[f['status']] ?? f['status'],
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
