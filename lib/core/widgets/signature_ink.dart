import 'package:flutter/material.dart';

/// Saved signatures are black ink on a transparent (or white) background so
/// they print correctly on the white contract PDF. On the app's dark screens
/// that ink is invisible, so previews show it inverted: black -> white,
/// white background -> black.
class SignatureInk extends StatelessWidget {
  final Widget child;
  const SignatureInk({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: child,
      );
}
