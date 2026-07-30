import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

class ContractDetailModal extends StatefulWidget {
  final dynamic contract;
  final Future<void> Function(int, String) onAction;
  final VoidCallback onRefresh;
  final VoidCallback? onGoToPayments;
  final String backLabel;
  final int? workspaceId;

  const ContractDetailModal({
    super.key,
    required this.contract,
    required this.onAction,
    required this.onRefresh,
    this.onGoToPayments,
    this.backLabel = 'كل العقود',
    this.workspaceId,
  });

  @override
  State<ContractDetailModal> createState() => _ContractDetailModalState();
}

class _ContractDetailModalState extends State<ContractDetailModal> {
  final _api = ApiClient();
  bool _uploading = false;
  List<dynamic> _uploadedFiles = [];
  bool _loadingFiles = false;
  Map<String, dynamic>? _fullContract;

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
    _loadFullContract();
  }

  Future<void> _loadFullContract() async {
    final existingClauses = widget.contract['clauses'] as List<dynamic>?;
    final existingReqDocs = widget.contract['required_documents'] as List<dynamic>?;
    if ((existingClauses?.isNotEmpty == true) || (existingReqDocs?.isNotEmpty == true)) return;

    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    try {
      final data = await _api.get('/workspaces/$wsId/contracts');
      final list = safeList(data['contracts']);
      final contractId = widget.contract['id'];
      for (final cc in list) {
        if (cc is Map && cc['id'] == contractId) {
          _fullContract = Map<String, dynamic>.from(cc);
          break;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadUploadedFiles() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    setState(() => _loadingFiles = true);
    try {
      final data = await _api.get('/workspaces/$wsId/files');
      final allFiles = safeList(data['files']);
      final contractId = widget.contract['id'];
      _uploadedFiles = allFiles.where((f) => f['contract_id'] == contractId).toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingFiles = false);
  }

  Future<void> _uploadDocument(int contractId, int? definitionId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.single;
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;

    setState(() => _uploading = true);
    try {
      final fields = <String, dynamic>{'contract_id': contractId};
      if (definitionId != null) fields['contract_required_document_id'] = definitionId;
      if (kIsWeb) {
        await _api.multipartPost('/workspaces/$wsId/files', fields, bytes: pf.bytes, filename: pf.name);
      } else {
        await _api.multipartPost('/workspaces/$wsId/files', fields, file: File(pf.path!));
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم رفع المستند')));
      widget.onRefresh();
      await _loadUploadedFiles();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع المستند: $e')));
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = _fullContract ?? widget.contract;
    final status = c['status'] as String? ?? '';
    final clauses = c['clauses'] as List<dynamic>? ?? [];
    final requiredDocs = c['required_documents'] as List<dynamic>? ?? [];
    final needsAction = status == 'sent';
    final isCompanyApproved = status == 'company_approved';

    final progress = double.tryParse((c['progress'] ?? '').toString()) ?? 0.0;
    final stageIndex = _computeStageIndex(c);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 16),
        child: ListView(
          controller: scrollController,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Row(children: [
                const Icon(Icons.arrow_forward_ios, size: 12, color: ShadColors.textSecondary),
                const SizedBox(width: 6),
                Text(widget.backLabel, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 14),

            // detail-card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['title'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                if (c['contract_type'] == 'additional')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [ShadColors.gold.withAlpha(50), ShadColors.gold.withAlpha(25)]),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ShadColors.gold.withAlpha(80)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_circle_outline, size: 12, color: ShadColors.gold),
                        SizedBox(width: 4),
                        Text('عقد خدمة إضافية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ShadColors.gold)),
                      ]),
                    ),
                  ),
                if (c['contract_type'] != 'additional')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A4A6A).withAlpha(60),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF4A8AC0).withAlpha(80)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.description_outlined, size: 12, color: Color(0xFF4A8AC0)),
                        SizedBox(width: 4),
                        Text('عقد أساسي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4A8AC0))),
                      ]),
                    ),
                  ),
                const SizedBox(height: 4),
                Text('#${c['id'] ?? ''}', style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
                const SizedBox(height: 12),
                Text('${c['value'] ?? 0} ${c['currency'] as String? ?? 'SAR'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: const AlwaysStoppedAnimation(ShadColors.gold),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: List.generate(4, (i) {
                  final done = i < stageIndex;
                  final current = i == stageIndex;
                  return Expanded(
                    child: Container(
                      height: 5, margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: done ? ShadColors.crimson : current ? ShadColors.gold : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                })),
              ]),
            ),
            const SizedBox(height: 16),

            // Info rows
            Text('معلومات العقد', style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
            const SizedBox(height: 8),
            if (c['start_date'] != null)
              _infoRow('تاريخ البداية', (c['start_date'] as String).split('T')[0]),
            if (c['end_date'] != null)
              _infoRow('تاريخ الإنتهاء', (c['end_date'] as String).split('T')[0]),
            if (c['value'] != null)
              _infoRow('قيمة العقد', '${c['value']} ${c['currency'] as String? ?? 'SAR'}', gold: true),
            if (c['paid'] != null)
              _infoRow('المدفوع', '${c['paid']} ${c['currency'] as String? ?? 'SAR'}', gold: true),
            if (c['remaining'] != null)
              _infoRow('المتبقي', '${c['remaining']} ${c['currency'] as String? ?? 'SAR'}'),
            const SizedBox(height: 16),

            // Clauses (only in modal)
            if (clauses.isNotEmpty) ...[
              Text('بنود العقد', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
              const SizedBox(height: 8),
              ...clauses.map((cl) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ShadColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.circle, size: 6, color: ShadColors.textDisabled),
                  const SizedBox(width: 8),
                  Expanded(child: Text(cl['content'] ?? '', style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary))),
                ]),
              )),
              const SizedBox(height: 16),
            ],

            // Required documents (only show when action is needed)
            if (requiredDocs.isNotEmpty && needsAction) ...[
              Text('المستندات المطلوبة', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
              const SizedBox(height: 8),
              ...requiredDocs.map((doc) {
                final docStatus = doc['status'] as String? ?? 'pending';
                final docStatusColor = docStatus == 'approved'
                    ? ShadColors.success
                    : docStatus == 'rejected'
                        ? ShadColors.error
                        : ShadColors.warning;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ShadColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ShadColors.cardBorder),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(doc['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ShadColors.textPrimary))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: docStatusColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabels[docStatus] ?? docStatus,
                          style: TextStyle(fontSize: 10, color: docStatusColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                    if (doc['rejection_reason'] != null) ...[
                      const SizedBox(height: 4),
                      Text('سبب الرفض: ${doc['rejection_reason']}', style: const TextStyle(fontSize: 11, color: ShadColors.error)),
                    ],
                    if (docStatus != 'approved') ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _uploading ? null : () => _uploadDocument(c['id'], doc['id']),
                          icon: _uploading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file, size: 16),
                          label: Text(_uploading ? 'جاري الرفع...' : 'رفع المستند'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ShadColors.primary,
                            side: const BorderSide(color: ShadColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                    ],
                  ]),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Uploaded files
            if (_loadingFiles) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
            ] else if (_uploadedFiles.isNotEmpty) ...[
              Text('الملفات المرفوعة', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
              const SizedBox(height: 8),
              ..._uploadedFiles.map((f) {
                final fStatus = f['status'] as String? ?? '';
                final canDelete = fStatus != 'approved';
                return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ShadColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.attach_file, size: 16, color: ShadColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _downloadFile(f['file_url'] as String? ?? ''),
                      child: Text(f['name'] ?? '', style: const TextStyle(fontSize: 12, color: ShadColors.primary, decoration: TextDecoration.underline))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: fStatus == 'approved'
                          ? ShadColors.success.withAlpha(25)
                          : ShadColors.warning.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusLabels[fStatus] ?? fStatus,
                      style: TextStyle(fontSize: 9, color: fStatus == 'approved' ? ShadColors.success : ShadColors.warning),
                    ),
                  ),
                  if (canDelete) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _deleteFile(f),
                      child: const Icon(Icons.close, size: 16, color: ShadColors.error),
                    ),
                  ],
                ]),
              );
              }),
              const SizedBox(height: 16),
            ],

            // Action buttons
            if (needsAction) ...[
              Text('الإجراءات', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.textPrimary)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await widget.onAction(c['id'], 'approved');
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('موافقة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShadColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.onAction(c['id'], 'edit_requested');
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('تعديل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ShadColors.warning,
                      side: const BorderSide(color: ShadColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ]),
            ],

            // Download PDF (shown whenever available)
            if (c['pdf_url'] != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _downloadPdf(c['pdf_url'] as String),
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('تحميل العقد (PDF)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ShadColors.gold,
                    side: const BorderSide(color: ShadColors.gold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],

            if (isCompanyApproved) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ShadColors.success.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShadColors.success.withAlpha(40)),
                ),
                child: Column(children: [
                  const Icon(Icons.check_circle, size: 40, color: ShadColors.success),
                  const SizedBox(height: 8),
                  Text('تم اعتماد العقد من قبل الشركة', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ShadColors.success)),
                  const SizedBox(height: 4),
                  Text('يمكنك التوجه إلى صفحة الدفع لإتمام الدفعة', style: const TextStyle(fontSize: 12, color: ShadColors.success)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onGoToPayments?.call();
                    },
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('💳 انتقال إلى الدفع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShadColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ]),
              ),
            ],

            // Status messages
            if (!needsAction && !isCompanyApproved && status != 'draft') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ShadColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShadColors.cardBorder),
                ),
                child: Center(
                  child: Text(
                    status == 'client_approved' ? 'تمت موافقتك على هذا العقد' :
                    status == 'edit_requested' ? 'قمت بطلب تعديل العقد' :
                    status == 'rejected' ? 'قمت برفض هذا العقد' :
                    status == 'completed' ? 'العقد مكتمل' : '',
                    style: const TextStyle(fontSize: 13, color: ShadColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static int _computeStageIndex(dynamic c) {
    final stageMap = <String, int>{
      'onboarding': 0, 'draft': 0, 'sent': 0,
      'client_approved': 1, 'edit_requested': 1,
      'company_approved': 2,
      'completed': 3,
      'archived': 3,
    };
    return stageMap[c['status'] as String? ?? ''] ?? 0;
  }

  Widget _infoRow(String label, String value, {bool gold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShadColors.cardBorder, width: 0.5)),
      ),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 12, color: gold ? ShadColors.gold : ShadColors.textPrimary, fontWeight: gold ? FontWeight.w600 : FontWeight.w400)),
      ]),
    );
  }

  Future<void> _downloadFile(String fileUrl) async {
    if (fileUrl.isEmpty) return;
    final url = _api.resolveFileUrl(fileUrl);
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رابط الملف غير صالح')));
      }
    }
  }

  Future<void> _downloadPdf(String pdfUrl) async {
    final url = _api.resolveFileUrl(pdfUrl);
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رابط الملف غير صالح')));
      }
    }
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

    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;

    try {
      await _api.delete('/workspaces/$wsId/files/${file['id']}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الملف')));
      await _loadUploadedFiles();
      widget.onRefresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل حذف الملف: $e')));
    }
  }
}
