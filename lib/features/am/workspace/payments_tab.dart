import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/widgets/reject_reason_dialog.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/payment_provider.dart';

class PaymentsTab extends StatefulWidget {
  final int? workspaceId;
  final VoidCallback? onWorkspaceUpdate;
  final ApiClient? api;
  final PaymentProvider? paymentProvider;
  final ContractProvider? contractProvider;
  const PaymentsTab({
    super.key,
    this.workspaceId,
    this.onWorkspaceUpdate,
    this.api,
    this.paymentProvider,
    this.contractProvider,
  });

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final PaymentProvider _paymentProvider = widget.paymentProvider ?? PaymentProvider();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider();
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
      // Future.wait (not sequential) so a contracts-fetch failure aborts the
      // whole load and surfaces `_error` — unlike payments_page.dart, which
      // treats that failure as "no contracts" and keeps going.
      final results = await Future.wait<dynamic>([
        _paymentProvider.fetchWorkspaceEnvelope(wsId),
        _contractProvider.fetchWorkspaceContractsRaw(wsId),
      ]);
      final paymentsResult = results[0] as Map<String, dynamic>;
      _payments = (paymentsResult['payments'] as List<dynamic>?) ?? [];
      _taxSummary = paymentsResult['tax_summary'] as Map<String, dynamic>?;
      _contracts = results[1] as List<dynamic>;
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

  // num.tryParse(v?.toString() ?? '') rather than `v as num?` or `(v ?? 0)`:
  // both of those assume the server already sent a num, which
  // payments_page.dart's equivalent field-read never assumed (it already
  // used num.tryParse). If tax_summary's fields ever come back as a String
  // (a Laravel decimal cast, an API Resource change, pagination — anything
  // touching serialization), `as num?` throws a TypeError and `(v ?? 0)`
  // throws a NoSuchMethodError the moment .toDouble()/.toStringAsFixed()/`>`
  // is called on a String, taking the whole build() down. Not currently
  // triggered (the backend returns numeric today), but this is a getter
  // called from build(), so when it does trigger it's a crash, not a bad
  // value. See docs/mobile-review-2026-08.md, P1 #4.
  double _taxNum(dynamic v) => num.tryParse(v?.toString() ?? '')?.toDouble() ?? 0;

  double get _grandTotal {
    if (_taxSummary != null) {
      return _taxNum(_taxSummary!['grand_total']);
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

  // A payment's currency is server-enforced from its linked contract (see
  // PaymentController::resolveCurrency(), plans/payment-currency-plan.md
  // ح3) — these mirror that logic here for display/pre-fill only in the
  // schedule/request sheets below. Uses ALL of the workspace's contracts
  // (not just payable ones), matching the backend's ambiguity check —
  // unlike [_contractCurrency] above, which only looks at payable contracts
  // for the summary card.
  List<String> get _allContractCurrencies {
    return _contracts
        .cast<Map<String, dynamic>?>()
        .map((c) => (c?['currency'] as String?) ?? 'SAR')
        .toSet()
        .toList();
  }

  bool get _hasSingleCurrency => _allContractCurrencies.length <= 1;

  String get _singleCurrency => _allContractCurrencies.isNotEmpty ? _allContractCurrencies.first : 'SAR';

  String _resolvedCurrencyFor(int? contractId) {
    if (contractId != null) {
      for (final c in _contracts) {
        if (c is Map && c['id'] == contractId) {
          final cur = c['currency'] as String?;
          if (cur != null) return cur;
        }
      }
    }
    return _singleCurrency;
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
    if (!_api.canReviewPayments) return;
    final displayAction = action;
    final l10n = AppLocalizations.of(context)!;
    String? reason;
    if (action == 'rejected') {
      reason = await showRejectReasonDialog(context);
      if (reason == null) return;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.paymentsApprovePayment),
          content: Text(l10n.paymentsApproveConfirmMsg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Lx.ok),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final data = await _paymentProvider.reviewPayment(id, displayAction, notes: reason);
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

  Widget _sumTile(String label, String value, {bool hl = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Lx.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.display(context, size: 16, color: hl ? Lx.ok : Lx.ink)),
          ),
        ]),
      ),
    );
  }

  Widget _summary(AppLocalizations l10n) {
    final grandTotal = _grandTotal;
    final cur = _contractCurrency;
    final remaining = (grandTotal - _totalPaid).clamp(0.0, double.infinity);
    final progress = grandTotal > 0 ? (_totalPaid / grandTotal).clamp(0.0, 1.0) : 0.0;
    final paidPct = (progress * 100).round();
    final isFullyPaid = _totalPaid >= grandTotal && grandTotal > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _sumTile(l10n.paymentsSummaryContracted, lxFormatMoney(grandTotal)),
        const SizedBox(width: 8),
        _sumTile(l10n.paymentsTotalPaid, lxFormatMoney(_totalPaid), hl: true),
        const SizedBox(width: 8),
        _sumTile(l10n.paymentsSummaryRemaining, lxFormatMoney(remaining)),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(isFullyPaid ? l10n.paymentsPaidInFull : '${l10n.paymentsTotalPaid} $paidPct% · $cur', style: Lx.text(context, size: 11.5, color: isFullyPaid ? Lx.ok : Lx.muted)),
        ]),
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Lx.line2, valueColor: const AlwaysStoppedAnimation(Lx.ok)),
      ),
      if (_taxSummary != null && _taxNum(_taxSummary!['tax_percentage']) > 0) ...[
        const SizedBox(height: 14),
        LuxeCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LuxeKind(l10n.paymentsTaxDetails),
            const SizedBox(height: 8),
            _taxRow(l10n.paymentsContractsValue, '${_taxNum(_taxSummary!['contracts_total']).toStringAsFixed(2)} $cur'),
            _taxRow(l10n.paymentsTaxRow(_taxNum(_taxSummary!['tax_percentage'])), '${_taxNum(_taxSummary!['tax_amount']).toStringAsFixed(2)} $cur'),
            const Divider(height: 14, color: Lx.line),
            _taxRow(l10n.paymentsTotalRow, '${_taxNum(_taxSummary!['grand_total']).toStringAsFixed(2)} $cur', bold: true),
          ]),
        ),
      ],
      const SizedBox(height: 16),
    ]);
  }

  Widget _taxRow(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a, style: Lx.text(context, size: 12, color: bold ? Lx.ink : Lx.muted, weight: bold ? FontWeight.w500 : FontWeight.w400)),
          Directionality(textDirection: TextDirection.ltr, child: Text(b, style: Lx.text(context, size: 12, weight: bold ? FontWeight.w500 : FontWeight.w400))),
        ]),
      );

  Widget _paymentCard(dynamic p, int i, AppLocalizations l10n) {
    final canReview = _api.canReviewPayments;
    final isPending = p['status'] == 'pending';
    final isApproved = p['status'] == 'approved';
    final isScheduled = p['status'] == 'scheduled';
    final isOverdue = p['status'] == 'overdue';
    final isRejected = p['status'] == 'rejected';
    final isManagerScheduled = p['requested_by_manager'] == true;
    final dot = isApproved ? LxStatus.ok : (isOverdue || isRejected) ? LxStatus.bad : (isPending || isScheduled) ? LxStatus.wait : LxStatus.off;
    final statusText = isApproved ? l10n.paymentsStatusApproved : isPending ? l10n.paymentsStatusPending : isOverdue ? l10n.paymentsStatusOverdue : isRejected ? l10n.paymentsStatusRejected : isScheduled ? l10n.paymentsStatusScheduled : p['status'] ?? '';
    final methodLabels = {'bank_transfer': l10n.paymentsMethodBankTransfer, 'swift': l10n.paymentsMethodSwift, 'corporate_account': l10n.paymentsMethodCorporateAccount, 'instapay': l10n.paymentsMethodInstapay, 'vodafone_cash': l10n.paymentsMethodVodafoneCash, 'mobile_wallet': l10n.paymentsMethodMobileWallet, 'cheque': l10n.paymentsMethodCheque};
    final method = (p['method_type'] as String?) ?? '';
    final created = _formatDate(p['created_at'] as String?);
    final amount = num.tryParse('${p['amount'] ?? 0}');
    final currency = p['currency'] as String? ?? 'SAR';
    final proofUrls = p['proof_file_url'] == null
        ? <String>[]
        : (p['proof_file_url'] is List ? (p['proof_file_url'] as List).cast<String>() : [p['proof_file_url'].toString()]);

    Widget note(String text, Color c) => Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.withAlpha(20), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withAlpha(50))),
          child: Text(text, style: Lx.text(context, size: 12, color: c == Lx.line2 ? Lx.muted : c)),
        );

    return LuxeCard(
      key: ValueKey('ws-payment-${p['id']}'),
      attention: isPending,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (method.isNotEmpty) LuxeKind(methodLabels[method] ?? method),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_installmentLabel(_payments.length - 1 - i, l10n), style: Lx.text(context, size: 16)),
        ),
        if (created.isNotEmpty) Text(created, style: Lx.text(context, size: 12.5, color: Lx.muted)),
        if (p['contract'] is Map && p['contract']['title'] != null)
          Text('${p['contract']['title']}', style: Lx.text(context, size: 12.5, color: Lx.muted)),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: amount != null ? lxFormatMoney(amount) : '${p['amount'] ?? 0}', style: Lx.display(context, size: 20)),
            TextSpan(text: ' $currency', style: Lx.text(context, size: 11, color: Lx.muted)),
          ])),
        ),
        if (p['due_date'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.paymentsDueDateFormat(_formatDate(p['due_date'])), style: Lx.text(context, size: 12, color: isOverdue ? Lx.danger : Lx.muted)),
          ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            LuxeStatusDot(status: dot),
            const SizedBox(width: 7),
            Text(statusText, style: Lx.text(context, size: 12, color: Lx.ink2)),
          ]),
          if (proofUrls.isNotEmpty)
            InkWell(
              onTap: () async {
                final resolved = _api.resolveFileUrl(proofUrls.first);
                final uri = Uri.tryParse(resolved);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paymentsFileOpenFailed)));
                }
              },
              child: Text(l10n.paymentsViewProof, style: Lx.text(context, size: 12, color: Lx.ink2).copyWith(decoration: TextDecoration.underline, decorationColor: Lx.line2)),
            ),
        ]),
        // payments-fixes-2-plan.md ت٢ — rejection_reason and notes are
        // different things; never fall back from one to the other.
        if (isRejected && (p['rejection_reason'] as String? ?? '').isNotEmpty)
          note('${l10n.paymentsRejectionReason}: ${p['rejection_reason']}', Lx.danger),
        if ((p['notes'] as String? ?? '').isNotEmpty)
          note('${l10n.paymentDetail_notes}: ${p['notes']}', Lx.line2),
        if (isPending && canReview) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: () => _review(p['id'], 'approved'), child: Text(l10n.approve))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => _review(p['id'], 'rejected'), style: OutlinedButton.styleFrom(foregroundColor: Lx.danger), child: Text(l10n.reject))),
          ]),
        ],
        if (isManagerScheduled && (isScheduled || isOverdue)) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showEditScheduleSheet(p),
                icon: const Icon(Icons.edit, size: 14),
                label: Text(l10n.edit),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _deleteSchedule(p['id']),
                icon: const Icon(Icons.delete, size: 14),
                label: Text(l10n.paymentsClear),
                style: OutlinedButton.styleFrom(foregroundColor: Lx.danger),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState(itemCount: 3);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final l10n = AppLocalizations.of(context)!;
    if (_payments.isEmpty) return EmptyState(icon: Icons.payment_outlined, title: l10n.paymentsEmpty);
    final isAM = _api.role == 'account_manager';

    return LuxeFormTheme(
      child: RefreshIndicator(
        onRefresh: _load,
        color: Lx.crimsonInk,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 28),
          children: [
            _summary(l10n),
            if (isAM) ...[
              SizedBox(
                width: double.infinity,
                child: LuxeButton(
                  key: const ValueKey('payments-request'),
                  label: l10n.paymentsRequestPayment,
                  lxIcon: 'plus',
                  kind: LuxeButtonKind.primary,
                  size: LuxeButtonSize.lg,
                  onPressed: _showRequestPaymentSheet,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: LuxeButton(
                  key: const ValueKey('payments-schedule'),
                  label: l10n.paymentsScheduleTitle,
                  kind: LuxeButtonKind.outline,
                  size: LuxeButtonSize.md,
                  onPressed: _showScheduleSheet,
                ),
              ),
              const SizedBox(height: 14),
            ],
            for (var i = 0; i < _payments.length; i++) _paymentCard(_payments[i], i, l10n),
          ],
        ),
      ),
    );
  }

  void _showScheduleSheet() {
    final installments = <Map<String, dynamic>>[];
    final amountCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    // Currency is no longer a free choice (plans/payment-currency-plan.md
    // ح3) — it's derived from the picked contract, or the workspace's
    // single shared currency when there's no ambiguity to resolve.
    int? selectedContractId;
    final hasSingleCurrency = _hasSingleCurrency;
    final singleCurrency = _singleCurrency;
    final contracts = _contracts;

    showModalBottomSheet(
      context: context,
      backgroundColor: Lx.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final sheetL10n = AppLocalizations.of(ctx)!;
          return Padding(
            padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
            // Wrapped in a scroll view: the currency block below now grows by
            // a dropdown + hint line for multi-currency workspaces
            // (plans/payment-currency-plan.md ح3), which pushed this sheet's
            // fixed-height Column past the available height on shorter
            // screens (and in tests) — was fine as a plain Column before
            // that extra content existed.
            child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(sheetL10n.paymentsScheduleTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Lx.ink)),
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
              if (hasSingleCurrency)
                InputDecorator(
                  decoration: InputDecoration(labelText: sheetL10n.paymentsCurrency),
                  child: Text(singleCurrency, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Lx.wait)),
                )
              else ...[
                DropdownButtonFormField<int>(
                  initialValue: selectedContractId,
                  decoration: InputDecoration(labelText: sheetL10n.paymentsCurrency),
                  hint: Text(sheetL10n.paymentsSelectContract, style: const TextStyle(fontSize: 13)),
                  items: contracts.map<DropdownMenuItem<int>>((c) {
                    final id = c['id'] as int;
                    final title = (c['title'] as String?) ?? '';
                    final cur = (c['currency'] as String?) ?? 'SAR';
                    return DropdownMenuItem(value: id, child: Text('$title ($cur)', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (v) => setSheetState(() => selectedContractId = v),
                ),
                const SizedBox(height: 4),
                Text(sheetL10n.paymentsMultiCurrencyContractHint, style: const TextStyle(fontSize: 11, color: Lx.muted)),
              ],
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
                  onPressed: (!hasSingleCurrency && selectedContractId == null) ? null : () {
                    final amount = double.tryParse(amountCtrl.text);
                    if (amount == null || amount <= 0) return;
                    setSheetState(() {
                      installments.add({
                        'amount': amount,
                        'currency': _resolvedCurrencyFor(selectedContractId),
                        if (selectedContractId != null) 'contract_id': selectedContractId,
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
                          icon: const Icon(Icons.delete, size: 18, color: Lx.danger),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Lx.crimson),
                  child: Text(sheetL10n.paymentsScheduleCount(installments.length), style: const TextStyle(color: Colors.white)),
                ),
              ),
            ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _schedulePayments(List<Map<String, dynamic>> installments) async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    try {
      await _paymentProvider.schedulePayments(wsId, installments);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.paymentsScheduledSuccess)])));
        _load();
      }
    } catch (e, s) {
      AppLog.error('payments_tab._schedulePayments', e, s);
      if (mounted) {
        final msg = e.toString().contains('ValidationException') ? '${AppLocalizations.of(context)!.paymentsInvalidData}: $e' : '${AppLocalizations.of(context)!.paymentsScheduleFailed}: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _updateSchedule(int paymentId, Map<String, dynamic> data) async {
    try {
      await _paymentProvider.updatePaymentSchedule(paymentId, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.paymentsInstallmentUpdated)])));
        _load();
      }
    } catch (e, s) {
      AppLog.error('payments_tab._updateSchedule', e, s);
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
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Lx.danger), child: Text(l10n.paymentsClear)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _paymentProvider.deletePaymentSchedule(paymentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.paymentsInstallmentCleared)])));
        _load();
      }
    } catch (e, s) {
      AppLog.error('payments_tab._deleteSchedule', e, s);
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
      backgroundColor: Lx.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.paymentsEditInstallmentTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Lx.ink)),
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
                style: ElevatedButton.styleFrom(backgroundColor: Lx.crimson),
                child: Text(l10n.saveChanges, style: const TextStyle(color: Colors.white)),
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
    // Currency is no longer a free choice (plans/payment-currency-plan.md
    // ح3) — it's derived from the picked contract, or the workspace's
    // single shared currency when there's no ambiguity to resolve.
    int? selectedContractId;
    final hasSingleCurrency = _hasSingleCurrency;
    final singleCurrency = _singleCurrency;
    final contracts = _contracts;

    showModalBottomSheet(
      context: context,
      backgroundColor: Lx.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
          // Scrollable for the same reason as _showScheduleSheet above: the
          // currency block can now grow by a dropdown + hint line.
          child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(l10n.paymentsRequestPayment, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Lx.ink)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 4),
            Text(l10n.paymentsRequestHint, style: const TextStyle(fontSize: 12, color: Lx.muted)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              decoration: InputDecoration(labelText: '${l10n.paymentsAmount} *', hintText: '0.00'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            if (hasSingleCurrency)
              InputDecorator(
                decoration: InputDecoration(labelText: l10n.paymentsCurrency),
                child: Text(singleCurrency, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Lx.wait)),
              )
            else ...[
              DropdownButtonFormField<int>(
                initialValue: selectedContractId,
                decoration: InputDecoration(labelText: l10n.paymentsCurrency),
                hint: Text(l10n.paymentsSelectContract, style: const TextStyle(fontSize: 13)),
                items: contracts.map<DropdownMenuItem<int>>((c) {
                  final id = c['id'] as int;
                  final title = (c['title'] as String?) ?? '';
                  final cur = (c['currency'] as String?) ?? 'SAR';
                  return DropdownMenuItem(value: id, child: Text('$title ($cur)', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) => setSheetState(() => selectedContractId = v),
              ),
              const SizedBox(height: 4),
              Text(l10n.paymentsMultiCurrencyContractHint, style: const TextStyle(fontSize: 11, color: Lx.muted)),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: l10n.paymentsNoteOptional, hintText: l10n.paymentsNoteHint),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (!hasSingleCurrency && selectedContractId == null) ? null : () async {
                  final amount = double.tryParse(amountCtrl.text);
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(ctx);
                  await _requestPayment(amount, _resolvedCurrencyFor(selectedContractId), noteCtrl.text, contractId: selectedContractId);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Lx.crimson),
                child: Text(l10n.paymentsSendRequest, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ]),
          ),
        ),
      ),
    );
  }

  Future<void> _requestPayment(double amount, String currency, String notes, {int? contractId}) async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    try {
      await _paymentProvider.requestPayment(wsId, amount, currency, notes: notes.isNotEmpty ? notes : null, contractId: contractId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.paymentsRequestSent)])));
        _load();
      }
    } catch (e, s) {
      AppLog.error('payments_tab._requestPayment', e, s);
      if (mounted) {
        final msg = e.toString().contains('ValidationException') ? '${AppLocalizations.of(context)!.paymentsInvalidData}: $e' : '${AppLocalizations.of(context)!.paymentsSendFailed}: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }
}
