import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../api_client.dart';

/// client-signature-plan.md ن3 — ContractController::clientAction() and
/// ChatController::respond() (ك3/ك4) now reject an 'approved' action with
/// no saved client signature: a 422 whose body carries
/// `code: 'signature_required'` alongside the human-readable message.
///
/// This is the shared reactive handling for that specific rejection, used
/// by the three screens that call one of those two endpoints
/// (contracts_page.dart, chat_page.dart, client_onboarding_screen.dart).
/// client_onboarding_screen.dart's own _computeStage() additionally keeps
/// the client on the signature stage until they've saved one, so it should
/// rarely reach this path in practice — this stays as a fallback there too,
/// since the backend is the actual source of truth, not the client-side
/// stage computation.
///
/// Returns true if `error` was this specific rejection (and a dialog was
/// shown for it) — the caller should stop there instead of falling through
/// to its own generic error handling. Returns false for anything else so
/// the caller's existing handling still runs unchanged.
Future<bool> maybeShowSignatureRequiredDialog(BuildContext context, Object error, {required bool isSubUser}) async {
  if (error is! ValidationException || error.code != 'signature_required') return false;
  if (!context.mounted) return true;

  final l10n = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.signatureRequiredTitle),
      content: Text(isSubUser ? l10n.signatureRequiredSubUserMessage : l10n.signatureRequiredMessage),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        // A sub-user acts on behalf of the primary client and has no
        // signature of its own to save — see client-signature-plan.md ن3.
        if (!isSubUser)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/signature');
            },
            child: Text(l10n.signatureRequiredAction),
          ),
      ],
    ),
  );
  return true;
}
