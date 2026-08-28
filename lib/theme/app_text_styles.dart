import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// AppTextStyles defines the typography system for HappyWay using modern Google Fonts.
/// Base styles omit hardcoded white colors so they adapt cleanly to both Dark and Light themes.
class AppTextStyles {
  AppTextStyles._();

  /// Large display number used for Safety Scores (e.g. "92/100")
  static TextStyle displayScore = GoogleFonts.outfit(
    fontSize: 52,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.1,
  );

  /// Screen main headers
  static TextStyle titleHero = GoogleFonts.outfit(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  /// Section titles
  static TextStyle titleLarge = GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// Card titles & subheads
  static TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  /// List item titles
  static TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// Primary body text
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  /// Secondary body text
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  /// Small descriptions
  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Badge / Pill tag text
  static TextStyle badgeLabel = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  // Context-aware text style helpers
  static TextStyle hero(BuildContext context) =>
      titleHero.copyWith(color: AppColors.primaryText(context));

  static TextStyle heading(BuildContext context) =>
      titleLarge.copyWith(color: AppColors.primaryText(context));

  static TextStyle title(BuildContext context) =>
      titleMedium.copyWith(color: AppColors.primaryText(context));

  static TextStyle body(BuildContext context) =>
      bodyMedium.copyWith(color: AppColors.secondaryText(context));

  static TextStyle muted(BuildContext context) =>
      bodySmall.copyWith(color: AppColors.mutedText(context));
}
