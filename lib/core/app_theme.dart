import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF4834D4);
  static const Color secondary = Color(0xFFFD79A8);
  static const Color accent = Color(0xFF00B894);

  // Background Colors
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color sidebarBackground = Color(0xFF0F172A);

  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);

  // Glassmorphism Values
  static const double glassBlur = 20.0;
  static const double glassOpacity = 0.05;
  static final Color glassBorder = Colors.white.withValues(alpha: 0.1);

  static ThemeData get darkTheme {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            headlineMedium: GoogleFonts.outfit(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
            bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 16),
            bodyMedium: GoogleFonts.inter(color: textSecondary, fontSize: 14),
          ),
      // cardTheme: CardTheme(
      //   color: surface,
      //   elevation: 0,
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(16),
      //     side: BorderSide(color: glassBorder),
      //   ),
      // ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: Colors.white.withValues(alpha: 0.2),
        selectionHandleColor: primary,
        cursorColor: primary,
      ),
    );
  }
}
