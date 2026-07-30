import 'package:flutter/material.dart';
import '../theme.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_rounded, size: 48, color: ShadColors.warning),
            const SizedBox(height: 16),
            Text('تعذر تحميل البيانات', style: ShadTypography.emptyTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: ShadTypography.emptyBody.copyWith(color: ShadColors.textSecondary), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
