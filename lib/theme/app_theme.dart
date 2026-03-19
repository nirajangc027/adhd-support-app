import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const background = Color(0xFFF8F3FF); // warm off-white with purple tint
  static const primary = Color(0xFF4EC8C8); // soft teal
  static const secondary = Color(0xFFE8C8D8); // warm pink
  static const cardColor = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2D2D3A); // soft dark
  static const textSecondary = Color(0xFF8A8A9A); // muted grey

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: textPrimary,
      secondary: secondary,
      onSecondary: textPrimary,
      surface: cardColor,
      onSurface: textPrimary,
      surfaceTint: primary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      dividerColor: const Color(0xFFEDE7F6),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 28,
            color: selected ? primary : textSecondary,
          );
        }),
      ),
    );
  }
}

