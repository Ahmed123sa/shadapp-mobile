import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';

class ClientFilesPage extends StatefulWidget {
  const ClientFilesPage({super.key});

  @override
  State<ClientFilesPage> createState() => _ClientFilesPageState();
}

class _ClientFilesPageState extends State<ClientFilesPage> {
  final _api = ApiClient();
  List<dynamic> _files = [];
  List<dynamic> _definitions = [];
  List<dynamic> _paymentFiles = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    setState(() => _loading = true);
    try {
      final data = await _api.get('/workspaces/$wsId/files');
      _files = safeList(data['files']);
      _definitions = safeList(data['definitions']);
      _paymentFiles = safeList(data['paymentFiles']);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upload() async {
    if (_definitions.isEmpty) {
      await _pickAndUpload(null);
      return;
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        int? selectedDef;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('اختر تعريف المستند', style: ShadTypography.cardTitle),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              ..._definitions.map((d) {
                final isSelected = selectedDef == d['id'];
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? ShadColors.crimson : ShadColors.textDisabled,
                  ),
                  title: Text('${d['name']}${d['is_required'] == true ? ' *' : ''}',
                      style: ShadTypography.cardBody),
                  onTap: () => setSheetState(() => selectedDef = d['id'] as int),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickAndUpload(selectedDef);
                  },
                  child: const Text('اختيار ورفع'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(int? definitionId) async {
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
      await _api.multipartPost('/workspaces/$wsId/files', fields, file: file);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع الملف: $e')));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _deleteFile(dynamic file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملف'),
        content: Text('هل تريد حذف "${file['name'] ?? ''}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    try {
      await _api.delete('/workspaces/$wsId/files/${file['id']}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الملف')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل حذف الملف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_definitions.isNotEmpty) ...[
          Text('تعريفات المستندات', style: ShadTypography.sectionHeader),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _definitions.map<Widget>((d) =>
            Chip(
              label: Text('${d['name']}${d['is_required'] == true ? ' *' : ''}',
                  style: ShadTypography.caption.copyWith(color: ShadColors.textPrimary)),
              backgroundColor: ShadColors.card,
              side: BorderSide(color: d['is_required'] == true ? ShadColors.gold : ShadColors.cardBorder),
            ),
          ).toList()),
          const SizedBox(height: 16),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('الملفات المرفوعة', style: ShadTypography.sectionHeader),
          TextButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: _uploading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file, size: 18),
            label: Text(_uploading ? 'جاري الرفع...' : 'رفع ملف'),
          ),
        ]),
        const SizedBox(height: 8),
        if (_files.isEmpty && _paymentFiles.isEmpty)
          const EmptyState(icon: Icons.folder_outlined, title: 'لا توجد ملفات')
        else
          ..._files.map((f) {
            final status = f['status'] as String? ?? 'pending';
            final tag = f['tag'] as String? ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: ShadColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: GestureDetector(
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
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: ShadColors.gold.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.attach_file, size: 20, color: ShadColors.gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(f['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textPrimary), overflow: TextOverflow.ellipsis),
                      ),
                      if (tag.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ShadColors.crimson.withAlpha(40),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ShadColors.crimson.withAlpha(70)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.label, size: 11, color: ShadColors.crimson),
                            const SizedBox(width: 4),
                            Text(tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ShadColors.crimson)),
                          ]),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      StatusBadge(status: status, fontSize: 10),
                      const SizedBox(width: 8),
                      if (f['definition_name'] != null)
                        Text(f['definition_name'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ShadColors.primary)),
                      if (f['definition_name'] != null && f['size'] != null)
                        const Text('  •  ', style: TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
                      if (f['size'] != null)
                        Text('${(f['size'] / 1024).toStringAsFixed(0)} KB',
                            style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'PlayfairDisplay')),
                    ]),
                    if (f['rejection_reason'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('سبب الرفض: ${f['rejection_reason']}', style: const TextStyle(fontSize: 11, color: ShadColors.error)),
                      ),
                  ])),
                  if (status != 'approved')
                    GestureDetector(
                      onTap: () => _deleteFile(f),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.close, size: 18, color: ShadColors.error),
                      ),
                    ),
                ]),
              ),
            );
          }),
        if (_paymentFiles.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('إثباتات الدفع', style: ShadTypography.sectionHeader),
          const SizedBox(height: 10),
          ..._paymentFiles.map((pf) {
            final status = pf['status'] as String? ?? 'pending';
            final date = pf['created_at'] as String?;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: ShadColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: GestureDetector(
                onTap: pf['file_url'] != null ? () async {
                  final url = _api.resolveFileUrl(pf['file_url'] as String);
                  final uri = Uri.tryParse(url);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                  }
                } : null,
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: ShadColors.success.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long, size: 20, color: ShadColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(pf['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textPrimary), overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ShadColors.success.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ShadColors.success.withAlpha(70)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.receipt_long, size: 11, color: ShadColors.success),
                          SizedBox(width: 4),
                          Text('إثبات الدفع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ShadColors.success)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      StatusBadge(status: status, fontSize: 10),
                      if (date != null) ...[
                        const SizedBox(width: 8),
                        Text(date.split('T')[0], style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '${pf['amount'] ?? ''} ${pf['currency'] ?? 'SAR'}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.gold, fontFamily: 'PlayfairDisplay'),
                    ),
                  ])),
                ]),
              ),
            );
          }),
        ],
      ],
    );
  }
}
