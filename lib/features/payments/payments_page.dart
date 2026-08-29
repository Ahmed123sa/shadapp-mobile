import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/payment_detail_sheet.dart';
import '../../providers/contract_provider.dart';
import '../../providers/payment_provider.dart';
import 'payments_page_sheets.dart';

class PaymentsPage extends StatefulWidget {
  final ApiClient? api;
  final PaymentProvider? paymentProvider;
  final ContractProvider? contractProvider;
  const PaymentsPage({super.key, this.api, this.paymentProvider, this.contractProvider});

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
    _load();
    _startRefresh();
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
    if (mounted) setState(() => _loading = false);
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

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showRequestPaymentSheet,
        backgroundColor: ShadColors.crimson,
        child: const Icon(Icons.add, color: ShadColors.textOnCrimson),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 80),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ShadColors.surfaceDarker,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Column(children: [
                if (isFullyPaid) ...[
                  const Icon(Icons.check_circle, size: 32, color: ShadColors.success),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.payments_paidInFull, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ShadColors.success, fontFamily: 'NotoSansArabic')),
                  const SizedBox(height: 4),
                  Text('${_totalPaid.toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                ] else ...[
                  Text(AppLocalizations.of(context)!.payments_totalPaid, style: TextStyle(fontSize: 12, color: ShadColors.gold, fontFamily: 'NotoSansArabic')),
                  const SizedBox(height: 8),
                  Text('${_totalPaid.toStringAsFixed(2)} $contractCur', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
                  const SizedBox(height: 4),
                  Text(AppLocalizations.of(context)!.payments_remainingSummary(contractCur, (grandTotal - _totalPaid).toStringAsFixed(2), grandTotal.toStringAsFixed(2)),
                    style: TextStyle(fontSize: 11, color: ShadColors.textDisabled, fontFamily: 'NotoSansArabic')),
                  if (_taxSummary != null && (_taxSummary!['tax_percentage'] ?? 0) > 0) ...[
                    const SizedBox(height: 4),
                    Text(AppLocalizations.of(context)!.payments_taxSummary(_taxSummary!['tax_amount'] ?? 0, contractCur, _taxSummary!['tax_percentage'], _taxSummary!['contracts_total'] ?? 0),
                      style: TextStyle(fontSize: 10, color: ShadColors.textDisabled, fontFamily: 'NotoSansArabic')),
                  ],
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: ShadColors.cardBorder,
                    valueColor: AlwaysStoppedAnimation(isFullyPaid ? ShadColors.success : ShadColors.gold),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            Row(children: [
              _filterChip(AppLocalizations.of(context)!.payments_filterAll, 'all'),
              const SizedBox(width: 8),
              _filterChip(AppLocalizations.of(context)!.payments_filterAccepted, 'approved'),
              const SizedBox(width: 8),
              _filterChip(AppLocalizations.of(context)!.payments_filterPending, 'pending'),
              const SizedBox(width: 8),
              _filterChip(AppLocalizations.of(context)!.payments_filterRejected, 'rejected'),
              const SizedBox(width: 8),
              _filterChip(AppLocalizations.of(context)!.payments_filterScheduled, 'scheduled'),
            ]),
            const SizedBox(height: 12),

            if (_scheduledPayments.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 14, color: ShadColors.gold),
                  const SizedBox(width: 6),
                  Text(AppLocalizations.of(context)!.payments_upcomingPayments, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.gold, fontFamily: 'NotoSansArabic')),
                ]),
              ),
              ..._scheduledPayments.map((p) => _scheduledPaymentCard(p)),
              const SizedBox(height: 12),
            ],

            if (_filteredPayments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(children: [
                  const Icon(Icons.payment_outlined, size: 48, color: ShadColors.textDisabled),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.payments_empty, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ShadColors.textSecondary, fontFamily: 'NotoSansArabic')),
                ]),
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
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? ShadColors.crimson : ShadColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? ShadColors.crimson : ShadColors.cardBorder),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? ShadColors.textOnCrimson : ShadColors.textSecondary)),
      ),
    );
  }

  void _showRequestPaymentSheet() => showRequestPaymentSheet(
    pageContext: context,
    getAvailableMethods: () => _availableMethods,
    getGrandTotal: () => _grandTotal,
    getPayments: () => _payments,
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
    final statusColor = isApproved ? ShadColors.success : isPending ? ShadColors.gold : isRequested ? ShadColors.gold : isScheduled ? ShadColors.gold : isOverdue ? ShadColors.error : isRejected ? ShadColors.error : ShadColors.textDisabled;
    final l10n = AppLocalizations.of(context)!;
    final statusText = isApproved ? l10n.payments_statusApproved : isPending ? l10n.payments_statusPending : isRequested ? l10n.payments_statusRequested : isScheduled ? l10n.payments_statusScheduled : isOverdue ? l10n.payments_statusOverdue : isRejected ? l10n.payments_statusRejected : p['status'] ?? '';

    final methodLabels = <String, String>{
      'bank_transfer': l10n.payments_methodBankTransfer,
      'swift': l10n.payments_methodSwift,
      'corporate_account': l10n.payments_methodCorporateAccount,
      'instapay': l10n.payments_methodInstapay,
      'vodafone_cash': l10n.payments_methodVodafoneCash,
      'mobile_wallet': l10n.payments_methodMobileWallet,
    };

    return InkWell(
      onTap: () => _showPaymentDetail(p),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isPending ? ShadColors.gold : ShadColors.cardBorder, width: isPending ? 1.5 : 0.5),
        ),
        child: Column(children: [
          // ── Top section: installment number + amount + status ──
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12),
            child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _formatDate(p['created_at'] as String?).isNotEmpty
                      ? '${_installmentLabel(index)}  •  ${_formatDate(p['created_at'] as String?)}'
                      : _installmentLabel(index),
                  style: TextStyle(fontSize: 11, color: ShadColors.gold, fontWeight: FontWeight.w600, fontFamily: 'NotoSansArabic'),
                ),
                const SizedBox(height: 4),
                Text('${p['amount'] ?? 0} ${_currency(p)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
                const SizedBox(height: 4),
                Row(children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(statusText, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500, fontFamily: 'NotoSansArabic')),
                ]),
                if (p['due_date'] != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.calendar_today, size: 11, color: isOverdue ? ShadColors.error : ShadColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context)!.payments_dueDateFormat(_formatDate(p['due_date'])),
                      style: TextStyle(fontSize: 11, color: isOverdue ? ShadColors.error : ShadColors.textSecondary, fontFamily: 'NotoSansArabic')),
                  ]),
                ],
              ]),
            ),
          ]),
        ),

        // ── Divider ──
        Divider(height: 1, color: ShadColors.cardBorder),

        // ── Bottom section: payment method + contract + proof ──
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((p['method_type'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Text('💳 ', style: TextStyle(fontSize: 12, fontFamily: 'NotoSansArabic')),
                  Text(methodLabels[p['method_type']] ?? p['method_type'] ?? '', style: TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'NotoSansArabic')),
                ]),
              ),
            if (p['contract'] is Map && p['contract']['title'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Text('📄 ', style: TextStyle(fontSize: 12, fontFamily: 'NotoSansArabic')),
                  Text(p['contract']['title'], style: TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'NotoSansArabic')),
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
                      final messenger = ScaffoldMessenger.of(context);
                      final failedMsg = AppLocalizations.of(context)!.payments_fileOpenFailed;
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        messenger.showSnackBar(SnackBar(content: Text(failedMsg)));
                      }
                    },
                    child: Row(children: [
                      Text('📎 ', style: TextStyle(fontSize: 12, fontFamily: 'NotoSansArabic')),
                      Text(AppLocalizations.of(context)!.payments_viewProof, style: TextStyle(fontSize: 12, color: ShadColors.gold, fontFamily: 'NotoSansArabic')),
                    ]),
                  ),
                ));
              })(),
          ]),
        ),
      ]),
    ),
    );
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
        showPayButton: isScheduled,
        onPay: isScheduled
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
    final borderColor = isOverdue ? ShadColors.error : ShadColors.gold;
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: () => _showPaymentDetail(p),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ShadColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(children: [
          Icon(
            isOverdue ? Icons.warning_amber : Icons.schedule,
            size: 20,
            color: isOverdue ? ShadColors.error : ShadColors.gold,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['installment_label'] ?? l10n.payments_scheduledPayment,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShadColors.textPrimary, fontFamily: 'NotoSansArabic')),
            const SizedBox(height: 2),
            Row(children: [
              Text('${p['amount'] ?? 0} ${p['currency'] ?? 'SAR'}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
              const SizedBox(width: 8),
              if (p['due_date'] != null)
                Text(_formatDate(p['due_date']),
                  style: TextStyle(fontSize: 11, color: isOverdue ? ShadColors.error : ShadColors.textSecondary, fontFamily: 'NotoSansArabic')),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isOverdue ? ShadColors.error : ShadColors.gold).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(isOverdue ? l10n.payments_overdueLabel : l10n.payments_scheduledLabel,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isOverdue ? ShadColors.error : ShadColors.gold)),
          ),
        ]),
      ),
    );
  }
}
