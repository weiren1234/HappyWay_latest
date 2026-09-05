import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle displayScore = GoogleFonts.outfit(
    fontSize: 52,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.1,
  );

  static TextStyle titleHero = GoogleFonts.outfit(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  static TextStyle titleLarge = GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  static TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle badgeLabel = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

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
