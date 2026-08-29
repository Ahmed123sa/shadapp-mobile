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
import '../../../core/theme.dart';
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
          return AlertDialog(
            backgroundColor: ShadColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              existing == null ? localL10n.adminSettings_addClause : localL10n.adminSettings_editClause,
              style: const TextStyle(fontFamily: 'PlayfairDisplay', color: ShadColors.gold, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary, fontFamily: 'Archivo'),
                  decoration: InputDecoration(
                    labelText: localL10n.adminSettings_clauseName,
                    hintText: localL10n.adminSettings_clauseNamePh,
                    labelStyle: const TextStyle(color: ShadColors.textSecondary),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: ShadColors.cardBorder)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: ShadColors.gold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary, fontFamily: 'Archivo'),
                  decoration: InputDecoration(
                    labelText: localL10n.adminSettings_clauseCategory,
                    labelStyle: const TextStyle(color: ShadColors.textSecondary),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: ShadColors.cardBorder)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: ShadColors.gold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary, fontFamily: 'Archivo'),
                  decoration: InputDecoration(
                    labelText: localL10n.adminSettings_clauseContent,
                    hintText: localL10n.adminSettings_clauseContentPh,
                    labelStyle: const TextStyle(color: ShadColors.textSecondary),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: ShadColors.cardBorder)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: ShadColors.gold)),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Text(localL10n.adminSettings_clauseType, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
                  const SizedBox(width: 12),
                  _typeChip('fixed', localL10n.adminSettings_clauseFixed, type, (v) => setDialogState(() => type = v)),
                  const SizedBox(width: 8),
                  _typeChip('optional', localL10n.adminSettings_clauseOptional, type, (v) => setDialogState(() => type = v)),
                ]),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(localL10n.cancel, style: const TextStyle(fontFamily: 'Archivo')),
              ),
              TextButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  final content = contentController.text.trim();
                  if (title.isEmpty || content.isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: Text(localL10n.save, style: const TextStyle(fontFamily: 'Archivo', fontWeight: FontWeight.w700)),
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

Widget _typeChip(String value, String label, String selected, ValueChanged<String> onChanged) {
  final isSelected = selected == value;
  return GestureDetector(
    onTap: () => onChanged(value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? ShadColors.crimson : ShadColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isSelected ? ShadColors.crimson : ShadColors.cardBorder),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isSelected ? ShadColors.textOnCrimson : ShadColors.textSecondary, fontFamily: 'Archivo')),
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
      backgroundColor: ShadColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l10n.delete, style: const TextStyle(fontFamily: 'PlayfairDisplay', color: ShadColors.gold, fontSize: 18, fontWeight: FontWeight.w700)),
      content: Text(l10n.adminSettings_clauseDeleteConfirm, style: const TextStyle(fontSize: 13, color: ShadColors.textPrimary, fontFamily: 'Archivo')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel, style: const TextStyle(fontFamily: 'Archivo'))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.delete, style: const TextStyle(fontFamily: 'Archivo', fontWeight: FontWeight.w700, color: ShadColors.error)),
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
}) {
  final l10n = AppLocalizations.of(context)!;
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ShadColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ShadColors.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Spacer(),
        ElevatedButton.icon(
          onPressed: clauseSaving ? null : onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: Text(l10n.adminSettings_addClause, style: const TextStyle(fontSize: 12, fontFamily: 'Archivo')),
          style: ElevatedButton.styleFrom(
            backgroundColor: ShadColors.gold,
            foregroundColor: ShadColors.background,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      if (clausesLoading)
        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2.5)))
      else if (clauses.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text(l10n.adminSettings_clausesEmpty, style: const TextStyle(fontSize: 12, color: ShadColors.textSecondary, fontFamily: 'Archivo'))),
        )
      else
        Column(children: [
          for (var i = 0; i < clauses.length; i++) _clauseTile(context, clauses[i], i, onMove, onToggle, onEdit, onDelete),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onSaveOrder,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: Text(l10n.adminSettings_clauseSaveOrder, style: const TextStyle(fontSize: 12, fontFamily: 'Archivo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShadColors.crimson,
                foregroundColor: ShadColors.textOnCrimson,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ]),
    ]),
  );
}

Widget _clauseTile(
  BuildContext context,
  Map<String, dynamic> clause,
  int index,
  void Function(int index, int delta) onMove,
  void Function(Map<String, dynamic>) onToggle,
  void Function(Map<String, dynamic>) onEdit,
  void Function(Map<String, dynamic>) onDelete,
) {
  final l10n = AppLocalizations.of(context)!;
  final isFixed = (clause['type'] as String? ?? 'fixed') == 'fixed';
  final isActive = (clause['is_active'] as bool?) ?? true;
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ShadColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ShadColors.cardBorder),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        GestureDetector(
          onTap: () => onMove(index, -1),
          child: const Icon(Icons.keyboard_arrow_up, size: 18, color: ShadColors.textSecondary),
        ),
        GestureDetector(
          onTap: () => onMove(index, 1),
          child: const Icon(Icons.keyboard_arrow_down, size: 18, color: ShadColors.textSecondary),
        ),
      ]),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(clause['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay', color: ShadColors.textPrimary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isFixed ? ShadColors.gold.withValues(alpha: 0.15) : ShadColors.textSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isFixed ? l10n.adminSettings_clauseFixed : l10n.adminSettings_clauseOptional,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isFixed ? ShadColors.gold : ShadColors.textSecondary, fontFamily: 'Archivo'),
              ),
            ),
          ]),
          if ((clause['category'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(clause['category'] as String, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo')),
          ],
          const SizedBox(height: 4),
          Text(clause['content'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary, fontFamily: 'Archivo', height: 1.4)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.circle, size: 8, color: isActive ? ShadColors.success : ShadColors.textDisabled),
            const SizedBox(width: 4),
            Text(
              isActive ? l10n.adminSettings_clauseActive : l10n.adminSettings_clauseInactive,
              style: TextStyle(fontSize: 10, color: isActive ? ShadColors.success : ShadColors.textDisabled, fontFamily: 'Archivo'),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => onToggle(clause),
              child: Icon(Icons.visibility_outlined, size: 16, color: isActive ? ShadColors.gold : ShadColors.textDisabled),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => onEdit(clause),
              child: const Icon(Icons.edit_outlined, size: 16, color: ShadColors.textSecondary),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => onDelete(clause),
              child: const Icon(Icons.delete_outline, size: 16, color: ShadColors.error),
            ),
          ]),
        ]),
      ),
    ]),
  );
}
