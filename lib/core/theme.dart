import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

class ShadColors {
  // Brand Core (70/20/10 Rule)
  static const Color black = Color(0xFF1C1C1C);
  static const Color crimson = Color(0xFF941414);
  static const Color whiteSoft = Color(0xFFF0F0F0);
  static const Color gold = Color(0xFFD4AF37);

  // Surfaces
  static const Color surface = Color(0xFF1C1C1C);
  static const Color surfaceDarker = Color(0xFF0D0D0D);
  static const Color panelBg = Color(0xFF111111);
  static const Color card = Color(0xFF1E1E1E);
  static const Color cardAlt = Color(0xFF181818);
  static const Color cardBorder = Color(0xFF2A2A2A);
  static const Color borderLight = Color(0xFF333333);
  static const Color divider = Color(0xFF2A2A2A);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textDisabled = Color(0xFF606060);
  static const Color textOnCrimson = Color(0xFFF0F0F0);

  // Accent
  static const Color accent = Color(0xFF941414);
  static const Color accentLight = Color(0xFFB71C1C);
  static const Color accentDark = Color(0xFF6B0E0E);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF1A3A2A);
  static const Color warning = Color(0xFFEAB308);
  static const Color warningLight = Color(0xFF3A3520);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFF3A2020);
  static const Color blue = Color(0xFF60A5FA);
  static const Color purple = Color(0xFFA78BFA);
  static const Color orange = Color(0xFFFB923C);

  // Input
  static const Color inputFill = Color(0xFF2A2A2A);
  static const Color inputBorder = Color(0xFF3A3A3A);
  static const Color inputFocused = Color(0xFFD4AF37);

  // Additions from redesign
  static const Color surfaceLighter = Color(0xFF2A2A2A);
  static const Color avatarBorder = Color(0xFF941414);
  static const Color cardGoldBorder = Color(0xFFD4AF37);
  static const Color online = Color(0xFF22C55E);

  // Chat-specific colors
  static const Color chatBg = Color(0xFF181818);
  static const Color chatBorder = Color(0xFF1C1C1C);
  static const Color chatHeaderBg = Color(0xFF0D0D0D);
  static const Color chatInputFill = Color(0xFF141414);
  static const Color chatInputBorder = Color(0xFF1A1A1A);
  static const Color meetingBlue = Color(0xFF85B7EB);
  static const Color meetingBlueBg = Color(0xFF1A2530);
  static const Color meetingBlueBorder = Color(0xFF2A4050);

  // WhatsApp-like sender bubble colors
  static const Color managerBubble = Color(0xFF1E2A3A);
  static const Color subUserBubble = Color(0xFF2A1E1E);
  static const Color managerNameColor = Color(0xFF85B7EB);
  static const Color subUserNameColor = Color(0xFFD4AF37);

  // Gold variants for approval cards
  static const Color goldSoft = Color(0x23D4AF37);
  static const Color goldBorder = Color(0x4DD4AF37);

  // Text variants for chat
  static const Color textMuted = Color(0xFF555555);
  static const Color textDim = Color(0xFF9A9A96);
  static const Color crimsonSoft = Color(0x2E941414);
  static const Color crimsonBorder = Color(0x52941414);

  // Legacy aliases for backward compatibility
  static const Color primary = Color(0xFF941414);
  static const Color primaryLight = Color(0xFFB71C1C);
  static const Color primaryDark = Color(0xFF6B0E0E);
  static const Color secondary = Color(0xFF3A3A3A);
  static const Color background = Color(0xFF1C1C1C);
  static const Color draft = Color(0xFF606060);
  static const Color sent = Color(0xFF3B82F6);
  static const Color approved = Color(0xFF22C55E);
  static const Color rejected = Color(0xFFEF4444);
  static const Color companyApproved = Color(0xFF8B5CF6);
  static const Color completed = Color(0xFF10B981);
  static const Color archived = Color(0xFF52525B);
}

const String arabicFont = 'Tajawal';

final Map<String, Color> statusColors = {
  'draft': ShadColors.draft,
  'sent': ShadColors.sent,
  'client_approved': ShadColors.approved,
  'client_rejected': ShadColors.rejected,
  'company_approved': ShadColors.companyApproved,
  'completed': ShadColors.completed,
  'archived': ShadColors.archived,
  'pending': ShadColors.warning,
  'approved': ShadColors.approved,
  'rejected': ShadColors.rejected,
  'edit_requested': ShadColors.warning,
  'active': ShadColors.success,
  'inactive': ShadColors.textDisabled,
  'scheduled': ShadColors.gold,
  'cancelled': ShadColors.error,
};

Map<String, String> statusLabels(AppLocalizations l10n) => {
  'draft': l10n.draft,
  'sent': l10n.sent,
  'client_approved': l10n.clientApproved,
  'client_rejected': l10n.clientRejected,
  'company_approved': l10n.companyApproved,
  'completed': l10n.completed,
  'archived': l10n.archived,
  'pending': l10n.pending,
  'approved': l10n.approved,
  'rejected': l10n.rejected,
  'edit_requested': l10n.editRequestedStatus,
  'active': l10n.active,
  'inactive': l10n.inactive,
  'scheduled': l10n.scheduled,
  'cancelled': l10n.cancelled,
};

class ShadTypography {
  static const TextStyle appBarTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0, height: 1.4);
  static const TextStyle largeTitle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, height: 1.33);
  static const TextStyle sectionHeader = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, height: 1.38);
  static const TextStyle cardTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.37);
  static const TextStyle cardSubtitle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.43);
  static const TextStyle cardBody = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.43);
  static const TextStyle body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.43);
  static const TextStyle caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.33);
  static const TextStyle badge = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3, height: 1.27);
  static const TextStyle buttonLabel = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5, height: 1.43);
  static const TextStyle inputLabel = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.29);
  static const TextStyle inputText = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.37);
  static const TextStyle emptyTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.44);
  static const TextStyle emptyBody = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.43);
  static const TextStyle chatBubble = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.6);
  static const TextStyle chatTimestamp = TextStyle(fontSize: 9, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.27);
}

ThemeData shadTheme() {
  final textTheme = GoogleFonts.getTextTheme(
    'Playfair Display',
    GoogleFonts.archivoTextTheme(
      GoogleFonts.tajawalTextTheme(
        ThemeData.dark().textTheme,
      ),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: arabicFont,
    textTheme: textTheme,
    colorScheme: const ColorScheme.dark(
      primary: ShadColors.crimson,
      onPrimary: ShadColors.textOnCrimson,
      secondary: ShadColors.cardBorder,
      onSecondary: ShadColors.textPrimary,
      error: ShadColors.error,
      onError: ShadColors.textOnCrimson,
      surface: ShadColors.black,
      onSurface: ShadColors.textPrimary,
    ),
    scaffoldBackgroundColor: ShadColors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: ShadColors.black,
      foregroundColor: ShadColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: ShadTypography.appBarTitle,
    ),
    cardTheme: CardThemeData(
      color: ShadColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ShadColors.cardBorder),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ShadColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ShadColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ShadColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ShadColors.inputFocused, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ShadColors.error),
      ),
      labelStyle: ShadTypography.inputLabel.copyWith(color: ShadColors.textSecondary),
      hintStyle: ShadTypography.inputText.copyWith(color: ShadColors.textDisabled),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ShadColors.crimson,
        foregroundColor: ShadColors.textOnCrimson,
        textStyle: ShadTypography.buttonLabel,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ShadColors.crimson,
        textStyle: ShadTypography.buttonLabel,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        side: const BorderSide(color: ShadColors.crimson),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ShadColors.crimson,
        textStyle: ShadTypography.buttonLabel,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ShadColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentTextStyle: ShadTypography.body.copyWith(color: ShadColors.textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: ShadColors.black,
      selectedItemColor: ShadColors.gold,
      unselectedItemColor: ShadColors.textDisabled,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: ShadTypography.caption,
      unselectedLabelStyle: ShadTypography.caption,
    ),
    dividerTheme: const DividerThemeData(
      color: ShadColors.divider,
      thickness: 1,
      space: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ShadColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: ShadColors.cardBorder),
      labelStyle: ShadTypography.caption.copyWith(color: ShadColors.textPrimary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ShadColors.crimson,
      foregroundColor: ShadColors.textOnCrimson,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ShadColors.crimson,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return ShadColors.crimson;
        return ShadColors.textDisabled;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return ShadColors.accentLight;
        return ShadColors.cardBorder;
      }),
    ),
  );
}
