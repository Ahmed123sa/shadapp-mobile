import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../api_client.dart';

/// ContractController::clientAction() rejects an 'approved' action when
/// required documents have not been uploaded (or are all rejected):
/// a 422 whose body carries `code: 'required_documents_missing'` and
/// `missing_documents: [{ id, name }]`.
///
/// Returns true if `error` was this specific rejection and a dialog was shown.
Future<bool> maybeShowRequiredDocumentsDialog(BuildContext context, Object error) async {
  if (error is! ValidationException || error.code != 'required_documents_missing') return false;
  if (!context.mounted) return true;

  final l10n = AppLocalizations.of(context)!;
  final missingDocs = error.data?['missing_documents'];
  String? docNames;
  if (missingDocs is List && missingDocs.isNotEmpty) {
    docNames = missingDocs
        .map((d) => d is Map ? (d['name'] ?? '') : d.toString())
        .where((n) => (n as String).isNotEmpty)
        .join('، ');
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.contractDocsRequiredTitle),
      content: Text(docNames != null && docNames.isNotEmpty
          ? l10n.contractUploadRequiredFirstWithDocs(docNames)
          : l10n.contractUploadRequiredFirst),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.confirm),
        ),
      ],
    ),
  );
  return true;
}
