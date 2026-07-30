import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';

class PaymentsTab extends StatefulWidget {
  final int? workspaceId;
  final VoidCallback? onWorkspaceUpdate;
  const PaymentsTab({super.key, this.workspaceId, this.onWorkspaceUpdate});

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  final _api = ApiClient();
  List<dynamic> _payments = [];
  List<dynamic> _contracts = [];
  Map<String, dynamic>? _taxSummary;
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait<Map<String, dynamic>>([
        _api.get('/workspaces/$wsId/payments'),
        _api.get('/workspaces/$wsId/contracts'),
      ]);
      _payments = (results[0]['payments'] as List<dynamic>?) ?? [];
      _taxSummary = results[0]['tax_summary'] as Map<String, dynamic>?;
      final rawContracts = results[1]['contracts'];
      _contracts = rawContracts is List ? rawContracts : (rawContracts is Map ? (rawContracts['data'] ?? []) as List : []);
    } catch (_) {
      _error = 'فشل تحميل المدفوعات';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _payableContracts {
    return _contracts.cast<Map<String, dynamic>?>().where(
      (c) => c?['status'] == 'company_approved' || c?['status'] == 'completed',
    ).whereType<Map<String, dynamic>>().toList();
  }

  double get _totalPaid {
    return _payments
        .where((p) => p['status'] == 'approved')
        .fold<double>(0, (sum, p) => sum + (num.tryParse(p['amount']?.toString() ?? '')?.toDouble() ?? 0));
  }

  double get _grandTotal {
    if (_taxSummary != null) {
      return (_taxSummary!['grand_total'] as num?)?.toDouble() ?? 0;
    }
    final contracts = _payableContracts;
    if (contracts.isNotEmpty) {
      return contracts.fold<double>(0, (sum, c) => sum + (num.tryParse(c['value']?.toString() ?? '')?.toDouble() ?? 0));
    }
    return _payments.fold<double>(0, (s, p) => s + (num.tryParse(p['amount']?.toString() ?? '')?.toDouble() ?? 0));
  }

  String get _contractCurrency {
    final contracts = _payableContracts;
    return (contracts.isNotEmpty ? (contracts.first['currency'] as String?) : null) ?? 'SAR';
  }

  String _installmentLabel(int index) {
    const labels = ['الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة', 'السابعة', 'الثامنة', 'التاسعة', 'العاشرة'];
    return index < labels.length ? 'دفعة ${labels[index]}' : 'دفعة ${index + 1}';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _review(int id, [String action = 'approved']) async {
    if (_api.role != 'super_admin') return;
    final displayAction = action;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'approved' ? 'اعتماد الدفعة' : 'رفض الدفعة'),
        content: Text(action == 'approved' ? 'هل أنت متأكد من اعتماد هذه الدفعة؟' : 'هل أنت متأكد من رفض هذه الدفعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: action == 'approved' ? ShadColors.success : ShadColors.error),
            child: Text(action == 'approved' ? 'تأكيد' : 'رفض'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final data = await _api.post('/payments/$id/review', {'action': displayAction});
      if (mounted) {
        final wsActive = data['workspace']?['status'] == 'active';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(displayAction == 'approved'
              ? (wsActive ? '✅ تم اعتماد الدفعة — مساحة العمل نشطة' : '✅ تم اعتماد الدفعة — سيتم تفعيل مساحة العمل عند اكتمال الإجراءات')
              : '❌ تم رفض الدفعة'),
        ));
        _load();
        widget.onWorkspaceUpdate?.call();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState(itemCount: 3);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_payments.isEmpty) return const EmptyState(icon: Icons.payment_outlined, title: 'لا توجد مدفوعات');

    return Scaffold(
      floatingActionButton: _api.role == 'account_manager' ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'request',
            onPressed: _showRequestPaymentSheet,
            backgroundColor: ShadColors.gold,
            child: const Icon(Icons.request_quote, color: Colors.black, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'schedule',
            onPressed: _showScheduleSheet,
            backgroundColor: ShadColors.gold,
            child: const Icon(Icons.add, color: Colors.black),
          ),
        ],
      ) : null,
      body: RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payments.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            final grandTotal = _grandTotal;
            final contractCur = _contractCurrency;
            final progress = grandTotal > 0 ? (_totalPaid / grandTotal).clamp(0.0, 1.0) : 0.0;
            final isFullyPaid = _totalPaid >= grandTotal && grandTotal > 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Column(children: [
                if (isFullyPaid) ...[
                  const Icon(Icons.check_circle, size: 28, color: ShadColors.success),
                  const SizedBox(height: 6),
                  const Text('تم الدفع بالكامل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.success)),
                  const SizedBox(height: 4),
                  Text('${_totalPaid.toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                ] else ...[
                  Text('إجمالي المدفوع', style: TextStyle(fontSize: 12, color: ShadColors.gold)),
                  const SizedBox(height: 6),
                  Text('${_totalPaid.toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  const SizedBox(height: 4),
                  Text('من أصل ${grandTotal.toStringAsFixed(2)} $contractCur — متبقي ${(grandTotal - _totalPaid).toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
                ],
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: ShadColors.cardBorder,
                    valueColor: AlwaysStoppedAnimation(isFullyPaid ? ShadColors.success : ShadColors.gold),
                  ),
                ),
                if (_taxSummary != null && (_taxSummary!['tax_percentage'] ?? 0) > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('تفاصيل الضريبة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ShadColors.gold)),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('قيمة العقود', style: TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
                        Text('${(_taxSummary!['contracts_total'] ?? 0).toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 2),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('ضريبة ${(_taxSummary!['tax_percentage'] ?? 0)}%', style: TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
                        Text('${(_taxSummary!['tax_amount'] ?? 0).toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ShadColors.gold)),
                      ]),
                      const Divider(height: 10, color: ShadColors.cardBorder),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('الإجمالي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('${(_taxSummary!['grand_total'] ?? 0).toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ShadColors.gold)),
                      ]),
                    ]),
                  ),
                ],
              ]),
            );
          }
          final p = _payments[i - 1];
          final isSA = _api.role == 'super_admin';
          final isPending = p['status'] == 'pending';
          final isApproved = p['status'] == 'approved';
          final isScheduled = p['status'] == 'scheduled';
          final isOverdue = p['status'] == 'overdue';
          final isManagerScheduled = p['requested_by_manager'] == true;
          final statusColor = isApproved ? ShadColors.success : isPending ? ShadColors.gold : isOverdue ? ShadColors.error : isScheduled ? ShadColors.gold : ShadColors.textDisabled;
          final statusText = isApproved ? 'تمت الموافقة' : isPending ? 'قيد الانتظار' : isOverdue ? 'متأخر' : isScheduled ? 'مجدول' : p['status'] ?? '';

          final methodLabels = {'bank_transfer': 'تحويل بنكي', 'swift': 'SWIFT', 'corporate_account': 'حساب شركة', 'instapay': 'Instapay', 'vodafone_cash': 'فودافون كاش', 'mobile_wallet': 'محفظة موبايل'};

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: ShadColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isPending ? ShadColors.gold : ShadColors.cardBorder, width: isPending ? 1.5 : 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── القسم العلوي ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _formatDate(p['created_at'] as String?).isNotEmpty
                          ? '${_installmentLabel(_payments.length - i)}  •  ${_formatDate(p['created_at'] as String?)}'
                          : _installmentLabel(_payments.length - i),
                      style: TextStyle(fontSize: 11, color: ShadColors.gold, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('${p['amount'] ?? 0} ${p['currency'] as String? ?? 'SAR'}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(statusText, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500)),
                    ]),
                    if (p['due_date'] != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.calendar_today, size: 11, color: isOverdue ? ShadColors.error : ShadColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('الاستحقاق: ${_formatDate(p['due_date'])}',
                          style: TextStyle(fontSize: 11, color: isOverdue ? ShadColors.error : ShadColors.textSecondary)),
                      ]),
                    ],
                  ]),
                ),

                // ── الفاصل ──
                Divider(height: 1, color: ShadColors.cardBorder),

                // ── القسم السفلي ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((p['method_type'] ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Text('💳 ', style: TextStyle(fontSize: 12)),
                          Text(methodLabels[p['method_type']] ?? p['method_type'] ?? '', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                        ]),
                      ),
                    if (p['contract'] is Map && p['contract']['title'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Text('📄 ', style: TextStyle(fontSize: 12)),
                          Text(p['contract']['title'], style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                        ]),
                      ),
                    if (p['proof_file_url'] != null)
                      ...(() {
                        final urls = (p['proof_file_url'] is List) ? (p['proof_file_url'] as List).cast<String>() : [p['proof_file_url'].toString()];
                        return urls.map((url) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: InkWell(
                            onTap: () async {
                              final resolved = _api.resolveFileUrl(url);
                              final uri = Uri.tryParse(resolved);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
                              }
                            },
                            child: Row(children: [
                              Text('📎 ', style: TextStyle(fontSize: 12)),
                              Text('عرض إثبات الدفع', style: TextStyle(fontSize: 12, color: ShadColors.gold)),
                            ]),
                          ),
                        ));
                      })(),
                    // ── أزرار الاعتماد والرفض (للـ SA بس) ──
                    if (isPending && isSA) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _review(p['id'], 'approved'),
                            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.success),
                            child: const Text('اعتماد'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _review(p['id'], 'rejected'),
                            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error),
                            child: const Text('رفض'),
                          ),
                        ),
                      ]),
                    ],
                    // ── أزرار تعديل/مسح القسط المجدول ──
                    if (isManagerScheduled && (isScheduled || isOverdue)) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showEditScheduleSheet(p),
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('تعديل'),
                            style: OutlinedButton.styleFrom(foregroundColor: ShadColors.gold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteSchedule(p['id']),
                            icon: const Icon(Icons.delete, size: 14),
                            label: const Text('مسح'),
                            style: OutlinedButton.styleFrom(foregroundColor: ShadColors.error),
                          ),
                        ),
                      ]),
                    ],
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    ),
    );
  }

  void _showScheduleSheet() {
    final installments = <Map<String, dynamic>>[];
    final amountCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    String selectedCurrency = 'SAR';

    const currencies = ['SAR', 'USD', 'EUR', 'AED', 'EGP', 'KWD', 'QAR', 'BHD', 'OMR'];
    const currencyLabels = {
      'SAR': 'ريال سعودي', 'USD': 'دولار أمريكي', 'EUR': 'يورو',
      'AED': 'درهم إماراتي', 'EGP': 'جنيه مصري', 'KWD': 'دينار كويتي',
      'QAR': 'ريال قطري', 'BHD': 'دينار بحريني', 'OMR': 'ريال عmani',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('جدولة دفعات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'المبلغ *', hintText: '0.00'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedCurrency,
              decoration: const InputDecoration(labelText: 'العملة'),
              items: currencies.map((c) => DropdownMenuItem(value: c, child: Text('$c — ${currencyLabels[c] ?? c}', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) { if (v != null) setSheetState(() => selectedCurrency = v); },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'الوصف (اختياري)', hintText: 'مثال: القسط الأول'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('تاريخ الاستحقاق: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: const TextStyle(fontSize: 12))),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
                child: const Text('اختر تاريخ'),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text);
                  if (amount == null || amount <= 0) return;
                  setSheetState(() {
                    installments.add({
                      'amount': amount,
                      'currency': selectedCurrency,
                      'due_date': selectedDate.toIso8601String().split('T')[0],
                      'installment_label': labelCtrl.text.isNotEmpty ? labelCtrl.text : 'القسط ${installments.length + 1}',
                    });
                    amountCtrl.clear();
                    labelCtrl.clear();
                    selectedDate = DateTime.now().add(const Duration(days: 30));
                  });
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة قسط'),
              ),
            ),
            if (installments.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  itemCount: installments.length,
                  itemBuilder: (_, i) {
                    final inst = installments[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: ShadColors.error),
                        onPressed: () => setSheetState(() => installments.removeAt(i)),
                      ),
                      title: Text(inst['installment_label'] ?? '', style: const TextStyle(fontSize: 12)),
                      subtitle: Text('${inst['amount']} ${inst['currency'] ?? 'SAR'} — ${inst['due_date']}', style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: installments.isEmpty ? null : () async {
                  Navigator.pop(ctx);
                  await _schedulePayments(installments);
                },
                style: ElevatedButton.styleFrom(backgroundColor: ShadColors.gold),
                child: Text('جدولة (${installments.length} أقساط)', style: const TextStyle(color: Colors.black)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _schedulePayments(List<Map<String, dynamic>> installments) async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    try {
      await _api.post('/workspaces/$wsId/payments/schedule', {'installments': installments});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تمت جدولة الدفعات')));
        _load();
      }
    } catch (e) {
      debugPrint('[payments_tab] _schedulePayments error: $e');
      if (mounted) {
        final msg = e.toString().contains('ValidationException') ? 'بيانات غير صحيحة: $e' : 'فشل جدولة الدفعات: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _updateSchedule(int paymentId, Map<String, dynamic> data) async {
    try {
      await _api.put('/payments/$paymentId/schedule', data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تحديث القسط')));
        _load();
      }
    } catch (e) {
      debugPrint('[payments_tab] _updateSchedule error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحديث القسط')));
    }
  }

  Future<void> _deleteSchedule(int paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح القسط'),
        content: const Text('هل أنت متأكد من مسح هذا القسط؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error), child: const Text('مسح')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/payments/$paymentId/schedule');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم مسح القسط')));
        _load();
      }
    } catch (e) {
      debugPrint('[payments_tab] _deleteSchedule error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل مسح القسط')));
    }
  }

  void _showEditScheduleSheet(dynamic p) {
    final amountCtrl = TextEditingController(text: p['amount']?.toString() ?? '');
    final labelCtrl = TextEditingController(text: p['installment_label'] ?? '');
    DateTime selectedDate = DateTime.tryParse(p['due_date'] ?? '') ?? DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('تعديل القسط', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'المبلغ *'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('الاستحقاق: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: const TextStyle(fontSize: 12))),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
                child: const Text('اختر تاريخ'),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text);
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(ctx);
                  await _updateSchedule(p['id'], {
                    'amount': amount,
                    'due_date': selectedDate.toIso8601String().split('T')[0],
                    'installment_label': labelCtrl.text,
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: ShadColors.gold),
                child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.black)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showRequestPaymentSheet() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCurrency = 'SAR';

    const currencies = ['SAR', 'USD', 'EUR', 'AED', 'EGP', 'KWD', 'QAR', 'BHD', 'OMR'];
    const currencyLabels = {
      'SAR': 'ريال سعودي', 'USD': 'دولار أمريكي', 'EUR': 'يورو',
      'AED': 'درهم إماراتي', 'EGP': 'جنيه مصري', 'KWD': 'دينار كويتي',
      'QAR': 'ريال قطري', 'BHD': 'دينار بحريني', 'OMR': 'ريال عmani',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('طلب دفعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 4),
            Text('ابعت طلب دفعة للعميل', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'المبلغ *', hintText: '0.00'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedCurrency,
              decoration: const InputDecoration(labelText: 'العملة'),
              items: currencies.map((c) => DropdownMenuItem(value: c, child: Text('$c — ${currencyLabels[c] ?? c}', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) { if (v != null) setSheetState(() => selectedCurrency = v); },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', hintText: 'مثال: دفعة العقد الأول'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text);
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(ctx);
                  await _requestPayment(amount, selectedCurrency, noteCtrl.text);
                },
                style: ElevatedButton.styleFrom(backgroundColor: ShadColors.gold),
                child: const Text('إرسال الطلب', style: TextStyle(color: Colors.black)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _requestPayment(double amount, String currency, String notes) async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    try {
      final body = <String, dynamic>{
        'amount': amount,
        'currency': currency,
      };
      if (notes.isNotEmpty) body['notes'] = notes;
      await _api.post('/workspaces/$wsId/payments/request', body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إرسال طلب الدفعة')));
        _load();
      }
    } catch (e) {
      debugPrint('[payments_tab] _requestPayment error: $e');
      if (mounted) {
        final msg = e.toString().contains('ValidationException') ? 'بيانات غير صحيحة: $e' : 'فشل إرسال الطلب: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }
}

List safeList(dynamic value) {
  if (value is List) return value;
  return [];
}
