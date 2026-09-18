import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// نفس متغيرات الألوان بتاعة نسخة الـ HTML بالظبط
class C {
  static const bg = Color(0xFF0B0D0E);
  static const panel = Color(0xFF16191B);
  static const panel2 = Color(0xFF1D2123);
  static const border = Color(0xFF2A2E31);
  static const text = Color(0xFFEDEDED);
  static const muted = Color(0xFF8A9096);
  static const accent = Color(0xFFF2542D);
  static const accentDim = Color(0xFF7A2C17);
  static const good = Color(0xFFC7F464);
  static const danger = Color(0xFFE5484D);
}

const double kRadius = 14;

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  // خط Cairo: بيدعم العربي والإنجليزي بشكل ممتاز وبأوزان متعددة (200-900)
  final cairoText = GoogleFonts.cairoTextTheme(base.textTheme)
      .apply(bodyColor: C.text, displayColor: C.text);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.accent,
      secondary: C.accent,
      surface: C.panel,
      error: C.danger,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.cairo(
        color: C.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: cairoText,
    primaryTextTheme: cairoText,
    dividerColor: C.border,
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: C.panel2,
      hintStyle: const TextStyle(color: C.muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.accent),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.panel,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: C.panel2,
      contentTextStyle: TextStyle(color: C.text, fontSize: 13.5),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : C.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? C.accent : C.panel2),
      trackOutlineColor: WidgetStateProperty.all(C.border),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? C.accent : C.panel2),
      side: const BorderSide(color: C.border),
    ),
  );
}
