import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Central theme and color palette following 70-20-10 design system
class AppPalette {
  // Brand primary (20%) and deep gradient end
  static const Color primary = Color(0xFF00897B);
  static const Color primaryDeep = Color(0xFF005B52);
  static final Color primarySoft = primary.withValues(alpha: 0.12);

  // Brand accent (10% — alternating activity icon chip & highlight badges only)
  static const Color accent = Color(0xFFFF7043);
  static final Color accentSoft = accent.withValues(alpha: 0.12);

  // Light mode (70% neutral base)
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF757575);
  static final Color lightShadow = Colors.black.withValues(alpha: 0.08);

  // Dark mode (mirrored structure, brand stays constant)
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFF2F2F2);
  static const Color darkTextSecondary = Color(0xFFA0A0A0);
  static final Color darkShadow = Colors.black.withValues(alpha: 0.24);

  // Exactly one gradient element per screen (primary -> primaryDeep, diagonal)
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDeep],
  );

  // Context-aware getters
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBackground
          : lightBackground;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface
          : lightSurface;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : lightTextSecondary;

  static Color shadow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkShadow
          : lightShadow;

  // BoxShadow for cards / list rows
  static List<BoxShadow> cardShadow(BuildContext context) => [
        BoxShadow(
          color: shadow(context),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppPalette.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppPalette.primary,
        surface: AppPalette.lightSurface,
        onSurface: AppPalette.lightTextPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppPalette.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppPalette.primary,
        surface: AppPalette.darkSurface,
        onSurface: AppPalette.darkTextPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
