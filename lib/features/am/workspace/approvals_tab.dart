import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/status_badge.dart';

class ApprovalsTab extends StatefulWidget {
  final int? workspaceId;
  const ApprovalsTab({super.key, this.workspaceId});

  @override
  State<ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends State<ApprovalsTab> {
  final _api = ApiClient();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  List<dynamic> _approvals = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<File> _selectedFiles = [];
  List<String> _selectedFileNames = [];

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
      final data = await _api.get('/workspaces/$wsId/approvals');
      _approvals = safeList(data['approvals']);
    } catch (_) {
      _error = 'فشل تحميل طلبات الموافقة';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
        _selectedFileNames = result.files.map((f) => f.name).toList();
      });
    }
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || widget.workspaceId == null) return;
    setState(() => _sending = true);
    try {
      final fields = <String, dynamic>{
        'title': title,
        'description': _descController.text.trim(),
      };
      if (_selectedFiles.isNotEmpty) {
        await _api.multipartPostMultiple('/workspaces/${widget.workspaceId}/approvals', fields, files: _selectedFiles, fileField: 'files[]');
      } else {
        await _api.post('/workspaces/${widget.workspaceId}/approvals', fields);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إرسال طلب الموافقة')));
        _titleController.clear();
        _descController.clear();
        setState(() { _selectedFiles = []; _selectedFileNames = []; });
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إرسال الطلب')));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _respond(int id, String action, String? reason) async {
    try {
      await _api.post('/approvals/$id/respond', {
        'action': action,
        if (reason != null) 'reason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'approved' ? '✅ تمت الموافقة' : '✎ تم طلب تعديل'),
        ));
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تنفيذ الإجراء')));
    }
  }

  Future<void> _showEditRequestDialog(int id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('طلب تعديل'),
          content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'اذكر التعديلات المطلوبة...')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('إرسال الطلب')),
          ],
        );
      },
    );
    if (reason != null && mounted) _respond(id, 'edit_requested', reason.isEmpty ? null : reason);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final isSA = _api.role == 'super_admin';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isSA)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('إنشاء طلب موافقة', style: ShadTypography.cardTitle),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'عنوان الطلب *', hintText: 'مثال: اعتماد التصميم النهائي'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'الوصف', hintText: 'تفاصيل إضافية...'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: Icon(Icons.attach_file, size: 18),
                    label: Text(_selectedFileNames.isNotEmpty ? '${_selectedFileNames.length} ملفات' : 'إرفاق ملفات'),
                  ),
                  if (_selectedFileNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(spacing: 4, runSpacing: 2, children: _selectedFileNames.map((n) => Chip(
                        label: Text(n, style: const TextStyle(fontSize: 10)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          final idx = _selectedFileNames.indexOf(n);
                          setState(() {
                            _selectedFiles.removeAt(idx);
                            _selectedFileNames.removeAt(idx);
                          });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList()),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _create,
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('إرسال طلب موافقة'),
                    ),
                  ),
                ]),
              ),
            ),
          Text('الطلبات السابقة', style: ShadTypography.sectionHeader),
          const SizedBox(height: 8),
          if (_approvals.isEmpty)
            const EmptyState(icon: Icons.check_circle_outlined, title: 'لا توجد طلبات موافقة')
          else
            ..._approvals.map((a) {
              final hasCertificate = a['certificate'] != null && a['certificate']['pdf_url'] != null;
              final status = a['status'] ?? 'pending';
              final accentColor = status == 'approved' ? ShadColors.success :
                  status == 'rejected' || status == 'edit_requested' ? ShadColors.error : ShadColors.gold;
              final createdAt = a['created_at'] as String?;
              final requestedBy = a['requested_by_name'] as String? ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: ShadColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            a['title'] ?? '',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
                          ),
                          if (a['description'] != null && (a['description'] as String).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(a['description'], style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 8),
                          Row(children: [
                            if (requestedBy.isNotEmpty) ...[
                              Icon(Icons.person_outline, size: 13, color: ShadColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(requestedBy, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ShadColors.textSecondary)),
                              const SizedBox(width: 12),
                            ],
                            if (createdAt != null) ...[
                              Icon(Icons.access_time, size: 13, color: ShadColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(createdAt.split('T')[0], style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                            ],
                          ]),
                          if (a['reference_no'] != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ShadColors.gold.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('المرجع: ${a['reference_no']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ShadColors.gold)),
                            ),
                          ],
                        ])),
                        const SizedBox(width: 10),
                        StatusBadge(status: status),
                      ]),
                      if (hasCertificate)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: InkWell(
                            onTap: () async {
                              final url = _api.resolveFileUrl(a['certificate']['pdf_url'] as String);
                              final uri = Uri.tryParse(url);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: ShadColors.gold.withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ShadColors.gold.withAlpha(40)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.picture_as_pdf, size: 18, color: ShadColors.gold),
                                const SizedBox(width: 8),
                                Text('شهادة الموافقة', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.gold)),
                              ]),
                            ),
                          ),
                        ),
                      if (a['action_taken'] == true) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: a['action_result'] == 'approved' ? ShadColors.successLight : ShadColors.errorLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: a['action_result'] == 'approved' ? ShadColors.success.withAlpha(40) : ShadColors.error.withAlpha(40),
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              a['action_result'] == 'approved' ? Icons.check_circle : Icons.cancel,
                              size: 18, color: a['action_result'] == 'approved' ? ShadColors.success : ShadColors.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              a['action_result'] == 'approved' ? 'تمت الموافقة' : 'تم طلب التعديل',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: a['action_result'] == 'approved' ? ShadColors.success : ShadColors.error),
                            )),
                          ]),
                        ),
                      ],
                      if (status == 'edit_requested' && a['reason'] != null && (a['reason'] as String).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ShadColors.gold.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ShadColors.gold.withAlpha(40)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('سبب التعديل:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ShadColors.gold)),
                            const SizedBox(height: 4),
                            Text(a['reason'] as String, style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary)),
                          ]),
                        ),
                      ],
                      if (status == 'pending' && !isSA && a['requested_by'] != _api.userId)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _respond(a['id'], 'approved', null),
                                icon: const Icon(Icons.check, size: 15),
                                label: const Text('موافقة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ShadColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showEditRequestDialog(a['id']),
                                icon: const Icon(Icons.edit, size: 15),
                                label: const Text('طلب تعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ]),
                  )),
                ]),
              );
            }),
        ],
      ),
    );
  }
}
