import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/widgets/reject_reason_dialog.dart';
import '../../../core/luxe/lx_icons.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../providers/payment_provider.dart';

/// Finance screen for the super admin and the accountant (staff mockup `pFinance`): totals, search,
/// status chips and every payment across all workspaces. Same data as the web
/// dashboard's Finance page (`GET /all-payments`).
class FinancePage extends StatefulWidget {
  final PaymentProvider? paymentProvider;
  final ApiClient? api;
  // True when shown inside the accountant home (which has its own top bar).
  final bool embedded;
  const FinancePage({super.key, this.paymentProvider, this.api, this.embedded = false});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final PaymentProvider _provider = widget.paymentProvider ?? PaymentProvider();
  final _search = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _stats = {};
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;
  String _status = '';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _failed = false;
        _page = 1;
      });
    }
    try {
      final res = await _provider.fetchAllPayments(page: more ? _page + 1 : 1, search: _query, status: _status);
      final pag = res['payments'] is Map ? Map<String, dynamic>.from(res['payments'] as Map) : <String, dynamic>{};
      final rows = safeList(pag['data']).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _payments = more ? [..._payments, ...rows] : rows;
        _page = (pag['current_page'] as num?)?.toInt() ?? 1;
        _lastPage = (pag['last_page'] as num?)?.toInt() ?? 1;
        _stats = res['stats'] is Map ? Map<String, dynamic>.from(res['stats'] as Map) : {};
      });
    } catch (e, s) {
      AppLog.error('finance_page._load', e, s);
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _query = v.trim();
      _load();
    });
  }

  int? _reviewingId;

  /// Approves or rejects a pending payment (super admin / accountant only).
  /// Rejecting needs a reason of at least 5 characters.
  Future<void> _review(Map<String, dynamic> p, String action) async {
    if (!_api.canReviewPayments || _reviewingId != null) return;
    final l10n = AppLocalizations.of(context)!;
    final id = p['id'] as int;
    String? reason;
    if (action == 'rejected') {
      reason = await showRejectReasonDialog(context);
      if (reason == null || !mounted) return;
    } else {
      final ok = await showDialog<bool>(
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
      if (ok != true || !mounted) return;
    }
    setState(() => _reviewingId = id);
    try {
      await _provider.reviewPayment(id, action, notes: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'approved' ? l10n.paymentsApprovedWorkspacePending : l10n.paymentsRejectedMsg)));
      await _load();
    } catch (e, s) {
      AppLog.error('finance_page._review', e, s);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    }
    if (mounted) setState(() => _reviewingId = null);
  }

  Future<void> _openProof(String url) async {
    final uri = Uri.tryParse(_api.resolveFileUrl(url));
    final fail = AppLocalizations.of(context)!.payments_fileOpenFailed;
    final messenger = ScaffoldMessenger.of(context);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(fail)));
    }
  }

  num _n(dynamic v) => num.tryParse('${v ?? 0}') ?? 0;

  Widget _kpi(String label, String value, String unit, {bool act = false}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: Lx.cardGradient,
          borderRadius: BorderRadius.circular(Lx.rCard),
          border: Border.all(color: act ? const Color(0x59941414) : Lx.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 1.6)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: value, style: Lx.display(context, size: 26)),
                if (unit.isNotEmpty) TextSpan(text: ' $unit', style: Lx.text(context, size: 11, color: Lx.muted)),
              ])),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final byCur = _stats['approved_by_currency'] is Map ? Map<String, dynamic>.from(_stats['approved_by_currency'] as Map) : <String, dynamic>{};
    // Biggest approved currency first (the mockup shows a single total).
    String topCur = '';
    num topVal = 0;
    byCur.forEach((k, v) {
      if (_n(v) >= topVal) {
        topVal = _n(v);
        topCur = k;
      }
    });

    final chips = <(String, String)>[
      (l10n.payments_filterAll, ''),
      (l10n.payments_filterPending, 'pending'),
      (l10n.payments_filterAccepted, 'approved'),
      (l10n.payments_filterRejected, 'rejected'),
      (l10n.payments_filterScheduled, 'scheduled'),
    ];

    return Scaffold(
      backgroundColor: Lx.page,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Lx.page,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: const IconThemeData(color: Lx.muted),
              title: const SizedBox.shrink(),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: Lx.crimsonInk,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 28),
          children: [
            // Mockup pFinance: head('Money', 'Finance').
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.financeEyebrow.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.73)),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: l10n.financeTitle),
                    TextSpan(text: '.', style: Lx.display(context, size: 28).copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
                  ]),
                  key: const ValueKey('lx-page-title'),
                  style: Lx.display(context, size: 28).copyWith(height: 1.2),
                ),
              ]),
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text(l10n.financeFailed, style: Lx.text(context, size: 14, color: Lx.muted))),
              )
            else ...[
              IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _kpi(l10n.financeApprovedTotal, lxFormatMoney(topVal), topCur)),
                const SizedBox(width: 10),
                Expanded(child: _kpi(l10n.financePendingCount, '${_n(_stats['pending_count']).toInt()}', '', act: true)),
              ])),
              const SizedBox(height: 10),
              IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _kpi(l10n.financeApprovedCount, '${_n(_stats['approved_count']).toInt()}', '')),
                const SizedBox(width: 10),
                Expanded(child: _kpi(l10n.financeAllCount, '${_n(_stats['total_count']).toInt()}', '')),
              ])),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line)),
                child: Row(children: [
                  const LxIcon('search', size: 18, color: Lx.faint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('finance-search'),
                      controller: _search,
                      onChanged: _onSearch,
                      style: Lx.text(context, size: 12.5),
                      cursorColor: Lx.crimsonInk,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        hintText: l10n.financeSearchHint,
                        hintStyle: Lx.text(context, size: 12.5, color: Lx.faint),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (label, value) in chips)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: GestureDetector(
                        key: ValueKey('finance-chip-${value.isEmpty ? 'all' : value}'),
                        onTap: () {
                          if (_status == value) return;
                          _status = value;
                          _load();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _status == value ? const Color(0xFFF0F0F0) : null,
                            borderRadius: BorderRadius.circular(Lx.rPill),
                            border: Border.all(color: _status == value ? const Color(0xFFF0F0F0) : Lx.line2),
                          ),
                          child: Text(label, style: Lx.text(context, size: 12, color: _status == value ? const Color(0xFF111111) : Lx.muted)),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: Lx.crimsonInk)))
              else if (_payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text(l10n.payments_empty, style: Lx.text(context, size: 14, color: Lx.muted))),
                )
              else ...[
                ..._payments.map(_card),
                if (_page < _lastPage)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: LuxeButton(
                        key: const ValueKey('finance-load-more'),
                        label: l10n.financeLoadMore,
                        onPressed: _loadingMore ? () {} : () => _load(more: true),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final l10n = AppLocalizations.of(context)!;
    final status = '${p['status'] ?? ''}';
    final ws = p['workspace'] is Map ? Map<String, dynamic>.from(p['workspace'] as Map) : <String, dynamic>{};
    final client = ws['client'] is Map ? Map<String, dynamic>.from(ws['client'] as Map) : <String, dynamic>{};
    final manager = ws['manager'] is Map ? Map<String, dynamic>.from(ws['manager'] as Map) : <String, dynamic>{};
    final clientName = '${client['company_name'] ?? client['contact_person'] ?? '—'}';
    final methods = <String, String>{
      'bank_transfer': l10n.payments_methodBankTransfer,
      'swift': l10n.payments_methodSwift,
      'corporate_account': l10n.payments_methodCorporateAccount,
      'instapay': l10n.payments_methodInstapay,
      'vodafone_cash': l10n.payments_methodVodafoneCash,
      'mobile_wallet': l10n.payments_methodMobileWallet,
      'cheque': l10n.payments_methodCheque,
    };
    final method = methods['${p['method_type']}'] ?? '${p['method_type'] ?? ''}';
    // Mockup card sub: "manager · 16 Oct".
    final created = DateTime.tryParse('${p['created_at'] ?? ''}')?.toLocal();
    final date = created == null ? '' : DateFormat('d MMM', Localizations.localeOf(context).toString()).format(created);
    final sub = [if ('${manager['name'] ?? ''}'.isNotEmpty) '${manager['name']}', if (date.isNotEmpty) date].join(' · ');
    final dot = status == 'approved'
        ? LxStatus.ok
        : (status == 'rejected' || status == 'overdue')
            ? LxStatus.bad
            : LxStatus.wait;
    final label = status == 'approved'
        ? l10n.payments_statusApproved
        : status == 'pending'
            ? l10n.payments_statusPending
            : status == 'rejected'
                ? l10n.payments_statusRejected
                : status == 'scheduled'
                    ? l10n.payments_statusScheduled
                    : status == 'overdue'
                        ? l10n.payments_statusOverdue
                        : status;
    final urls = p['proof_file_url'] == null
        ? <String>[]
        : (p['proof_file_url'] is List ? (p['proof_file_url'] as List).map((e) => '$e').toList() : ['${p['proof_file_url']}']);

    return LuxeCard(
      key: ValueKey('finance-card-${p['id']}'),
      attention: status == 'pending',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LuxeKind('#${p['id']}${method.isNotEmpty ? ' · $method' : ''}'),
        const SizedBox(height: 4),
        Text(clientName, style: Lx.text(context, size: 16)),
        if (sub.isNotEmpty) Text(sub, style: Lx.text(context, size: 12.5, color: Lx.muted)),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: lxFormatMoney(_n(p['amount'])), style: Lx.display(context, size: 20)),
            TextSpan(text: ' ${p['currency'] ?? 'SAR'}', style: Lx.text(context, size: 11, color: Lx.muted)),
          ])),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            LuxeStatusDot(status: dot),
            const SizedBox(width: 7),
            Text(label, style: Lx.text(context, size: 12, color: Lx.ink2)),
          ]),
          if (urls.isNotEmpty)
            InkWell(
              key: ValueKey('finance-proof-${p['id']}'),
              onTap: () => _openProof(urls.first),
              child: Container(
                padding: const EdgeInsets.only(bottom: 1),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                child: Text(l10n.payments_viewProof, style: Lx.text(context, size: 12.5, color: Lx.ink2)),
              ),
            ),
        ]),
        if (status == 'pending' && _api.canReviewPayments) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                key: ValueKey('finance-approve-${p['id']}'),
                onPressed: _reviewingId == null ? () => _review(p, 'approved') : null,
                child: Text(l10n.approve),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: ValueKey('finance-reject-${p['id']}'),
                onPressed: _reviewingId == null ? () => _review(p, 'rejected') : null,
                style: OutlinedButton.styleFrom(foregroundColor: Lx.danger),
                child: Text(l10n.reject),
              ),
            ),
          ]),
        ],
        if (p['workspace_id'] != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: ValueKey('finance-open-${p['id']}'),
              // Payments tab (3) of the client's workspace; contracts are tab 2.
              onPressed: () => context.push('/am/workspace/${p['workspace_id']}?tab=3'),
              child: Text(clientName, overflow: TextOverflow.ellipsis),
            ),
          ),
      ]),
    );
  }
}
