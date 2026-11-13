// Extracted from client_onboarding_screen.dart as part of بند ٨ (file splitting).
// Pure stage widgets: the parent screen still owns all state (client,
// workspace, taxSettings) and every side-effecting action; these functions
// only build UI.
//
// Luxe layout (design/mobile/client-mobile-mockup.html, obStage/obSticky):
// each stage is a heading + lead in the scroll body, and the stage's buttons
// live in the screen's pinned bottom bar (buildXxxActions).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../core/widgets/ads_split.dart';
import 'onboarding_signature_pad.dart';

// ── shared bits ──

Widget _h2(BuildContext context, String text) =>
    Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(text, style: Lx.display(context, size: 23)));

Widget _lead(BuildContext context, String text) =>
    Padding(padding: const EdgeInsets.only(bottom: 18), child: Text(text, style: Lx.text(context, size: 13.5, color: Lx.muted, height: 1.5)));

ButtonStyle _primaryStyle() => ElevatedButton.styleFrom(
      backgroundColor: Lx.crimson,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: const StadiumBorder(),
      elevation: 0,
      disabledBackgroundColor: const Color(0xFF2A2827),
      disabledForegroundColor: Lx.faint,
    );

ButtonStyle _outlineStyle() => OutlinedButton.styleFrom(
      foregroundColor: Lx.ink2,
      minimumSize: const Size.fromHeight(48),
      shape: const StadiumBorder(),
      side: const BorderSide(color: Lx.line2),
    );

// ── Stage 0: signature ──

Widget buildSignatureStage({
  required BuildContext context,
  required Map<String, dynamic>? client,
  required SignatureDraft draft,
  required VoidCallback onPickImage,
  required ValueChanged<bool> onDrawingChanged,
  VoidCallback? onOpenFullscreen,
}) {
  final l10n = AppLocalizations.of(context)!;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _h2(context, l10n.onboarding_welcomeName(client?['contact_person'] ?? '')),
    _lead(context, l10n.onboarding_addSignaturePrompt),
    OnboardingSignaturePad(draft: draft, onPickImage: onPickImage, onDrawingChanged: onDrawingChanged, onOpenFullscreen: onOpenFullscreen),
  ]);
}

List<Widget> buildSignatureActions({
  required BuildContext context,
  required SignatureDraft draft,
  required bool saving,
  required Future<void> Function() onSave,
}) =>
    [
      ListenableBuilder(
        listenable: draft,
        builder: (ctx, _) => ElevatedButton(
          key: const ValueKey('onboarding-sign'),
          onPressed: (draft.canSave && !saving) ? onSave : null,
          style: _primaryStyle(),
          child: saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(AppLocalizations.of(ctx)!.signature_saveSignature),
        ),
      ),
    ];

// ── Waiting stages (1, 3, 5, 6) ──

/// [boxed] puts the message in a card (stages 1 and 3, like the mockup's
/// waitBox); stages 5 and 6 are bare.
Widget buildWaitingStage({
  required BuildContext context,
  required String title,
  required String subtitle,
  bool boxed = true,
  Widget? extra,
}) {
  final l10n = AppLocalizations.of(context)!;
  final content = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.only(top: 8), child: LuxePulseDot(key: ValueKey('waiting-pulse'))),
    const SizedBox(width: 14),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Lx.display(context, size: 23)),
        const SizedBox(height: 8),
        Text(subtitle, style: Lx.text(context, size: 13.5, color: Lx.muted, height: 1.5)),
        if (extra != null) ...[const SizedBox(height: 18), extra],
        const SizedBox(height: 14),
        Row(children: [
          const LxIcon('bell', size: 14, color: Lx.faint),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.onboardingNotifyHint, style: Lx.text(context, size: 12, color: Lx.faint))),
        ]),
      ]),
    ),
  ]);
  return boxed
      ? LuxeCard(key: const ValueKey('waiting-card'), child: content)
      : Padding(key: const ValueKey('waiting-plain'), padding: const EdgeInsets.only(top: 8), child: content);
}

/// "What happens next": the stages still ahead, numbered 0N, as plain rows.
Widget buildNextList({
  required BuildContext context,
  required String title,
  required List<MapEntry<int, String>> steps, // index (0-based) → label
}) {
  if (steps.isEmpty) return const SizedBox.shrink();
  return Column(
    key: const ValueKey('next-steps'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(title.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.6)),
      ),
      for (var i = 0; i < steps.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: i == steps.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
          child: Row(children: [
            Text('0${steps[i].key + 1}', style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 1)),
            const SizedBox(width: 12),
            Expanded(child: Text(steps[i].value, style: Lx.text(context, size: 13.5))),
          ]),
        ),
    ],
  );
}

// ── Stage 2: contract review ──

Map? _sentContract(Map<String, dynamic>? workspace) {
  final contracts = workspace != null ? safeList(workspace['contracts']).whereType<Map>().toList() : <Map>[];
  for (final c in contracts) {
    if (c['status'] == 'sent') return c;
  }
  return contracts.isNotEmpty ? contracts.first : null;
}

bool _hasMissingDocs(Map? sentContract) {
  final requiredDocs = sentContract != null ? safeList(sentContract['required_documents']) : [];
  return requiredDocs.isNotEmpty &&
      requiredDocs.any((d) {
        if (d is! Map) return false;
        final files = d['files'] as List<dynamic>?;
        if (files != null && files.isNotEmpty) {
          return !files.any((f) => f is Map && f['status'] != 'rejected');
        }
        return d['status'] != 'approved' && d['status'] != 'pending';
      });
}

/// A required document is "uploaded" once it has a file that was not rejected
/// (or, with no file list, a pending/approved status) — same rule as
/// [_hasMissingDocs].
bool _docUploaded(Map d) {
  final files = d['files'] as List<dynamic>?;
  if (files != null && files.isNotEmpty) {
    return files.any((f) => f is Map && f['status'] != 'rejected');
  }
  return d['status'] == 'approved' || d['status'] == 'pending';
}

String? _docFileUrl(Map d) {
  final files = d['files'] as List<dynamic>?;
  if (files == null) return null;
  for (final f in files) {
    if (f is Map && f['status'] != 'rejected' && f['file_url'] != null) return f['file_url'] as String;
  }
  return null;
}

Widget buildContractReviewStage({
  required BuildContext context,
  required Map<String, dynamic>? workspace,
  required void Function(Map) onPreviewContract,
  required int? uploadingDocId,
  required void Function(int contractId, int docId) onUploadDocument,
  required void Function(String url) onOpenFile,
}) {
  final l10n = AppLocalizations.of(context)!;
  final sent = _sentContract(workspace);
  final requiredDocs = sent != null ? safeList(sent['required_documents']) : [];
  final clauses = sent != null ? safeList(sent['clauses']) : [];
  final value = sent != null ? double.tryParse((sent['value'] ?? '').toString()) : null;
  final pdf = sent?['pdf_url'] as String?;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _h2(context, l10n.onboarding_contractReceived),
    _lead(context, l10n.onboarding_reviewContractPrompt),
    if (sent != null)
      LuxeCard(
        key: const ValueKey('onboarding-contract-card'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((sent['contract_type'] == 'additional' ? l10n.onboardingAdditionalContract : l10n.mainContract).toUpperCase(),
              style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.2)),
          const SizedBox(height: 4),
          Text('${sent['title'] ?? ''}', style: Lx.display(context, size: 19)),
          Builder(builder: (context) {
            // The API has no sent_at; a sent contract's last update is the send.
            final when = DateTime.tryParse('${sent['updated_at'] ?? ''}')?.toLocal();
            final parts = [
              if (when != null) l10n.onboardingSentOn(DateFormat('d MMM', Localizations.localeOf(context).toString()).format(when)),
              if (clauses.isNotEmpty) l10n.onboardingClauseCount(clauses.length),
            ];
            if (parts.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(parts.join(' · '), key: const ValueKey('onboarding-contract-sub'), style: Lx.text(context, size: 12, color: Lx.muted)),
            );
          }),
          if (value != null) ...[
            const SizedBox(height: 10),
            Text.rich(TextSpan(children: [
              TextSpan(text: _fmt(value), style: Lx.display(context, size: 20)),
              TextSpan(text: '  ${sent['currency'] ?? ''}', style: Lx.text(context, size: 11, color: Lx.muted)),
            ])),
            if (contractHasAds(sent)) AdsSplit(contract: sent, currency: '${sent['currency'] ?? 'SAR'}', size: 12),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            LuxeButton(
              key: const ValueKey('onboarding-preview-contract'),
              label: l10n.onboardingPreviewShort,
              lxIcon: 'eye',
              size: LuxeButtonSize.sm,
              onPressed: () => onPreviewContract(sent),
            ),
            if (pdf != null)
              LuxeButton(
                key: const ValueKey('onboarding-download-pdf'),
                label: l10n.onboardingDownloadPdf,
                lxIcon: 'doc',
                size: LuxeButtonSize.sm,
                onPressed: () => onOpenFile(pdf),
              ),
          ]),
        ]),
      ),
    if (requiredDocs.isNotEmpty)
      LuxeCard(
        key: const ValueKey('onboarding-docs-card'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.requiredDocuments.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.2)),
          const SizedBox(height: 6),
          for (var i = 0; i < requiredDocs.length; i++)
            if (requiredDocs[i] is Map) ...[
              Builder(builder: (_) {
                final d = requiredDocs[i] as Map;
                final up = _docUploaded(d);
                final url = _docFileUrl(d);
                final id = d['id'] as int?;
                final busy = uploadingDocId != null && uploadingDocId == id;
                return Container(
                  key: ValueKey('onboarding-doc-$i'),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: i == requiredDocs.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d['name'] ?? ''}', style: Lx.text(context, size: 13.5)),
                        const SizedBox(height: 3),
                        Row(children: [
                          LuxeStatusDot(status: up ? LxStatus.ok : LxStatus.bad),
                          const SizedBox(width: 7),
                          Text(up ? l10n.onboardingDocUploaded : l10n.onboardingDocMissing, style: Lx.text(context, size: 12, color: Lx.ink2)),
                        ]),
                        if ((d['rejection_reason'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(l10n.rejectionReason('${d['rejection_reason']}'), style: Lx.text(context, size: 11, color: Lx.danger)),
                          ),
                      ]),
                    ),
                    if (up && url != null)
                      InkWell(
                        key: ValueKey('onboarding-doc-open-$i'),
                        onTap: () => onOpenFile(url),
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 1),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Lx.line2))),
                          child: Text(l10n.onboardingPreviewShort, style: Lx.text(context, size: 12.5, color: Lx.ink2)),
                        ),
                      )
                    else if (!up && id != null)
                      LuxeButton(
                        key: ValueKey('onboarding-doc-upload-$i'),
                        label: busy ? l10n.uploading : l10n.uploadDocument,
                        lxIcon: 'up',
                        size: LuxeButtonSize.sm,
                        onPressed: busy ? null : () => onUploadDocument(sent!['id'] as int, id),
                      ),
                  ]),
                );
              }),
            ],
        ]),
      ),
  ]);
}

/// Where one required document stands, from its files: ok (one is approved),
/// missing (none), rejected (every file was refused) or pending (waiting).
String contractDocState(Map d) {
  final files = safeList(d['files']).whereType<Map>().toList();
  if (files.any((f) => f['status'] == 'approved')) return 'ok';
  if (files.isEmpty) return 'missing';
  return files.every((f) => f['status'] == 'rejected') ? 'rejected' : 'pending';
}

/// The contract the client already approved and the company has not, if any.
Map? clientApprovedContract(Map<String, dynamic>? workspace) {
  final contracts = workspace != null ? safeList(workspace['contracts']).whereType<Map>().toList() : <Map>[];
  for (final c in contracts) {
    if (c['status'] == 'client_approved') return c;
  }
  return null;
}

/// After the client approved, the company still has to accept every required
/// document. Lists them with where each stands, why a rejected one was refused,
/// and lets the client send a replacement. Draws nothing when all are accepted.
Widget buildContractDocsReview({
  required BuildContext context,
  required Map? contract,
  required int? uploadingDocId,
  required void Function(int contractId, int docId) onUploadDocument,
  required bool canUpload,
}) {
  if (contract == null) return const SizedBox.shrink();
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  String t(String a, String e) => ar ? a : e;
  final docs = safeList(contract['required_documents'])
      .whereType<Map>()
      .where((d) => d['is_required'] != false && d['is_required'] != 0)
      .toList();
  if (docs.isEmpty || docs.every((d) => contractDocState(d) == 'ok')) return const SizedBox.shrink();

  final label = {
    'ok': t('مقبول', 'Approved'),
    'pending': t('قيد المراجعة', 'Under review'),
    'rejected': t('مرفوض', 'Rejected'),
    'missing': t('ماترفعش', 'Not uploaded'),
  };
  final dot = {'ok': LxStatus.ok, 'pending': LxStatus.wait, 'rejected': LxStatus.bad, 'missing': LxStatus.bad};

  return LuxeCard(
    key: const ValueKey('contract-docs-review'),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('المستندات تحت المراجعة', 'Documents under review').toUpperCase(),
          style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.2)),
      const SizedBox(height: 6),
      Text(t('الشركة بتعتمد العقد لما كل المستندات المطلوبة تتقبل.', 'The company approves the contract once every required document is accepted.'),
          style: Lx.text(context, size: 12, color: Lx.muted, height: 1.5)),
      const SizedBox(height: 4),
      for (var i = 0; i < docs.length; i++)
        Builder(builder: (_) {
          final d = docs[i];
          final state = contractDocState(d);
          final id = d['id'] as int?;
          final busy = uploadingDocId != null && uploadingDocId == id;
          final files = safeList(d['files']).whereType<Map>().toList();
          final rejected = files.reversed.firstWhere((f) => f['status'] == 'rejected', orElse: () => const {});
          final reason = (rejected['rejection_reason'] ?? '').toString();
          return Container(
            key: ValueKey('contract-docs-review-$i'),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: i == docs.length - 1 ? null : const Border(bottom: BorderSide(color: Lx.line))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d['name'] ?? ''}', style: Lx.text(context, size: 13.5)),
                  const SizedBox(height: 3),
                  Row(children: [
                    LuxeStatusDot(status: dot[state]!),
                    const SizedBox(width: 7),
                    Text(label[state]!, style: Lx.text(context, size: 12, color: Lx.ink2)),
                  ]),
                  if (state == 'rejected' && reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(t('السبب: $reason', 'Reason: $reason'), style: Lx.text(context, size: 11, color: Lx.danger)),
                    ),
                ]),
              ),
              if ((state == 'rejected' || state == 'missing') && canUpload && id != null)
                LuxeButton(
                  key: ValueKey('contract-docs-replace-$i'),
                  label: busy ? t('بيترفع...', 'Uploading...') : (state == 'rejected' ? t('ارفع بديل', 'Upload replacement') : t('ارفع', 'Upload')),
                  lxIcon: 'up',
                  size: LuxeButtonSize.sm,
                  onPressed: busy ? null : () => onUploadDocument(contract['id'] as int, id),
                ),
            ]),
          );
        }),
    ]),
  );
}

Widget _lockLine(BuildContext context, String text, {Key? key}) => Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const LxIcon('lock', size: 14, color: Lx.faint),
        const SizedBox(width: 8),
        Flexible(child: Text(text, textAlign: TextAlign.center, style: Lx.text(context, size: 12, color: Lx.faint))),
      ],
    );

List<Widget> buildContractReviewActions({
  required BuildContext context,
  required Map<String, dynamic>? workspace,
  required void Function(String) onRespond,
  VoidCallback? onRequestEdit,
}) {
  final l10n = AppLocalizations.of(context)!;
  final missing = _hasMissingDocs(_sentContract(workspace));
  return [
    ElevatedButton(
      key: const ValueKey('onboarding-approve'),
      onPressed: missing ? null : () => onRespond('approved'),
      style: _primaryStyle(),
      child: Text(l10n.onboarding_approve),
    ),
    OutlinedButton(
      key: const ValueKey('onboarding-request-edit'),
      onPressed: onRequestEdit ?? () => onRespond('edit_requested'),
      style: _outlineStyle(),
      child: Text(l10n.onboarding_requestEdit),
    ),
    if (missing)
      _lockLine(context, l10n.contractUploadRequiredFirst, key: const ValueKey('onboarding-docs-hint')),
  ];
}

/// Mockup `st.edit` card: label, textarea, "Send request" + "Cancel".
Widget buildEditRequestCard({
  required BuildContext context,
  required TextEditingController controller,
  required bool sending,
  required VoidCallback onSend,
  required VoidCallback onCancel,
}) {
  final l10n = AppLocalizations.of(context)!;
  const box = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Lx.line2));
  return LuxeCard(
    key: const ValueKey('onboarding-edit-card'),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.onboardingEditLabel, style: Lx.text(context, size: 12, color: Lx.muted)),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey('onboarding-edit-text'),
        controller: controller,
        minLines: 3,
        maxLines: 6,
        style: Lx.text(context, size: 13),
        decoration: InputDecoration(
          hintText: l10n.onboardingEditHint,
          hintStyle: Lx.text(context, size: 13, color: Lx.faint),
          filled: false,
          contentPadding: const EdgeInsets.all(12),
          border: box,
          enabledBorder: box,
          focusedBorder: box.copyWith(borderSide: const BorderSide(color: Lx.muted)),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        LuxeButton(
          key: const ValueKey('onboarding-edit-send'),
          label: l10n.onboardingSendRequest,
          kind: LuxeButtonKind.primary,
          onPressed: sending ? null : onSend,
        ),
        LuxeButton(
          key: const ValueKey('onboarding-edit-cancel'),
          label: l10n.onboarding_cancel,
          onPressed: sending ? null : onCancel,
        ),
      ]),
    ]),
  );
}

/// Stage 6: "Your request" + the client's own words, quoted.
Widget buildEditReasonQuote(BuildContext context, String reason) {
  final l10n = AppLocalizations.of(context)!;
  return Column(key: const ValueKey('onboarding-edit-quote'), crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l10n.onboardingYourRequest.toUpperCase(), style: Lx.text(context, size: 10.5, color: Lx.faint).copyWith(letterSpacing: 2.6)),
    const SizedBox(height: 6),
    Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
      decoration: const BoxDecoration(border: BorderDirectional(start: BorderSide(color: Lx.crimsonInk, width: 2))),
      child: Text(reason, style: Lx.text(context, size: 13, color: Lx.ink2, height: 1.5)),
    ),
  ]);
}

// ── Stage 4: payment ──

class _PaymentFigures {
  double total = 0, paid = 0, tax = 0, taxPct = 0;
  // What the tax is charged on: the whole value of a normal contract, only
  // the agency fee of an ads contract (the ad budget inside is not taxed).
  double _taxBase = 0;
  double? _serverPct;
  bool _serverTax = false;
  String currency = 'SAR';
  String? startDate, endDate;
  final List<Map> adsContracts = [];
  Map<String, dynamic>? lastRejected;
  int? workspaceId;

  // Dollar-conversion fees: added on top of the value, never taxed.
  double conversion = 0;

  double get grand => total + conversion + tax;
  double get remaining => grand - paid;

  _PaymentFigures(Map<String, dynamic>? ws, Map<String, dynamic>? client, Map<String, dynamic>? taxSettings) {
    final isBusiness = (client?['client_type'] ?? '') == 'business';
    if (isBusiness && taxSettings != null) {
      taxPct = num.tryParse(taxSettings['corporate_tax_percentage']?['value']?.toString() ?? '')?.toDouble() ?? 0;
    }
    if (ws != null) {
      workspaceId = ws['id'] as int?;
      for (final c in safeList(ws['contracts'])) {
        if (c is Map) {
          final value = double.tryParse((c['value'] ?? '0').toString()) ?? 0.0;
          total += value;
          // A contract excluded from tax adds nothing to the taxable base.
          if (c['tax_excluded'] != true) {
            _taxBase += contractHasAds(c) ? (double.tryParse((c['ads_amount'] ?? '0').toString()) ?? 0.0) : value;
          }
          if (contractHasConversion(c)) conversion += double.tryParse('${c['conversion_amount']}') ?? 0.0;
          // The server prices each contract with its own locked rate.
          final serverTax = double.tryParse((c['tax_amount'] ?? '').toString());
          if (serverTax != null) {
            _serverTax = true;
            tax += serverTax;
            _serverPct = double.tryParse((c['tax_percentage'] ?? '').toString()) ?? _serverPct;
          }
          currency = (c['currency'] as String?) ?? currency;
          if (contractHasAds(c)) adsContracts.add(c);
          if (c['start_date'] != null) startDate = (c['start_date'] as String).split('T')[0];
          if (c['end_date'] != null) endDate = (c['end_date'] as String).split('T')[0];
        }
      }
      for (final p in safeList(ws['payments'])) {
        if (p is Map) {
          if (p['status'] == 'approved') {
            paid += double.tryParse((p['amount'] ?? '0').toString()) ?? 0.0;
          } else if (p['status'] == 'rejected') {
            lastRejected = p.cast<String, dynamic>();
          }
        }
      }
    }
    if (_serverTax) {
      // The rate the server priced with; dividing by the contract value would
      // understate it for an ads contract, which is taxed on its fee only.
      if (_serverPct != null) {
        taxPct = _serverPct!;
      } else if (_taxBase > 0) {
        taxPct = tax * 100 / _taxBase;
      }
    } else if (isBusiness && taxPct > 0) {
      tax = _taxBase * taxPct / 100;
    }
  }
}

String _pctLabel(Object? v) {
  final n = num.tryParse('${v ?? 0}') ?? 0;
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}

String _fmt(double v) {
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}

Widget _billRow(BuildContext context, String label, double value, String currency, {bool strong = false, bool last = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: Lx.text(context, size: 13, color: strong ? Lx.ink : Lx.muted)),
      Text.rich(TextSpan(children: [
        TextSpan(text: _fmt(value), style: Lx.display(context, size: 16)),
        TextSpan(text: '  $currency', style: Lx.text(context, size: 10.5, color: Lx.muted)),
      ])),
    ]),
  );
}

Widget buildPaymentStage({
  required BuildContext context,
  required Map<String, dynamic>? workspace,
  required Map<String, dynamic>? client,
  required Map<String, dynamic>? taxSettings,
}) {
  final l10n = AppLocalizations.of(context)!;
  final f = _PaymentFigures(workspace, client, taxSettings);
  final rejected = f.lastRejected;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (rejected != null)
      LuxeCard(
        key: const ValueKey('payment-rejected-card'),
        attention: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const LxIcon('alert', size: 18, color: Lx.crimsonInk),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.onboarding_paymentRejectedTitle, style: Lx.text(context, size: 14, weight: FontWeight.w700, color: Lx.crimsonInk))),
          ]),
          // payments-fixes-2-plan.md ت٢ — rejection_reason (why it was
          // rejected) and notes (the manager's note from requesting it) are
          // different things; notes must not stand in for the reason.
          if ((rejected['rejection_reason'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${l10n.onboarding_paymentRejectedReason}: ${rejected['rejection_reason']}', style: Lx.text(context, size: 12)),
          ],
          const SizedBox(height: 6),
          Text(l10n.onboarding_paymentRejectedRetry, style: Lx.text(context, size: 11, color: Lx.ink2)),
        ]),
      ),
    _h2(context, l10n.onboarding_completePayment),
    _lead(context, l10n.onboarding_confirmPaymentToActivate),
    LuxeCard(
      key: const ValueKey('payment-bill-card'),
      child: Column(children: [
        _billRow(context, l10n.onboarding_amount, f.total, f.currency),
        for (final c in f.adsContracts) ...[
          _billRow(context, '${f.adsContracts.length > 1 ? '${c['title'] ?? ''} · ' : ''}${l10n.adsFee(_pctLabel(c['ads_percentage']))}', double.tryParse('${c['ads_amount']}') ?? 0, f.currency),
          _billRow(context, '${f.adsContracts.length > 1 ? '${c['title'] ?? ''} · ' : ''}${l10n.adsBudget}', double.tryParse('${c['ads_budget']}') ?? 0, f.currency),
        ],
        for (final c in f.adsContracts.where(contractHasConversion))
          _billRow(context, '${f.adsContracts.length > 1 ? '${c['title'] ?? ''} · ' : ''}${l10n.adsConversion(_pctLabel(c['conversion_percentage']))}', double.tryParse('${c['conversion_amount']}') ?? 0, f.currency),
        if (f.tax > 0) _billRow(context, l10n.onboarding_tax, f.tax, f.currency),
        _billRow(context, f.conversion > 0 ? l10n.totalDue : l10n.onboarding_total, f.grand, f.currency, strong: true),
        _billRow(context, l10n.onboarding_paidAmount, f.paid, f.currency),
        _billRow(context, l10n.onboarding_remainingAmount2, f.remaining, f.currency, last: true),
      ]),
    ),
    if (f.startDate != null || f.endDate != null)
      LuxeCard(
        key: const ValueKey('payment-dates-card'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.onboarding_contractDetails, style: Lx.text(context, size: 12, color: Lx.muted)),
          const SizedBox(height: 10),
          if (f.startDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const LxIcon('scroll', size: 14, color: Lx.faint),
                const SizedBox(width: 8),
                Text('${l10n.onboarding_startDate}: ${f.startDate}', style: Lx.text(context, size: 12)),
              ]),
            ),
          if (f.endDate != null)
            Row(children: [
              const LxIcon('scroll', size: 14, color: Lx.faint),
              const SizedBox(width: 8),
              Text('${l10n.onboarding_endDate}: ${f.endDate}', style: Lx.text(context, size: 12)),
            ]),
        ]),
      ),
  ]);
}

List<Widget> buildPaymentActions({
  required BuildContext context,
  required Map<String, dynamic>? workspace,
  required Map<String, dynamic>? client,
  required Map<String, dynamic>? taxSettings,
  required void Function(double suggestedAmount, int? workspaceId, String currency) onSendPayment,
}) {
  final l10n = AppLocalizations.of(context)!;
  final f = _PaymentFigures(workspace, client, taxSettings);
  return [
    ElevatedButton(
      key: const ValueKey('onboarding-send-payment'),
      onPressed: () => onSendPayment(f.remaining > 0 ? f.remaining : f.grand, f.workspaceId, f.currency),
      style: _primaryStyle(),
      child: Text(l10n.onboarding_sendPayment),
    ),
  ];
}

/// Stage 5: the payment that was just sent, waiting for review.
Widget buildSentPaymentCard({required BuildContext context, required Map<String, dynamic>? workspace}) {
  final l10n = AppLocalizations.of(context)!;
  Map? pay;
  for (final p in safeList(workspace?['payments'])) {
    if (p is Map && p['status'] == 'pending') pay = p;
  }
  if (pay == null) return const SizedBox.shrink();
  final methods = {
    'bank_transfer': l10n.payments_methodBankTransfer,
    'swift': l10n.payments_methodSwift,
    'corporate_account': l10n.payments_methodCorporateAccount,
    'instapay': l10n.payments_methodInstapay,
    'vodafone_cash': l10n.payments_methodVodafoneCash,
    'mobile_wallet': l10n.payments_methodMobileWallet,
    'cheque': l10n.payments_methodCheque,
  };
  final amount = double.tryParse((pay['amount'] ?? '').toString());
  final method = methods[pay['method_type']] ?? '${pay['method_type'] ?? ''}';
  return LuxeCard(
    key: const ValueKey('sent-payment-card'),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${l10n.onboardingPaymentSent} · $method', style: Lx.text(context, size: 13.5)),
          const SizedBox(height: 3),
          Row(children: [
            const LuxeStatusDot(status: LxStatus.wait),
            const SizedBox(width: 7),
            Text(l10n.onboardingUnderReview, style: Lx.text(context, size: 12, color: Lx.ink2)),
          ]),
        ]),
      ),
      if (amount != null)
        Text.rich(TextSpan(children: [
          TextSpan(text: _fmt(amount), style: Lx.display(context, size: 18)),
          TextSpan(text: '  ${pay['currency'] ?? ''}', style: Lx.text(context, size: 11, color: Lx.muted)),
        ])),
    ]),
  );
}
