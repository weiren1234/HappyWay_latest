import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// AppTheme provides global Flutter ThemeData for both Dark and Light themes.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.weatherBlue,
        secondary: AppColors.accentCyan,
        surface: AppColors.backgroundCardDark,
        error: AppColors.dangerRed,
        onPrimary: Colors.white,
        onSecondary: AppColors.backgroundDark,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 30, fontWeight: FontWeight.w800),
        titleLarge: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
        bodySmall: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.glassSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.backgroundCardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorderLight),
        ),
        titleTextStyle: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.backgroundCardDark,
        modalBackgroundColor: AppColors.backgroundCardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 22,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundCardDark,
        contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.weatherBlue,
        secondary: AppColors.accentCyanLight,
        surface: AppColors.backgroundCardLight,
        error: AppColors.dangerRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        onSurfaceVariant: AppColors.textSecondaryLight,
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.outfit(color: AppColors.textPrimaryLight, fontSize: 30, fontWeight: FontWeight.w800),
        titleLarge: GoogleFonts.outfit(color: AppColors.textPrimaryLight, fontSize: 22, fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.inter(color: AppColors.textPrimaryLight, fontSize: 17, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.inter(color: AppColors.textPrimaryLight, fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: AppColors.textPrimaryLight, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: AppColors.textSecondaryLight, fontSize: 13),
        bodySmall: GoogleFonts.inter(color: AppColors.textMutedLight, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
      ),
      cardTheme: CardThemeData(
        color: AppColors.glassSurfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.glassBorderLightMode, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.backgroundCardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorderLightMode),
        ),
        titleTextStyle: GoogleFonts.outfit(color: AppColors.textPrimaryLight, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: GoogleFonts.inter(color: AppColors.textSecondaryLight, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.backgroundCardLight,
        modalBackgroundColor: AppColors.backgroundCardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryLight,
        size: 22,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundCardLight,
        contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimaryLight, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorderLightMode),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorderLightMode,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
