import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../api_client.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'status_badge.dart';

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
    final isGoldBorder = status == 'company_approved';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: isGoldBorder ? ShadColors.gold : ShadColors.primary, width: isGoldBorder ? 1.5 : 2),
        borderRadius: BorderRadius.circular(12),
        color: ShadColors.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isGoldBorder ? Icons.verified : Icons.description,
                color: isGoldBorder ? ShadColors.gold : ShadColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['title'] ?? '', style: ShadTypography.cardTitle),
                    const SizedBox(height: 2),
                    Text('${c['value'] ?? 0} ${c['currency'] as String? ?? 'SAR'} • ${clauses.length} ${l10n.contractClausesLabel}',
                      style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
                    if (widget.clientType == 'business')
                      Text(l10n.contractValueExcludesVat, style: TextStyle(fontSize: 9, color: ShadColors.textDisabled)),
                  ],
                ),
              ),
              StatusBadge(status: status, fontSize: 10),
            ]),
            if (status == 'company_approved')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l10n.contractApprovedUploadPayment,
                  style: const TextStyle(fontSize: 10, color: ShadColors.gold, fontWeight: FontWeight.w500)),
              ),
            if (['client_approved', 'company_approved', 'completed'].contains(status) && c['pdf_url'] != null) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _viewPdf(c['pdf_url'] as String?),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.picture_as_pdf, size: 14, color: ShadColors.error),
                  const SizedBox(width: 4),
                  Text(
                    status == 'client_approved' ? l10n.viewSignedContract : l10n.downloadFinalContract,
                    style: ShadTypography.cardBody.copyWith(color: ShadColors.primary, decoration: TextDecoration.underline, fontSize: 11),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                onPressed: widget.onViewClauses,
                icon: const Icon(Icons.list_alt, size: 18),
                label: Text(l10n.viewClauses),
              ),
              const Spacer(),
              if (showPayment)
                ElevatedButton.icon(
                  onPressed: widget.onGoToPayments,
                  icon: const Icon(Icons.payment, size: 16),
                  label: Text(l10n.uploadPayment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShadColors.crimson,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: ShadTypography.cardBody.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              if (showApprove)
                ElevatedButton(
                  onPressed: widget.onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShadColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: ShadTypography.cardBody.copyWith(fontWeight: FontWeight.w600),
                  ),
                  child: Text(l10n.approve),
                ),
            ]),
            if (showNeedsOwner)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l10n.subuserActionNeedsOwner, style: const TextStyle(fontSize: 10, color: ShadColors.textDisabled)),
              ),
          ],
        ),
      ),
    );
  }
}
