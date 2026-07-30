import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';

class ApprovalsPage extends StatefulWidget {
  final int? workspaceId;
  const ApprovalsPage({super.key, this.workspaceId});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  final _api = ApiClient();
  List<dynamic> _approvals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) {
      _error = 'لم يتم تحديد Workspace';
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _api.get('/workspaces/$wsId/approvals');
      _approvals = safeList(data['approvals']);
    } catch (_) {
      _error = 'فشل تحميل طلبات الموافقة';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _respond(int id, String action) async {
    if (action == 'edit_requested') {
      final reason = await _showEditRequestDialog();
      if (reason == null) return;
      try {
        await _api.post('/approvals/$id/respond', {'action': action, 'reason': reason});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✎ تم طلب التعديل')));
          _load();
        }
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تنفيذ الإجراء')));
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد الموافقة'),
          content: const Text('سيتم استخدام توقيعك الإلكتروني المحفوظ. هل أنت متأكد؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: ShadColors.success),
              child: const Text('موافقة'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await _api.post('/approvals/$id/respond', {'action': action});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تمت الموافقة')));
          _load();
        }
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تنفيذ الإجراء')));
      }
    }
  }

  Future<String?> _showEditRequestDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب تعديل'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('اذكر التعديلات المطلوبة:', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'مثال: عدّل ألوان التصميم...'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.gold),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final sorted = List<dynamic>.from(_approvals);
    sorted.sort((a, b) {
      final aCompleted = a['status'] == 'completed' || a['status'] == 'approved';
      final bCompleted = b['status'] == 'completed' || b['status'] == 'approved';
      if (aCompleted && !bCompleted) return 1;
      if (!aCompleted && bCompleted) return -1;
      return 0;
    });

    if (sorted.isEmpty) {
      return const EmptyState(icon: Icons.check_circle_outlined, title: 'لا توجد طلبات موافقة');
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...sorted.map((a) {
            final hasCertificate = a['certificate'] != null && a['certificate']['pdf_url'] != null;
            final status = a['status'] ?? 'pending';
            final accentColor = status == 'approved' ? ShadColors.success :
                status == 'rejected' || status == 'edit_requested' ? ShadColors.error : ShadColors.gold;
            final createdAt = a['created_at'] as String?;
            final requestedBy = a['requested_by_name'] as String? ?? '';
            final isCompleted = status == 'approved' || status == 'completed' || status == 'edit_requested';
            final actionTaken = a['action_taken'] == true;
            final reason = a['reason'] as String?;

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
                    if (actionTaken) ...[
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
                    if (reason != null && reason.isNotEmpty && status == 'edit_requested') ...[
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
                          Text(reason, style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary)),
                        ]),
                      ),
                    ],
                    if (!isCompleted && status == 'pending')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _respond(a['id'], 'approved'),
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
                              onPressed: () => _respond(a['id'], 'edit_requested'),
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
