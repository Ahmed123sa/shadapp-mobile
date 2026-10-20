import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../luxe/tokens.dart';
import '../theme.dart';
import '../api_client.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'luxe/luxe_widgets.dart';

class ChatContractCard extends StatefulWidget {
  final Map<String, dynamic> contract;
  final bool isClient;
  final String? clientType;
  final VoidCallback onViewClauses;
  final VoidCallback? onApprove;
  final VoidCallback? onGoToPayments;
  // subuser-review-plan.md م٦ — whether the current user is allowed to
  // approve a contract at all. Defaults to true so every existing call site
  // (the AM-side chat tab, which never passes onApprove in the first place)
  // is unaffected. When false, the approve button is hidden entirely rather
  // than shown-but-disabled, matching the pattern used everywhere else in
  // م٦ (a sub-user should never see an action it can't take, only find out
  // via a 403 if it tries some other way).
  final bool canApprove;

  const ChatContractCard({
    super.key,
    required this.contract,
    required this.isClient,
    this.clientType,
    required this.onViewClauses,
    this.onApprove,
    this.onGoToPayments,
    this.canApprove = true,
  });

  @override
  State<ChatContractCard> createState() => _ChatContractCardState();
}

class _ChatContractCardState extends State<ChatContractCard> {
  final _api = ApiClient();

  Future<void> _viewPdf(String? pdfUrl) async {
    if (pdfUrl == null) return;
    final url = _api.resolveFileUrl(pdfUrl);
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.chatContractCard_fileOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = widget.contract;
    final status = c['status'] as String? ?? '';
    final clauses = c['clauses'] as List<dynamic>? ?? [];
    final showApprove = widget.isClient && status == 'sent' && widget.canApprove;
    final showNeedsOwner = widget.isClient && status == 'sent' && !widget.canApprove;
    final showPayment = widget.isClient && (status == 'company_approved' || status == 'completed');

    final cur = c['currency'] as String? ?? 'SAR';
    final amt = num.tryParse('${c['value'] ?? 0}');
    final dot = (status == 'company_approved' || status == 'completed')
        ? LxStatus.ok
        : (status == 'rejected' || status == 'cancelled')
            ? LxStatus.bad
            : status == 'sent'
                ? LxStatus.wait
                : LxStatus.off;

    // Mockup `.mc` (+ `.ap` while it still needs the client's approval).
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: showApprove ? const Color(0x59941414) : Lx.line),
        gradient: showApprove
            ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x1A941414), Color(0x08941414)])
            : Lx.cardGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text(l10n.contracts.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2))),
            Row(mainAxisSize: MainAxisSize.min, children: [
              LuxeStatusDot(status: dot),
              const SizedBox(width: 6),
              Text(statusLabels(l10n)[status] ?? status, style: Lx.text(context, size: 11, color: Lx.ink2)),
            ]),
          ]),
          const SizedBox(height: 6),
          Text(c['title'] ?? '', style: Lx.display(context, size: 18)),
          const SizedBox(height: 2),
          Text('${amt != null ? lxFormatMoney(amt) : (c['value'] ?? 0)} $cur • ${clauses.length} ${l10n.contractClausesLabel}',
              style: Lx.text(context, size: 12.5, color: Lx.muted)),
          if (widget.clientType == 'business')
            Text(l10n.contractValueExcludesVat, style: Lx.text(context, size: 10, color: Lx.faint)),
          if (status == 'company_approved')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.contractApprovedUploadPayment, style: Lx.text(context, size: 11, color: Lx.ok)),
            ),
          if (['client_approved', 'company_approved', 'completed'].contains(status) && c['pdf_url'] != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _viewPdf(c['pdf_url'] as String?),
              child: Container(
                padding: const EdgeInsets.only(bottom: 1),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                child: Text(
                  status == 'client_approved' ? l10n.viewSignedContract : l10n.downloadFinalContract,
                  style: Lx.text(context, size: 12, color: Lx.ink2),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            TextButton.icon(
              onPressed: widget.onViewClauses,
              icon: const Icon(Icons.list_alt, size: 17),
              label: Text(l10n.viewClauses),
              style: TextButton.styleFrom(foregroundColor: Lx.ink2, padding: const EdgeInsets.symmetric(horizontal: 8), textStyle: Lx.text(context, size: 12.5)),
            ),
            const Spacer(),
            if (showPayment)
              ElevatedButton.icon(
                onPressed: widget.onGoToPayments,
                icon: const Icon(Icons.payment, size: 16),
                label: Text(l10n.uploadPayment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Lx.crimson,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: Lx.text(context, size: 12.5, weight: FontWeight.w500),
                ),
              ),
            if (showApprove)
              ElevatedButton(
                onPressed: widget.onApprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Lx.crimson,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  textStyle: Lx.text(context, size: 12.5, weight: FontWeight.w500),
                ),
                child: Text(l10n.approve),
              ),
          ]),
          if (showNeedsOwner)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LuxeHint(l10n.subuserActionNeedsOwner),
            ),
        ],
      ),
    );
  }
}
