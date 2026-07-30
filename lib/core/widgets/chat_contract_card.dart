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

  const ChatContractCard({
    super.key,
    required this.contract,
    required this.isClient,
    this.clientType,
    required this.onViewClauses,
    this.onApprove,
    this.onGoToPayments,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل فتح الملف')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contract;
    final status = c['status'] as String? ?? '';
    final clauses = c['clauses'] as List<dynamic>? ?? [];
    final showApprove = widget.isClient && status == 'sent';
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
                    Text('${c['value'] ?? 0} SAR • ${clauses.length} بند',
                      style: ShadTypography.cardBody.copyWith(color: ShadColors.textSecondary)),
                    if (widget.clientType == 'business')
                      const Text('قيمة العقد غير شاملة الضريبة', style: TextStyle(fontSize: 9, color: ShadColors.textDisabled)),
                  ],
                ),
              ),
              StatusBadge(status: status, fontSize: 10),
            ]),
            if (status == 'company_approved')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('تم اعتماد العقد — يمكنك رفع الدفعة الآن',
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
                    status == 'client_approved' ? '📄 عرض العقد الموقع' : '📄 تحميل العقد النهائي',
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
                label: Text(AppLocalizations.of(context)!.viewClauses),
              ),
              const Spacer(),
              if (showPayment)
                ElevatedButton.icon(
                  onPressed: widget.onGoToPayments,
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('رفع الدفعة'),
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
                  child: Text(AppLocalizations.of(context)!.approve),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
