import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/theme.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/payment_detail_sheet.dart';
import '../../providers/contract_provider.dart';
import '../../providers/payment_provider.dart';
import 'payments_page_sheets.dart';

class PaymentsPage extends StatefulWidget {
  final int? initialPaymentId;
  final VoidCallback? onTargetPaymentHandled;
  final ApiClient? api;
  final PaymentProvider? paymentProvider;
  final ContractProvider? contractProvider;
  const PaymentsPage({
    super.key,
    this.initialPaymentId,
    this.onTargetPaymentHandled,
    this.api,
    this.paymentProvider,
    this.contractProvider,
  });

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final PaymentProvider _paymentProvider = widget.paymentProvider ?? PaymentProvider();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider();
  List<dynamic> _payments = [];
  List<dynamic> _contracts = [];
  List<String> _availableMethods = [];
  Map<String, dynamic>? _taxSummary;
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  Timer? _refreshTimer;

  String _currency(dynamic p) => p['currency'] as String? ?? 'SAR';

  @override
  void initState() {
    super.initState();
    // payments-fixes-2-plan.md ت١ — the target payment used to be opened
    // from inside _load() itself, which _startRefresh() below also calls
    // every 30s. Combined with onTargetPaymentHandled never actually
    // triggering a rebuild with initialPaymentId: null (see
    // client_dashboard_screen.dart), that reopened the sheet indefinitely.
    // Opening it once here, after the first load, keeps that responsibility
    // out of _load() entirely.
    _load().then((_) {
      final id = widget.initialPaymentId;
      if (mounted && id != null) _openTargetPayment(id);
    });
    _startRefresh();
  }

  @override
  void didUpdateWidget(PaymentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPaymentId != null && widget.initialPaymentId != oldWidget.initialPaymentId) {
      _openTargetPayment(widget.initialPaymentId!);
    }
  }

  // Opens the target payment's sheet if it's already loaded; otherwise
  // reloads once and retries. Either way, onTargetPaymentHandled always
  // fires so a payment that's genuinely gone (deleted, wrong id) can never
  // leave a stale id behind for a later refresh to pick up again.
  Future<void> _openTargetPayment(int paymentId) async {
    dynamic target = _payments.firstWhere(
      (p) => p is Map && p['id'] == paymentId,
      orElse: () => null,
    );
    if (target == null) {
      await _load();
      if (!mounted) return;
      target = _payments.firstWhere(
        (p) => p is Map && p['id'] == paymentId,
        orElse: () => null,
      );
    }
    // Deferred to after this frame: onTargetPaymentHandled may run a
    // setState() on an ancestor (see client_dashboard_screen.dart), and
    // this method can be reached synchronously from didUpdateWidget while
    // the tree is still mid-build. Calling it there directly can hit a
    // "setState()/markNeedsBuild() called during build" reentrancy error.
    final resolvedTarget = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onTargetPaymentHandled?.call();
      if (resolvedTarget != null) _submitScheduledPayment(resolvedTarget);
    });
  }

  void _startRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  double get _totalPaid {
    return _payments
        .where((p) => p['status'] == 'approved')
        .fold<double>(0, (sum, p) => sum + (num.tryParse(p['amount']?.toString() ?? '')?.toDouble() ?? 0));
  }

  String get _contractCurrency {
    final contracts = _payableContracts;
    if (contracts.isEmpty) return 'SAR';
    final currencies = contracts.map((c) => (c['currency'] as String?) ?? 'SAR').toSet();
    if (currencies.length == 1) return currencies.first;
    return (contracts.first['currency'] as String?) ?? 'SAR';
  }

  double get _grandTotal {
    if (_taxSummary != null && _taxSummary!['grand_total'] != null) {
      return num.tryParse(_taxSummary!['grand_total'].toString())?.toDouble() ?? 0;
    }
    final contracts = _payableContracts;
    if (contracts.isNotEmpty) {
      return contracts.fold<double>(0, (sum, c) => sum + (num.tryParse(c['value']?.toString() ?? '')?.toDouble() ?? 0));
    }
    return _payments.fold<double>(0, (s, p) => s + (num.tryParse(p['amount']?.toString() ?? '')?.toDouble() ?? 0));
  }

  String _ordinalLabel(int index) {
    final l10n = AppLocalizations.of(context)!;
    switch (index) {
      case 0: return l10n.payments_ordinalFirst;
      case 1: return l10n.payments_ordinalSecond;
      case 2: return l10n.payments_ordinalThird;
      case 3: return l10n.payments_ordinalFourth;
      case 4: return l10n.payments_ordinalFifth;
      case 5: return l10n.payments_ordinalSixth;
      case 6: return l10n.payments_ordinalSeventh;
      case 7: return l10n.payments_ordinalEighth;
      case 8: return l10n.payments_ordinalNinth;
      case 9: return l10n.payments_ordinalTenth;
      default: return '${index + 1}';
    }
  }

  String _installmentLabel(int index) {
    final l10n = AppLocalizations.of(context)!;
    if (index < 10) {
      return l10n.payments_installmentFormat(_ordinalLabel(index));
    }
    return l10n.payments_installmentFormatNumbered(index + 1);
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

  Future<void> _load() async {
    final wsId = _api.workspaceId;
    if (wsId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final paymentsData = await _paymentProvider.fetchWorkspaceEnvelope(wsId);
      _payments = safeList(paymentsData['payments']);
      _availableMethods = (paymentsData['available_methods'] as List<dynamic>?)?.cast<String>() ?? [];
      _taxSummary = paymentsData['tax_summary'] as Map<String, dynamic>?;
      try {
        _contracts = await _contractProvider.fetchWorkspaceContractsRaw(wsId);
      } catch (_) {
        _contracts = [];
      }
    } catch (_) {
      if (mounted) _error = AppLocalizations.of(context)!.payments_failedToLoad;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _payableContracts {
    return _contracts.cast<Map<String, dynamic>?>().where(
      (c) => c?['status'] == 'company_approved' || c?['status'] == 'completed',
    ).whereType<Map<String, dynamic>>().toList();
  }

  List<dynamic> get _filteredPayments {
    if (_filter == 'all') return _payments;
    return _payments.where((p) => p['status'] == _filter).toList();
  }

  List<dynamic> get _scheduledPayments {
    return _payments.where((p) => p['requested_by_manager'] == true && (p['status'] == 'scheduled' || p['status'] == 'overdue')).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final grandTotal = _grandTotal;
    final contractCur = _contractCurrency;
    final progress = grandTotal > 0 ? (_totalPaid / grandTotal).clamp(0.0, 1.0) : 0.0;
    final isFullyPaid = _totalPaid >= grandTotal && grandTotal > 0;

    final l10n = AppLocalizations.of(context)!;
    final paid = _totalPaid;
    final remaining = (grandTotal - paid).clamp(0, double.infinity).toDouble();
    final pctPaid = (progress * 100).round();

    Widget tile(String label, num value, {bool highlight = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Lx.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 1.4)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: lxFormatMoney(value), style: Lx.display(context, size: 16, color: highlight ? Lx.ok : Lx.ink)),
                    TextSpan(text: ' $contractCur', style: Lx.text(context, size: 9.5, color: Lx.muted)),
                  ])),
                ),
              ),
            ]),
          ),
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      // subuser-review-plan.md م٦ — uploading/re-uploading a payment proof
      // maps to can_upload_payment_proof, per the plan's action table.
      floatingActionButton: _api.canDo('can_upload_payment_proof')
          ? FloatingActionButton(
              key: const ValueKey('payments-request'),
              onPressed: _showRequestPaymentSheet,
              backgroundColor: Lx.crimson,
              elevation: 0,
              shape: const CircleBorder(),
              child: const LxIcon('plus', size: 20, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 80),
          children: [
            LuxePageTitle(l10n.dashboard_tab_payments),
            Row(key: const ValueKey('payments-summary'), children: [
              tile(l10n.onboarding_total, grandTotal),
              const SizedBox(width: 8),
              tile(l10n.onboarding_paidAmount, paid, highlight: true),
              const SizedBox(width: 8),
              tile(l10n.onboarding_remainingAmount2, remaining),
            ]),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: '${l10n.onboarding_paidAmount} ', style: Lx.text(context, size: 11.5, color: Lx.muted)),
                TextSpan(text: '$pctPaid%', style: Lx.text(context, size: 11.5, weight: FontWeight.w500)),
              ])),
              Text.rich(TextSpan(children: [
                TextSpan(text: '${l10n.onboarding_remainingAmount2} ', style: Lx.text(context, size: 11.5, color: Lx.muted)),
                TextSpan(text: '${100 - pctPaid}%', style: Lx.text(context, size: 11.5, weight: FontWeight.w500)),
              ])),
            ]),
            const SizedBox(height: 8),
            LuxeProgressSplit(fraction: progress),
            if (isFullyPaid)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(key: const ValueKey('payments-paid-in-full'), children: [
                  const LuxeStatusDot(status: LxStatus.ok),
                  const SizedBox(width: 7),
                  Text(l10n.payments_paidInFull, style: Lx.text(context, size: 12, color: Lx.ok)),
                ]),
              )
            else if (_taxSummary != null && (_taxSummary!['tax_percentage'] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.payments_taxSummary(_taxSummary!['tax_amount'] ?? 0, contractCur, _taxSummary!['tax_percentage'], _taxSummary!['contracts_total'] ?? 0),
                  style: Lx.text(context, size: 10, color: Lx.muted),
                ),
              ),
            const SizedBox(height: 16),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip(l10n.payments_filterAll, 'all'),
                const SizedBox(width: 8),
                _filterChip(l10n.payments_filterAccepted, 'approved'),
                const SizedBox(width: 8),
                _filterChip(l10n.payments_filterPending, 'pending'),
                const SizedBox(width: 8),
                _filterChip(l10n.payments_filterRejected, 'rejected'),
                const SizedBox(width: 8),
                _filterChip(l10n.payments_filterScheduled, 'scheduled'),
              ]),
            ),
            const SizedBox(height: 14),

            if (_scheduledPayments.isNotEmpty) ...[
              LuxeKind(l10n.payments_upcomingPayments),
              const SizedBox(height: 8),
              ..._scheduledPayments.map((p) => _scheduledPaymentCard(p)),
              const SizedBox(height: 4),
            ],

            if (_filteredPayments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text(l10n.payments_empty, style: Lx.text(context, size: 14, color: Lx.muted))),
              )
            else
              ..._filteredPayments.asMap().entries.map((entry) => _paymentCard(entry.value, _filteredPayments.length - 1 - entry.key, _filteredPayments.length)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return InkWell(
      key: ValueKey('payments-filter-$value'),
      borderRadius: BorderRadius.circular(Lx.rPill),
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0x33941414) : null,
          borderRadius: BorderRadius.circular(Lx.rPill),
          border: Border.all(color: selected ? const Color(0x80941414) : Lx.line2),
        ),
        child: Text(label, style: Lx.text(context, size: 12, color: selected ? Lx.ink : Lx.ink2)),
      ),
    );
  }

  void _showRequestPaymentSheet() => showRequestPaymentSheet(
    pageContext: context,
    getAvailableMethods: () => _availableMethods,
    getGrandTotal: () => _grandTotal,
    getPayments: () => _payments,
    getPayableContracts: () => _payableContracts,
    getContractCurrency: () => _contractCurrency,
    paymentProvider: _paymentProvider,
    api: _api,
    load: _load,
  );

  Widget _paymentCard(dynamic p, int index, [int? total]) {
    final isPending = p['status'] == 'pending';
    final isApproved = p['status'] == 'approved';
    final isScheduled = p['status'] == 'scheduled';
    final isOverdue = p['status'] == 'overdue';
    final isRequested = p['requested_by_manager'] == true && p['due_date'] == null;
    final isRejected = p['status'] == 'rejected';
    final status = isApproved ? LxStatus.ok : (isOverdue || isRejected) ? LxStatus.bad : (isPending || isRequested || isScheduled) ? LxStatus.wait : LxStatus.off;
    final l10n = AppLocalizations.of(context)!;
    final statusText = isApproved ? l10n.payments_statusApproved : isPending ? l10n.payments_statusPending : isRequested ? l10n.payments_statusRequested : isScheduled ? l10n.payments_statusScheduled : isOverdue ? l10n.payments_statusOverdue : isRejected ? l10n.payments_statusRejected : p['status'] ?? '';

    final methodLabels = <String, String>{
      'bank_transfer': l10n.payments_methodBankTransfer,
      'swift': l10n.payments_methodSwift,
      'corporate_account': l10n.payments_methodCorporateAccount,
      'instapay': l10n.payments_methodInstapay,
      'vodafone_cash': l10n.payments_methodVodafoneCash,
      'mobile_wallet': l10n.payments_methodMobileWallet,
      'cheque': l10n.payments_methodCheque,
    };
    final method = methodLabels[p['method_type']] ?? (p['method_type'] ?? '').toString();
    final contractTitle = (p['contract'] is Map && p['contract']['title'] != null) ? p['contract']['title'].toString() : '';
    final kind = [if (method.isNotEmpty) method, if (contractTitle.isNotEmpty) contractTitle].join(' · ');
    final date = _formatDate(p['created_at'] as String?);
    final amount = num.tryParse('${p['amount'] ?? 0}');
    final urls = p['proof_file_url'] == null
        ? <String>[]
        : (p['proof_file_url'] is List ? (p['proof_file_url'] as List).cast<String>() : [p['proof_file_url'].toString()]);

    return LuxeCard(
      key: ValueKey('payment-card-${p['id']}'),
      attention: isPending,
      onTap: () => _showPaymentDetail(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (kind.isNotEmpty) LuxeKind(kind),
        const SizedBox(height: 4),
        Text(_installmentLabel(index), style: Lx.text(context, size: 16)),
        if (date.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(date, style: Lx.text(context, size: 12.5, color: Lx.muted)),
        ],
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: amount != null ? lxFormatMoney(amount) : '${p['amount'] ?? 0}', style: Lx.display(context, size: 20)),
            TextSpan(text: ' ${_currency(p)}', style: Lx.text(context, size: 11, color: Lx.muted)),
          ])),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            LuxeStatusDot(status: status),
            const SizedBox(width: 7),
            Text(statusText, style: Lx.text(context, size: 12, color: Lx.ink2)),
          ]),
          if (urls.isNotEmpty)
            InkWell(
              key: ValueKey('payment-receipt-${p['id']}'),
              onTap: () => _openProof(urls.first),
              child: Container(
                padding: const EdgeInsets.only(bottom: 1),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                child: Text(l10n.payments_viewProof, style: Lx.text(context, size: 12.5, color: Lx.ink2)),
              ),
            ),
        ]),
        if (p['due_date'] != null) ...[
          const SizedBox(height: 6),
          Text(l10n.payments_dueDateFormat(_formatDate(p['due_date'])), style: Lx.text(context, size: 11.5, color: isOverdue ? Lx.crimsonInk : Lx.muted)),
        ],
        // payments-fixes-2-plan.md ت٢ — rejection_reason (why the manager
        // rejected it) and notes (the manager's own note from when they
        // requested it) are different things; falling back to notes whenever
        // rejection_reason was empty mislabeled that note as a rejection reason.
        if (isRejected && (p['rejection_reason'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ShadColors.crimson.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ShadColors.crimson.withAlpha(50)),
            ),
            child: Text('${l10n.paymentsRejectionReason}: ${p['rejection_reason']}', style: Lx.text(context, size: 11.5, color: Lx.danger)),
          ),
        ],
        if ((p['notes'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('${l10n.paymentDetail_notes}: ${p['notes']}', style: Lx.text(context, size: 11.5, color: Lx.muted)),
        ],
        if (isRejected && _api.canDo('can_upload_payment_proof')) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: LuxeButton(
              key: ValueKey('payment-reupload-${p['id']}'),
              label: l10n.paymentsReuploadProof,
              lxIcon: 'up',
              size: LuxeButtonSize.sm,
              onPressed: () => _submitScheduledPayment(p),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _openProof(String url) async {
    final uri = Uri.tryParse(_api.resolveFileUrl(url));
    final messenger = ScaffoldMessenger.of(context);
    final failedMsg = AppLocalizations.of(context)!.payments_fileOpenFailed;
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(failedMsg)));
    }
  }

  void _showPaymentDetail(dynamic p) {
    final status = p['status']?.toString() ?? '';
    final isScheduled = status == 'scheduled' || status == 'overdue';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PaymentDetailSheet(
        payment: p is Map<String, dynamic> ? p : Map<String, dynamic>.from(p as Map),
        // subuser-review-plan.md م٦ — paying/uploading proof for a scheduled
        // payment maps to can_upload_payment_proof, per the plan's action
        // table.
        showPayButton: isScheduled && _api.canDo('can_upload_payment_proof'),
        onPay: isScheduled && _api.canDo('can_upload_payment_proof')
            ? () {
                Navigator.pop(context);
                _submitScheduledPayment(p);
              }
            : null,
      ),
    );
  }

  void _submitScheduledPayment(dynamic p) => showScheduledPaymentSheet(
    pageContext: context,
    payment: p,
    getAvailableMethods: () => _availableMethods,
    paymentProvider: _paymentProvider,
    api: _api,
    load: _load,
  );

  Widget _scheduledPaymentCard(dynamic p) {
    final isOverdue = p['status'] == 'overdue';
    final l10n = AppLocalizations.of(context)!;
    final amount = num.tryParse('${p['amount'] ?? 0}');
    final canPay = _api.canDo('can_upload_payment_proof');
    final contractTitle = (p['contract'] is Map && p['contract']['title'] != null) ? ' · ${p['contract']['title']}' : '';

    return LuxeCard(
      key: ValueKey('payment-scheduled-${p['id']}'),
      attention: true,
      onTap: () => _showPaymentDetail(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LuxeKind('${l10n.payments_installmentLabel}$contractTitle'),
        const SizedBox(height: 4),
        Text(p['installment_label'] ?? l10n.payments_scheduledPayment, style: Lx.text(context, size: 16)),
        if (p['due_date'] != null) ...[
          const SizedBox(height: 2),
          Text(l10n.payments_dueDateFormat(_formatDate(p['due_date'])), style: Lx.text(context, size: 12.5, color: isOverdue ? Lx.crimsonInk : Lx.muted)),
        ],
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: amount != null ? lxFormatMoney(amount) : '${p['amount'] ?? 0}', style: Lx.display(context, size: 20)),
            TextSpan(text: ' ${p['currency'] ?? 'SAR'}', style: Lx.text(context, size: 11, color: Lx.muted)),
          ])),
        ),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          LuxeStatusDot(status: isOverdue ? LxStatus.bad : LxStatus.wait),
          const SizedBox(width: 7),
          Text(isOverdue ? l10n.payments_overdueLabel : l10n.payments_scheduledLabel, style: Lx.text(context, size: 12, color: Lx.ink2)),
        ]),
        if (canPay) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: LuxeButton(
              key: ValueKey('payment-upload-proof-${p['id']}'),
              label: l10n.payments_attachProof,
              lxIcon: 'up',
              kind: LuxeButtonKind.primary,
              onPressed: () => _submitScheduledPayment(p),
            ),
          ),
        ],
      ]),
    );
  }
}
