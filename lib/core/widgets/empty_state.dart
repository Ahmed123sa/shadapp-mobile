import 'package:flutter/material.dart';
import '../luxe/tokens.dart';

/// Empty list in the Luxe language: faint icon, serif title (20), muted lead
/// (13.5), and the mockup's primary pill button when there's an action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Lx.faint),
            const SizedBox(height: 16),
            Text(title, style: Lx.display(context, size: 20), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: Lx.text(context, size: 13.5, color: Lx.muted, height: 1.5), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Lx.crimson,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(actionLabel!, style: Lx.text(context, size: 13, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
