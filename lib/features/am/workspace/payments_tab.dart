import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';

class PaymentsTab extends StatefulWidget {
  final int? workspaceId;
  final VoidCallback? onWorkspaceUpdate;
  final ApiClient? api;
  const PaymentsTab({super.key, this.workspaceId, this.onWorkspaceUpdate, this.api});

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
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
    setState(() { if (_payments.isEmpty) _loading = true; _error = null; });
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
      if (mounted) _error = AppLocalizations.of(context)?.paymentsFailedToLoad;
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

  String _installmentLabel(int index, AppLocalizations l10n) {
    final labels = [l10n.paymentsOrdinalFirst, l10n.paymentsOrdinalSecond, l10n.paymentsOrdinalThird, l10n.paymentsOrdinalFourth, l10n.paymentsOrdinalFifth, l10n.paymentsOrdinalSixth, l10n.paymentsOrdinalSeventh, l10n.paymentsOrdinalEighth, l10n.paymentsOrdinalNinth, l10n.paymentsOrdinalTenth];
    return index < labels.length ? l10n.paymentsInstallmentFormat(labels[index]) : l10n.paymentsInstallmentFormatNumbered(index + 1);
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
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'approved' ? l10n.paymentsApprovePayment : l10n.paymentsRejectPayment),
        content: Text(action == 'approved' ? l10n.paymentsApproveConfirmMsg : l10n.paymentsRejectConfirmMsg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: action == 'approved' ? ShadColors.success : ShadColors.error),
            child: Text(action == 'approved' ? l10n.confirm : l10n.reject),
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
          content: Row(children: [
            Icon(displayAction == 'approved' ? Icons.check_circle : Icons.cancel, color: displayAction == 'approved' ? Colors.green : Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(displayAction == 'approved'
                ? (wsActive ? l10n.paymentsApprovedWorkspaceActive : l10n.paymentsApprovedWorkspacePending)
                : l10n.paymentsRejectedMsg)),
          ]),
        ));
        _load();
        widget.onWorkspaceUpdate?.call();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState(itemCount: 3);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final l10n = AppLocalizations.of(context)!;
    if (_payments.isEmpty) return EmptyState(icon: Icons.payment_outlined, title: l10n.paymentsEmpty);

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
                color: ShadColors.surfaceDarker,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Column(children: [
                if (isFullyPaid) ...[
                  const Icon(Icons.check_circle, size: 28, color: ShadColors.success),
                  const SizedBox(height: 6),
                  Text(l10n.paymentsPaidInFull, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.success)),
                  const SizedBox(height: 4),
                  Text('${_totalPaid.toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                ] else ...[
                  Text(l10n.paymentsTotalPaid, style: const TextStyle(fontSize: 12, color: ShadColors.gold)),
                  const SizedBox(height: 6),
                  Text('${_totalPaid.toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  const SizedBox(height: 4),
                  Text(l10n.paymentsRemainingSummary(grandTotal.toStringAsFixed(2), contractCur, (grandTotal - _totalPaid).toStringAsFixed(2)), style: const TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
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
                      Text(l10n.paymentsTaxDetails, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ShadColors.gold)),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(l10n.paymentsContractsValue, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
                        Text('${(_taxSummary!['contracts_total'] ?? 0).toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 2),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(l10n.paymentsTaxRow((_taxSummary!['tax_percentage'] ?? 0).toDouble()), style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
                        Text('${(_taxSummary!['tax_amount'] ?? 0).toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ShadColors.gold)),
                      ]),
                      const Divider(height: 10, color: ShadColors.cardBorder),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(l10n.paymentsTotalRow, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
          final statusText = isApproved ? l10n.paymentsStatusApproved : isPending ? l10n.paymentsStatusPending : isOverdue ? l10n.paymentsStatusOverdue : isScheduled ? l10n.paymentsStatusScheduled : p['status'] ?? '';

          final methodLabels = {'bank_transfer': l10n.paymentsMethodBankTransfer, 'swift': l10n.paymentsMethodSwift, 'corporate_account': l10n.paymentsMethodCorporateAccount, 'instapay': l10n.paymentsMethodInstapay, 'vodafone_cash': l10n.paymentsMethodVodafoneCash, 'mobile_wallet': l10n.paymentsMethodMobileWallet};

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
                // ── Top section ──
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _formatDate(p['created_at'] as String?).isNotEmpty
                          ? '${_installmentLabel(_payments.length - i, l10n)}  •  ${_formatDate(p['created_at'] as String?)}'
                          : _installmentLabel(_payments.length - i, l10n),
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
                        Text(l10n.paymentsDueDateFormat(_formatDate(p['due_date'])),
                          style: TextStyle(fontSize: 11, color: isOverdue ? ShadColors.error : ShadColors.textSecondary)),
                      ]),
                    ],
                  ]),
                ),

                // ── Divider ──
                Divider(height: 1, color: ShadColors.cardBorder),

                // ── Bottom section ──
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
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
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.paymentsFileOpenFailed)));
                              }
                            },
                            child: Row(children: [
                              Text('📎 ', style: TextStyle(fontSize: 12)),
                              Text(l10n.paymentsViewProof, style: TextStyle(fontSize: 12, color: ShadColors.gold)),
                            ]),
                          ),
                        ));
                      })(),
                    // ── Approve/Reject buttons (SA only) ──
                    if (isPending && isSA) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _review(p['id'], 'approved'),
                            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.success),
                            child: Text(l10n.approve),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _review(p['id'], 'rejected'),
                            style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error),
                            child: Text(l10n.reject),
                          ),
                        ),
                      ]),
                    ],
                    // ── Edit/Clear scheduled installment buttons ──
                    if (isManagerScheduled && (isScheduled || isOverdue)) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showEditScheduleSheet(p),
                            icon: const Icon(Icons.edit, size: 14),
                            label: Text(l10n.edit),
                            style: OutlinedButton.styleFrom(foregroundColor: ShadColors.gold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteSchedule(p['id']),
                            icon: const Icon(Icons.delete, size: 14),
                            label: Text(l10n.paymentsClear),
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
    final l10n = AppLocalizations.of(context)!;
    final installments = <Map<String, dynamic>>[];
    final amountCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    String selectedCurrency = 'SAR';

    const currencies = ['SAR', 'USD', 'EUR', 'AED', 'EGP', 'KWD', 'QAR', 'BHD', 'OMR'];
    final currencyLabels = {
      'SAR': l10n.currencySar, 'USD': l10n.currencyUsd, 'EUR': l10n.currencyEur,
      'AED': l10n.currencyAed, 'EGP': l10n.currencyEgp, 'KWD': l10n.currencyKwd,
      'QAR': l10n.currencyQar, 'BHD': l10n.currencyBhd, 'OMR': l10n.currencyOmr,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final sheetL10n = AppLocalizations.of(ctx)!;
          return Padding(
            padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(sheetL10n.paymentsScheduleTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                decoration: InputDecoration(labelText: '${sheetL10n.paymentsAmount} *', hintText: '0.00'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCurrency,
                decoration: InputDecoration(labelText: sheetL10n.paymentsCurrency),
                items: currencies.map((c) => DropdownMenuItem(value: c, child: Text('$c — ${currencyLabels[c] ?? c}', style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) { if (v != null) setSheetState(() => selectedCurrency = v); },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(labelText: sheetL10n.paymentsDescriptionOptional, hintText: sheetL10n.paymentsDescriptionHint),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text('${sheetL10n.paymentsDueDate}: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
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
                  child: Text(sheetL10n.clientDetailSelectDate),
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
                        'installment_label': labelCtrl.text.isNotEmpty ? labelCtrl.text : sheetL10n.paymentsInstallmentFormatNumbered(installments.length + 1),
                      });
                      amountCtrl.clear();
                      labelCtrl.clear();
                      selectedDate = DateTime.now().add(const Duration(days: 30));
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(sheetL10n.paymentsAddInstallment),
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
                  child: Text(sheetL10n.paymentsScheduleCount(installments.length), style: const TextStyle(color: Colors.black)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _schedulePayments(List<Map<String, dynamic>> installments) async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    try {
      await _api.post('/workspaces/$wsId/payments/schedule', {'installments': installments});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.paymentsScheduledSuccess)])));
        _load();
      }
    } catch (e) {
      debugPrint('[payments_tab] _schedulePayments error: $e');
      if (mounted) {
        final msg = e.toString().contains('ValidationException') ? '${AppLocalizations.of(context)!.paymentsInvalidData}: $e' : '${AppLocalizations.of(context)!.paymentsScheduleFailed}: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _updateSchedule(int paymentId, Map<String, dynamic> data) async {
    try {
      await _api.put('/payments/$paymentId/schedule', data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.paymentsInstallmentUpdated)])));
        _load();
      }
    } catch (e) {
      debugPrint('[payments_tab] _updateSchedule error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.paymentsInstallmentUpdateFailed)));
    }
  }

  Future<void> _deleteSchedule(int paymentId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.paymentsClearInstallmentTitle),
        content: Text(l10n.paymentsClearInstallmentConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ShadColors.error), child: Text(l10n.paymentsClear)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/payments/$paymentId/schedule');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.paymentsInstallmentCleared)])));
        _load();
      }
    } catch (e) {
      debugPrint('[payments_tab] _deleteSchedule error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.paymentsInstallmentClearFailed)));
    }
  }

  void _showEditScheduleSheet(dynamic p) {
    final l10n = AppLocalizations.of(context)!;
    final amountCtrl = TextEditingController(text: p['amount']?.toString() ?? '');
    final labelCtrl = TextEditingController(text: p['installment_label'] ?? '');
    DateTime selectedDate = DateTime.tryParse(p['due_date'] ?? '') ?? DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.paymentsEditInstallmentTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              decoration: InputDecoration(labelText: '${l10n.paymentsAmount} *'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(labelText: l10n.paymentsDescription),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('${l10n.paymentsDueDate}: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
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
                child: Text(l10n.clientDetailSelectDate),
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
                child: Text(l10n.saveChanges, style: const TextStyle(color: Colors.black)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showRequestPaymentSheet() {
    final l10n = AppLocalizations.of(context)!;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCurrency = 'SAR';

    const currencies = ['SAR', 'USD', 'EUR', 'AED', 'EGP', 'KWD', 'QAR', 'BHD', 'OMR'];
    final currencyLabels = {
      'SAR': l10n.currencySar, 'USD': l10n.currencyUsd, 'EUR': l10n.currencyEur,
      'AED': l10n.currencyAed, 'EGP': l10n.currencyEgp, 'KWD': l10n.currencyKwd,
      'QAR': l10n.currencyQar, 'BHD': l10n.currencyBhd, 'OMR': l10n.currencyOmr,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(l10n.paymentsRequestPayment, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 4),
            Text(l10n.paymentsRequestHint, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              decoration: InputDecoration(labelText: '${l10n.paymentsAmount} *', hintText: '0.00'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedCurrency,
              decoration: InputDecoration(labelText: l10n.paymentsCurrency),
              items: currencies.map((c) => DropdownMenuItem(value: c, child: Text('$c — ${currencyLabels[c] ?? c}', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) { if (v != null) setSheetState(() => selectedCurrency = v); },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: l10n.paymentsNoteOptional, hintText: l10n.paymentsNoteHint),
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
                child: Text(l10n.paymentsSendRequest, style: const TextStyle(color: Colors.black)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.paymentsRequestSent)])));
        _load();
      }
    } catch (e) {
      debugPrint('[payments_tab] _requestPayment error: $e');
      if (mounted) {
        final msg = e.toString().contains('ValidationException') ? '${AppLocalizations.of(context)!.paymentsInvalidData}: $e' : '${AppLocalizations.of(context)!.paymentsSendFailed}: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }
}

List safeList(dynamic value) {
  if (value is List) return value;
  return [];
}
