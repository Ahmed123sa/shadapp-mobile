import 'package:flutter/material.dart';
import 'tokens.dart';

/// The app-wide Luxe theme (Plan 1). Every stock widget (Card, ListTile,
/// dialogs, sheets, chips, tabs, buttons, fields, snackbars…) that a screen has
/// not restyled by hand inherits the mockup look from here instead of the old
/// gold/Playfair theme. Values come from the mockup CSS (`design/mobile/*`).
ThemeData luxeTheme({bool arabic = false}) {
  final family = arabic ? Lx.arabic : Lx.sans;
  final fallback = arabic ? const [Lx.sans] : const [Lx.arabic];
  const underline = UnderlineInputBorder(borderSide: BorderSide(color: Lx.line2));
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = base.textTheme.apply(
    fontFamily: family,
    fontFamilyFallback: fallback,
    bodyColor: Lx.ink,
    displayColor: Lx.ink,
  );
  TextStyle ts(double size, {FontWeight w = FontWeight.w400, Color c = Lx.ink}) =>
      TextStyle(fontFamily: family, fontFamilyFallback: fallback, fontSize: size, fontWeight: w, color: c);

  return base.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Lx.page,
    canvasColor: Lx.page,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    colorScheme: const ColorScheme.dark(
      primary: Lx.crimson,
      onPrimary: Colors.white,
      secondary: Lx.ink2,
      onSecondary: Lx.page,
      error: Lx.danger,
      onError: Lx.page,
      surface: Lx.page,
      onSurface: Lx.ink,
      onSurfaceVariant: Lx.muted,
      outline: Lx.line2,
      outlineVariant: Lx.line,
      surfaceContainerLowest: Lx.page,
      surfaceContainerLow: Lx.surface,
      surfaceContainer: Lx.surface,
      surfaceContainerHigh: Lx.sheet,
      surfaceContainerHighest: Lx.sheet,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Lx.page,
      foregroundColor: Lx.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontFamily: Lx.serif, fontFamilyFallback: const [Lx.arabic], fontSize: 20, fontWeight: FontWeight.w500, color: Lx.ink),
    ),
    cardTheme: CardThemeData(
      color: Lx.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Lx.rCard),
        side: const BorderSide(color: Lx.cardBorder),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    dividerTheme: const DividerThemeData(color: Lx.line, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: Lx.muted,
      textColor: Lx.ink,
      titleTextStyle: ts(14),
      subtitleTextStyle: ts(12.5, c: Lx.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 9),
      border: underline,
      enabledBorder: underline,
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.crimsonInk)),
      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.danger)),
      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.danger)),
      labelStyle: ts(12, c: Lx.muted),
      floatingLabelStyle: ts(12, c: Lx.muted),
      hintStyle: ts(15, c: Lx.faint),
      errorStyle: ts(11.5, c: Lx.danger),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Lx.crimsonInk, selectionHandleColor: Lx.crimsonInk),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Lx.crimson,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Lx.crimson.withAlpha(96),
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const StadiumBorder(),
        textStyle: ts(13, w: FontWeight.w500),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Lx.crimson,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        shape: const StadiumBorder(),
        textStyle: ts(13, w: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Lx.ink2,
        side: const BorderSide(color: Lx.line2),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const StadiumBorder(),
        textStyle: ts(13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Lx.ink2, textStyle: ts(13)),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Lx.muted)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Lx.crimson,
      foregroundColor: Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: Lx.ink,
      disabledColor: Colors.transparent,
      side: const BorderSide(color: Lx.line2),
      shape: const StadiumBorder(),
      labelStyle: ts(12, c: Lx.ink2),
      secondaryLabelStyle: ts(12, c: const Color(0xFF111111)),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Lx.ink,
      unselectedLabelColor: Lx.muted,
      indicatorColor: Lx.crimsonInk,
      dividerColor: Lx.line,
      labelStyle: ts(13.5, w: FontWeight.w500),
      unselectedLabelStyle: ts(13.5),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Lx.sheet,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Lx.rSheet),
        side: const BorderSide(color: Lx.line),
      ),
      titleTextStyle: TextStyle(fontFamily: Lx.serif, fontFamilyFallback: const [Lx.arabic], fontSize: 20, fontWeight: FontWeight.w500, color: Lx.ink),
      contentTextStyle: ts(13.5, c: Lx.ink2),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Lx.sheet,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Lx.sheet,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Lx.sheet,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Lx.line2)),
      textStyle: ts(13.5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Lx.sheet,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Lx.line2)),
      contentTextStyle: ts(13),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Lx.rail,
      selectedItemColor: Lx.ink,
      unselectedItemColor: Lx.muted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: ts(10.5),
      unselectedLabelStyle: ts(10.5),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Lx.crimsonInk, linearTrackColor: Lx.line2),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : const Color(0xFF777777)),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Lx.crimson : const Color(0xFF2A2A2A)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Lx.crimson : Colors.transparent),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: Lx.line2, width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Lx.crimsonInk : Lx.muted),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Lx.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Lx.rSheet)),
    ),
  );
}
