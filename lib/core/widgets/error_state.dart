import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../luxe/lx_icons.dart';
import '../luxe/tokens.dart';

/// Load failure in the Luxe language: the mockup alert icon (wait yellow),
/// serif title, muted message, and an outline pill "Retry".
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LxIcon('alert', size: 36, color: Lx.wait),
            const SizedBox(height: 16),
            Text(l10n.couldNotLoadData, style: Lx.display(context, size: 20), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: Lx.text(context, size: 13.5, color: Lx.muted, height: 1.5), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Lx.ink2,
                  side: const BorderSide(color: Lx.line2),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: const StadiumBorder(),
                ),
                icon: const LxIcon('refresh', size: 15, color: Lx.ink2),
                label: Text(l10n.retry, style: Lx.text(context, size: 13, color: Lx.ink2)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
