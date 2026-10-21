// Extracted from admin_settings_page.dart (بند ٨: تقسيم الملفات فوق ٨٠٠ سطر)
// — the "Contract clauses" section (add/edit dialog + list tile + reorder/
// toggle/delete actions). Byte-identical logic to what used to live inline
// in admin_settings_page.dart as _saveClause/_deleteClause/_toggleClause/
// _saveClauseOrder/_typeChip/_clauseTile; only the instance-field/method
// reads (_contractProvider, _clauseSaving via setState, _loadClauses)
// became explicit parameters, since a top-level function can't reach a
// State's private members. `context.mounted` replaces the State's own
// `mounted` getter for the same reason — same check, different spelling.
import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../providers/contract_provider.dart';

Future<void> showSaveClauseDialog({
  required BuildContext context,
  Map<String, dynamic>? existing,
  required ContractProvider contractProvider,
  required void Function(bool) setSaving,
  required Future<void> Function() reloadClauses,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final titleController = TextEditingController(text: existing?['title'] as String? ?? '');
  final categoryController = TextEditingController(text: existing?['category'] as String? ?? '');
  final contentController = TextEditingController(text: existing?['content'] as String? ?? '');
  var type = existing?['type'] as String? ?? 'fixed';

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final localL10n = AppLocalizations.of(ctx)!;
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Mockup clauseSheet look: sheet colour, r24, serif title 22,
          // underlined fields, Fixed/Optional `.chip2`.
          return AlertDialog(
            backgroundColor: Lx.sheet,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Lx.rSheet), side: const BorderSide(color: Lx.line2)),
            title: Text(
              existing == null ? localL10n.adminSettings_addClause : localL10n.adminSettings_editClause,
              style: Lx.display(ctx, size: 22),
            ),
            content: LuxeFormTheme(
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(
                    controller: titleController,
                    style: Lx.text(ctx, size: 15),
                    decoration: InputDecoration(labelText: localL10n.adminSettings_clauseName, hintText: localL10n.adminSettings_clauseNamePh),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: categoryController,
                    style: Lx.text(ctx, size: 15),
                    decoration: InputDecoration(labelText: localL10n.adminSettings_clauseCategory),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: contentController,
                    minLines: 2,
                    maxLines: 4,
                    style: Lx.text(ctx, size: 14, height: 1.6),
                    decoration: InputDecoration(labelText: localL10n.adminSettings_clauseContent, hintText: localL10n.adminSettings_clauseContentPh, alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 16),
                  Text(localL10n.adminSettings_clauseType, style: Lx.text(ctx, size: 12, color: Lx.muted)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _typeChip(ctx, 'fixed', localL10n.adminSettings_clauseFixed, type, (v) => setDialogState(() => type = v)),
                    _typeChip(ctx, 'optional', localL10n.adminSettings_clauseOptional, type, (v) => setDialogState(() => type = v)),
                  ]),
                ]),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(localL10n.cancel, style: Lx.text(ctx, size: 13, color: Lx.muted)),
              ),
              TextButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  final content = contentController.text.trim();
                  if (title.isEmpty || content.isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: Text(localL10n.save, style: Lx.text(ctx, size: 13, weight: FontWeight.w500, color: Lx.crimsonInk)),
              ),
            ],
          );
        },
      );
    },
  );

  if (saved != true) return;
  final body = {
    'title': titleController.text.trim(),
    'category': categoryController.text.trim(),
    'content': contentController.text.trim(),
    'type': type,
  };
  setSaving(true);
  try {
    if (existing == null) {
      await contractProvider.createClauseTemplate(body);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminSettings_clauseAdded)));
    } else {
      await contractProvider.updateClauseTemplate(existing['id'] as int, body);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminSettings_clauseUpdated)));
    }
    await reloadClauses();
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
  if (context.mounted) setSaving(false);
}

/// Mockup `.chip2` / `.chip2.on` (crimson .2 fill, .5 border).
Widget _typeChip(BuildContext context, String value, String label, String selected, ValueChanged<String> onChanged) {
  final on = selected == value;
  return GestureDetector(
    onTap: () => onChanged(value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: on ? const Color(0x33941414) : Colors.transparent,
        borderRadius: BorderRadius.circular(Lx.rPill),
        border: Border.all(color: on ? const Color(0x80941414) : Lx.line2),
      ),
      child: Text(label, style: Lx.text(context, size: 12, color: on ? Lx.ink : Lx.ink2)),
    ),
  );
}

Future<void> deleteClauseTemplate({
  required BuildContext context,
  required Map<String, dynamic> clause,
  required ContractProvider contractProvider,
  required Future<void> Function() reloadClauses,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Lx.sheet,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l10n.delete, style: Lx.display(ctx, size: 22)),
      content: Text(l10n.adminSettings_clauseDeleteConfirm, style: Lx.text(ctx, size: 13.5, color: Lx.ink2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel, style: Lx.text(ctx, size: 13, color: Lx.muted))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.delete, style: Lx.text(ctx, size: 13, weight: FontWeight.w500, color: Lx.danger)),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await contractProvider.deleteClauseTemplate(clause['id'] as int);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminSettings_clauseDeleted)));
    await reloadClauses();
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

Future<void> toggleClauseTemplate({
  required BuildContext context,
  required Map<String, dynamic> clause,
  required ContractProvider contractProvider,
  required Future<void> Function() reloadClauses,
}) async {
  try {
    await contractProvider.updateClauseTemplate(clause['id'] as int, {
      'is_active': !((clause['is_active'] as bool?) ?? true),
    });
    await reloadClauses();
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

Future<void> saveClauseTemplateOrder({
  required BuildContext context,
  required List<Map<String, dynamic>> clauses,
  required ContractProvider contractProvider,
  required Future<void> Function() reloadClauses,
}) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final ids = clauses.map((c) => c['id']).toList();
    await contractProvider.reorderClauseTemplates(ids);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminSettings_clauseOrderSaved)));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    await reloadClauses();
  }
}

Widget buildClauseTemplatesSection({
  required BuildContext context,
  required bool clausesLoading,
  required bool clauseSaving,
  required List<Map<String, dynamic>> clauses,
  required VoidCallback onAdd,
  required void Function(int index, int delta) onMove,
  required VoidCallback onSaveOrder,
  required void Function(Map<String, dynamic>) onToggle,
  required void Function(Map<String, dynamic>) onEdit,
  required void Function(Map<String, dynamic>) onDelete,
}) =>
    _ClauseList(
      clausesLoading: clausesLoading,
      clauseSaving: clauseSaving,
      clauses: clauses,
      onAdd: onAdd,
      onMove: onMove,
      onSaveOrder: onSaveOrder,
      onToggle: onToggle,
      onEdit: onEdit,
      onDelete: onDelete,
    );

/// Mockup clause list: a `.card` (padding 4 12) of `.clr2` rows — move
/// arrows, number, text (2 lines), Fixed/Optional `.tagr`, active dot. A tap
/// opens the row (`.dt`) with Activate/Edit/Delete; "Show all" after 6;
/// then Add clause / Save order.
class _ClauseList extends StatefulWidget {
  final bool clausesLoading;
  final bool clauseSaving;
  final List<Map<String, dynamic>> clauses;
  final VoidCallback onAdd;
  final void Function(int index, int delta) onMove;
  final VoidCallback onSaveOrder;
  final void Function(Map<String, dynamic>) onToggle;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  const _ClauseList({
    required this.clausesLoading,
    required this.clauseSaving,
    required this.clauses,
    required this.onAdd,
    required this.onMove,
    required this.onSaveOrder,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ClauseList> createState() => _ClauseListState();
}

class _ClauseListState extends State<_ClauseList> {
  int? _open;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clauses = widget.clauses;
    final shown = _all ? clauses.length : (clauses.length < 6 ? clauses.length : 6);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LuxeCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: widget.clausesLoading
            ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Lx.crimsonInk)))
            : clauses.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text(l10n.adminSettings_clausesEmpty, style: Lx.text(context, size: 12.5, color: Lx.faint))),
                  )
                : Column(children: [
                    for (var i = 0; i < shown; i++) _row(context, clauses[i], i, last: i == shown - 1 && clauses.length <= 6),
                    if (clauses.length > 6)
                      GestureDetector(
                        key: const ValueKey('clauses-show-all'),
                        onTap: () => setState(() => _all = !_all),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: Text(_all ? l10n.clausesShowFewer : '${l10n.amViewAll} (${clauses.length})', style: Lx.text(context, size: 12.5, color: Lx.ink2)),
                          ),
                        ),
                      ),
                  ]),
      ),
      Row(children: [
        Expanded(
          child: LuxeButton(
            key: const ValueKey('clause-add'),
            label: l10n.adminSettings_addClause,
            lxIcon: 'plus',
            onPressed: widget.clauseSaving ? null : widget.onAdd,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LuxeButton(
            key: const ValueKey('clause-save-order'),
            label: l10n.adminSettings_clauseSaveOrder,
            lxIcon: 'down',
            kind: LuxeButtonKind.primary,
            onPressed: clauses.isEmpty ? null : widget.onSaveOrder,
          ),
        ),
      ]),
    ]);
  }

  Widget _row(BuildContext context, Map<String, dynamic> clause, int index, {bool last = false}) {
    final l10n = AppLocalizations.of(context)!;
    final id = clause['id'];
    final isFixed = (clause['type'] as String? ?? 'fixed') == 'fixed';
    final isActive = (clause['is_active'] as bool?) ?? true;
    final open = _open == index;
    final title = clause['title'] as String? ?? '';
    final content = clause['content'] as String? ?? '';
    Widget arrow(String d, int delta) => GestureDetector(
          onTap: () => widget.onMove(index, delta),
          child: SizedBox(width: 18, height: 14, child: Center(child: SvgArrow(d: d))),
        );
    return Container(
      decoration: BoxDecoration(border: last && !open ? null : const Border(bottom: BorderSide(color: Lx.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          key: ValueKey('clause-row-$id'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = open ? null : index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [arrow('up', -1), arrow('down', 1)]),
              const SizedBox(width: 6),
              SizedBox(width: 18, child: Text('${index + 1}', style: Lx.text(context, size: 11, color: Lx.faint, height: 1.8))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title.isNotEmpty ? title : content,
                    maxLines: open ? null : 2,
                    overflow: open ? null : TextOverflow.ellipsis,
                    style: Lx.text(context, size: 13, color: isActive ? Lx.ink : Lx.faint, height: 1.6)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Lx.rPill),
                  border: Border.all(color: isFixed ? const Color(0x73C9B27A) : Lx.line2),
                ),
                child: Text(isFixed ? l10n.adminSettings_clauseFixed : l10n.adminSettings_clauseOptional,
                    style: Lx.text(context, size: 9.5, color: isFixed ? Lx.wait : Lx.muted)),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(width: 7, height: 7, decoration: BoxDecoration(color: isActive ? Lx.ok : Lx.faint, shape: BoxShape.circle)),
              ),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 28, bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title.isNotEmpty && content.isNotEmpty)
                Text(content, style: Lx.text(context, size: 12.5, color: Lx.muted, height: 1.6)),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(
                    child: LuxeButton(
                      key: ValueKey('clause-toggle-$id'),
                      label: isActive ? l10n.amDeactivate : l10n.adminSettings_clauseActive,
                      lxIcon: 'eye',
                      size: LuxeButtonSize.sm,
                      onPressed: () => widget.onToggle(clause),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: LuxeButton(key: ValueKey('clause-edit-$id'), label: l10n.edit, size: LuxeButtonSize.sm, onPressed: () => widget.onEdit(clause))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LuxeButton(
                      key: ValueKey('clause-delete-$id'),
                      label: l10n.delete,
                      size: LuxeButtonSize.sm,
                      kind: LuxeButtonKind.danger,
                      onPressed: () => widget.onDelete(clause),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// The mockup's tiny up/down move arrows (`.mv`), 14px muted strokes.
class SvgArrow extends StatelessWidget {
  final String d;
  const SvgArrow({super.key, required this.d});
  @override
  Widget build(BuildContext context) => Icon(d == 'up' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: Lx.muted);
}
