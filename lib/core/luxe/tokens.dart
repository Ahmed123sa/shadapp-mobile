import 'package:flutter/material.dart';

/// Luxe design tokens (Plan 1). Values are copied from the mockup CSS
/// (`design/mobile/*-mockup.html`), not eyeballed. Kept separate from
/// `ShadColors` so screens that are not migrated yet do not change.
class Lx {
  Lx._();

  // Surfaces
  static const Color page = Color(0xFF141313);
  static const Color rail = Color(0xFF101010);
  static const Color surface = Color(0xFF1B1A19);
  static const Color sheet = Color(0xFF1A1918);

  // Ink
  static const Color ink = Color(0xFFF0F0F0);
  static const Color ink2 = Color(0xFFB9B9B9);
  static const Color muted = Color(0xFF8A8A8A);
  static const Color faint = Color(0xFF808080);

  // Lines (ink at 7% / 12%)
  static const Color line = Color(0x12F0F0F0);
  static const Color line2 = Color(0x1FF0F0F0);

  // Accent + status
  static const Color crimson = Color(0xFF941414);
  static const Color crimsonInk = Color(0xFFD24A4A);
  static const Color ok = Color(0xFF8FB98B);
  static const Color wait = Color(0xFFC9B27A);
  static const Color tuscan = Color(0xFFA8986A);
  static const Color danger = Color(0xFFDD8888);

  // Card
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x09FFFFFF), Color(0x03FFFFFF)],
  );
  static const LinearGradient cardApGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x1A941414), Color(0x08941414)],
  );
  static const Color cardBorder = Color(0x12F0F0F0);
  static const Color cardApBorder = Color(0x59941414);

  // Radii
  static const double rCard = 16;
  static const double rSheet = 24;
  static const double rPill = 999;

  // Font families (registered in pubspec.yaml)
  static const String serif = 'LxSerif';
  static const String sans = 'LxSans';
  static const String arabic = 'LxArabic';

  /// Arabic text uses Tajawal, everything else Archivo (falls back to Tajawal
  /// for mixed strings, like the mockup's font stack).
  static String family(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar' ? arabic : sans;

  static TextStyle text(BuildContext context, {double size = 13, FontWeight weight = FontWeight.w400, Color color = ink, double? height}) =>
      TextStyle(fontFamily: family(context), fontFamilyFallback: const [arabic, sans], fontSize: size, fontWeight: weight, color: color, height: height);

  /// Display headings (Playfair in English; Tajawal bold in Arabic).
  static TextStyle display(BuildContext context, {double size = 24, Color color = ink}) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return TextStyle(
      fontFamily: ar ? arabic : serif,
      fontFamilyFallback: const [arabic, serif],
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.25,
    );
  }
}

/// Status of a row / chip: drives the dot colour.
enum LxStatus { ok, wait, bad, off }

Color lxStatusColor(LxStatus s) {
  switch (s) {
    case LxStatus.ok:
      return Lx.ok;
    case LxStatus.wait:
      return Lx.wait;
    case LxStatus.bad:
      return Lx.crimsonInk;
    case LxStatus.off:
      return Lx.muted;
  }
}
