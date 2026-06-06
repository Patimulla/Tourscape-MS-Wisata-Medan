/// ============================================================
/// Tourscape MS — Earth Tone Theme System
/// Light & Dark mode dengan palette coklat/beige/gold
/// ============================================================

import 'package:flutter/material.dart';

class AppTheme {
  // ── EARTH TONE COLOR CONSTANTS ──
  // Vibrant Accents for Tourism Feel
  static const Color vibrantPrimary = Color(0xFFD4A855); // Gold
  static const Color vibrantSecondary = Color(0xFFF59E0B); // Amber
  static const Color vibrantGlow = Color(0x66D4A855);

  // Primary palette
  static const Color primaryLight = Color(0xFF8B6914);
  static const Color primaryDark = Color(0xFFC49A3C);

  // Surface & Background
  static const Color bgLight = Color(0xFFF5F0E8);
  static const Color bgDark = Color(0xFF1A1410);
  static const Color surfaceLight = Color(0xFFFFF8F0);
  static const Color surfaceDark = Color(0xFF2A2118);
  static const Color cardLight = Color(0xFFFFFDF8);
  static const Color cardDark = Color(0xFF33271C);

  // Text
  static const Color textPrimaryLight = Color(0xFF3E2723);
  static const Color textPrimaryDark = Color(0xFFF5F0E8);
  static const Color textSecondaryLight = Color(0xFF795548);
  static const Color textSecondaryDark = Color(0xFFBCA88A);

  // Accent
  static const Color accent = Color(0xFFA67B40);
  static const Color accentLight = Color(0xFFE8C876);
  static const Color secondary = Color(0xFF6D4C2A);
  static const Color secondaryDark = Color(0xFFD4A855);

  // Functional
  static const Color success = Color(0xFF6B8E4E);
  static const Color successDark = Color(0xFF8FBC6A);
  static const Color error = Color(0xFFC75050);
  static const Color errorDark = Color(0xFFE07070);

  // Borders
  static const Color borderLight = Color(0xFFD7CFC0);
  static const Color borderDark = Color(0xFF3D3228);

  // Map-specific
  static const Color routeColor = Color(0xFF2563EB);
  static const Color routeGlow = Color(0x6638BDF8);

  // ── LIGHT THEME ──
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        secondary: Color(0xFF6D4C2A),
        surface: surfaceLight,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: bgLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF5C4322),
        foregroundColor: Color(0xFFFFF8F0),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFFF8F0),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 2,
        shadowColor: const Color(0x1A795548),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        labelStyle: const TextStyle(color: textSecondaryLight, fontSize: 14),
        hintStyle: TextStyle(color: textSecondaryLight.withAlpha(120), fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  // ── DARK THEME ──
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        secondary: secondaryDark,
        surface: surfaceDark,
        error: errorDark,
        onPrimary: Color(0xFF1A1410),
        onSecondary: Color(0xFF1A1410),
        onSurface: textPrimaryDark,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: bgDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF241C14),
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 2,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: const Color(0xFF1A1410),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        labelStyle: const TextStyle(color: textSecondaryDark, fontSize: 14),
        hintStyle: TextStyle(color: textSecondaryDark.withAlpha(120), fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: errorDark),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(color: borderDark, thickness: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: Color(0xFF1A1410),
        elevation: 4,
      ),
    );
  }

  // ── HELPERS ──

  /// Vibrant gradient for primary buttons (e.g., Navigasi, Submit)
  static LinearGradient vibrantGradient(BuildContext context) {
    return const LinearGradient(
      colors: [Color(0xFFD4A855), Color(0xFFC49A3C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Glassmorphism surface decoration
  static BoxDecoration glassDecoration(BuildContext context) {
    return BoxDecoration(
      color: surface(context).withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border(context).withValues(alpha: 0.5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 10,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primary(BuildContext context) =>
      isDark(context) ? primaryDark : primaryLight;

  static Color surface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color card(BuildContext context) =>
      isDark(context) ? cardDark : cardLight;

  static Color bg(BuildContext context) =>
      isDark(context) ? bgDark : bgLight;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondaryLight;

  static Color border(BuildContext context) =>
      isDark(context) ? borderDark : borderLight;

  /// Gradient for backgrounds
  static LinearGradient bgGradient(BuildContext context) {
    return isDark(context)
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1410), Color(0xFF241C14), Color(0xFF1A1410)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F0E8), Color(0xFFFFF8F0), Color(0xFFF5F0E8)],
          );
  }

  /// AppBar gradient
  static LinearGradient appBarGradient(BuildContext context) {
    return isDark(context)
        ? const LinearGradient(
            colors: [Color(0xFF241C14), Color(0xFF33271C)],
          )
        : const LinearGradient(
            colors: [Color(0xFF5C4322), Color(0xFF8B6914)],
          );
  }
}
