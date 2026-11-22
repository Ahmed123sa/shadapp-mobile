import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/tokens.dart';
import '../../../providers/contract_provider.dart';

/// Closing a contract is hard to undo for the client's balance, so it takes more
/// than a tap: the dialog shows the numbers, blocks while a proof waits for
/// review, lets only the super admin close with money owed (after a tick), and
/// asks for the contract name to be typed.
///
/// Resolves to true once the contract was closed, false/null otherwise.
class CloseContractDialog extends StatefulWidget {
  const CloseContractDialog({super.key, required this.contract, required this.provider});

  final Map<String, dynamic> contract;
  final ContractProvider provider;

  static Future<bool?> show(BuildContext context,
          {required Map<String, dynamic> contract, required ContractProvider provider}) =>
      showDialog<bool>(
        context: context,
        builder: (_) => CloseContractDialog(contract: contract, provider: provider),
      );

  @override
  State<CloseContractDialog> createState() => _CloseContractDialogState();
}

class _CloseContractDialogState extends State<CloseContractDialog> {
  Map<String, dynamic>? _preview;
  bool _loadFailed = false;
  bool _busy = false;
  bool _understood = false;
  final _name = TextEditingController();

  String get _title => '${widget.contract['title'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    try {
      final p = await widget.provider.closePreview(widget.contract['id'] as int);
      if (mounted) setState(() => _preview = p);
    } catch (e, s) {
      AppLog.error('close_contract_dialog._loadPreview', e, s);
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  num _n(String key) => num.tryParse('${_preview?[key] ?? 0}') ?? 0;

  Future<void> _close(bool confirmOutstanding) async {
    setState(() => _busy = true);
    try {
      await widget.provider.closeContract(widget.contract['id'] as int, confirmOutstanding: confirmOutstanding);
      if (mounted) Navigator.pop(context, true);
    } catch (e, s) {
      AppLog.error('close_contract_dialog._close', e, s);
      if (!mounted) return;
      setState(() => _busy = false);
      // The server says why (a proof arrived meanwhile, a balance appeared...).
      final reason = e is ValidationException || e is ServerException ? e.toString() : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(reason.isEmpty ? AppLocalizations.of(context)!.errorOccurred : reason)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = _preview;
    final cur = '${p?['currency'] ?? widget.contract['currency'] ?? 'SAR'}';
    final outstanding = _n('outstanding');
    final owed = outstanding > 0;
    final canOverride = p?['can_override'] == true;
    final pendingCount = _n('pending_count').toInt();
    final blockedByPending = p != null && pendingCount > 0;
    final blockedByManager = p != null && owed && !canOverride;
    final needsTick = p != null && owed && canOverride;
    final nameOk = _name.text.trim() == _title.trim();
    final canConfirm = p != null &&
        !blockedByPending &&
        !blockedByManager &&
        nameOk &&
        (!needsTick || _understood) &&
        !_busy;

    Widget row(String label, num v, {bool bold = false, Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(
                child: Text(label,
                    style: Lx.text(context,
                        size: 13, weight: bold ? FontWeight.w600 : FontWeight.w400))),
            Text('${lxFormatMoney(v)} $cur',
                key: key,
                textDirection: TextDirection.ltr,
                style: Lx.text(context, size: 13, weight: bold ? FontWeight.w600 : FontWeight.w400)),
          ]),
        );

    return AlertDialog(
      key: const ValueKey('close-contract-dialog'),
      title: Text(l10n.closeContractTitle(_title)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.closeContractIntro, style: Lx.text(context, size: 13, color: Lx.muted)),
          const SizedBox(height: 12),
          if (p == null && !_loadFailed)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (_loadFailed)
            Text(l10n.closeLoadError, style: Lx.text(context, size: 13, color: Lx.crimsonInk))
          else ...[
            row(l10n.closeSummaryTotal, _n('total_due')),
            row(l10n.closeSummaryPaid, _n('paid')),
            row(l10n.closeSummaryOutstanding, outstanding,
                bold: true, key: const ValueKey('close-outstanding')),
            const SizedBox(height: 8),
            if (blockedByPending)
              Text(l10n.closePendingBlock(pendingCount),
                  key: const ValueKey('close-pending-block'),
                  style: Lx.text(context, size: 13, color: Lx.crimsonInk))
            else if (blockedByManager)
              Text(l10n.closeOutstandingManager,
                  key: const ValueKey('close-manager-block'),
                  style: Lx.text(context, size: 13, color: Lx.crimsonInk)),
            if (_n('scheduled_count') > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    l10n.closeInstallmentsNote(_n('scheduled_count').toInt(),
                        lxFormatMoney(_n('scheduled_amount')), cur),
                    style: Lx.text(context, size: 12.5, color: Lx.muted)),
              ),
            if (_n('unlinked_paid') > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.closeUnlinkedNote(lxFormatMoney(_n('unlinked_paid')), cur),
                    style: Lx.text(context, size: 12.5, color: Lx.muted)),
              ),
            if (needsTick && !blockedByPending)
              CheckboxListTile(
                key: const ValueKey('close-understood'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _understood,
                onChanged: (v) => setState(() => _understood = v ?? false),
                title: Text(l10n.closeOutstandingConfirm(lxFormatMoney(outstanding), cur),
                    style: Lx.text(context, size: 13)),
              ),
            if (!blockedByPending && !blockedByManager) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('close-name-field'),
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.closeTypeName, hintText: _title),
              ),
            ],
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        ElevatedButton(
          key: const ValueKey('close-confirm'),
          onPressed: canConfirm ? () => _close(needsTick && _understood) : null,
          style: ElevatedButton.styleFrom(backgroundColor: Lx.crimson, foregroundColor: Colors.white),
          child: Text(l10n.closeContractConfirm),
        ),
      ],
    );
  }
}
