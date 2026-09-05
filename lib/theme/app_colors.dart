import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color backgroundCardDark = Color(0xFF111827);
  static const Color backgroundGradientStart = Color(0xFF0A0E17);
  static const Color backgroundGradientEnd = Color(0xFF172136);

  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundCardLight = Color(0xFFFFFFFF);
  static const Color backgroundGradientStartLight = Color(0xFFF8FAFC);
  static const Color backgroundGradientEndLight = Color(0xFFE2E8F0);

  static const Color glassSurface = Color(0x1AFFFFFF);
  static const Color glassSurfaceHover = Color(0x26FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassBorderLight = Color(0x40FFFFFF);
  static const Color glassHighlight = Color(0x1AFFFFFF);
  static const Color cardShadow = Color(0x40000000);
  static const Color navBarBackground = Color(0xCC0D1322);

  static const Color glassSurfaceLight = Color(0xF2FFFFFF);
  static const Color glassSurfaceHoverLight = Color(0xFFFFFFFF);
  static const Color glassBorderLightMode = Color(0xFFE2E8F0);
  static const Color glassBorderLightHover = Color(0xFFCBD5E1);
  static const Color glassHighlightLight = Color(0x33FFFFFF);
  static const Color cardShadowLight = Color(0x0F0F172A);
  static const Color navBarBackgroundLight = Color(0xF2FFFFFF);

  static const Color safeGreen = Color(0xFF10B981);
  static const Color safeGreenGlow = Color(0x4010B981);
  static const Color cautionAmber = Color(0xFFF59E0B);
  static const Color cautionAmberGlow = Color(0x40F59E0B);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color dangerRedGlow = Color(0x40EF4444);

  static const Color weatherBlue = Color(0xFF3B82F6);
  static const Color weatherBlueLight = Color(0xFF2563EB);
  static const Color floodOrange = Color(0xFFF97316);
  static const Color airQualityCyan = Color(0xFF06B6D4);
  static const Color uvPurple = Color(0xFF8B5CF6);

  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDark = Color(0xFF111827);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentCyanLight = Color(0xFF0284C7);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? textPrimary : textPrimaryLight;

  static Color secondaryText(BuildContext context) =>
      isDark(context) ? textSecondary : textSecondaryLight;

  static Color mutedText(BuildContext context) =>
      isDark(context) ? textMuted : textMutedLight;

  static Color cardBg(BuildContext context) =>
      isDark(context) ? backgroundCardDark : backgroundCardLight;

  static Color surfaceGlass(BuildContext context) =>
      isDark(context) ? glassSurface : glassSurfaceLight;

  static Color borderGlass(BuildContext context) =>
      isDark(context) ? glassBorder : glassBorderLightMode;

  static Color cyanAccent(BuildContext context) =>
      isDark(context) ? accentCyan : accentCyanLight;

  static Color blueAccent(BuildContext context) =>
      isDark(context) ? weatherBlue : weatherBlueLight;

  static Color scaffoldBg(BuildContext context) =>
      isDark(context) ? backgroundDark : backgroundLight;

  static Color gradientStart(BuildContext context) =>
      isDark(context) ? backgroundGradientStart : backgroundGradientStartLight;

  static Color gradientEnd(BuildContext context) =>
      isDark(context) ? backgroundGradientEnd : backgroundGradientEndLight;

  static Color navBarBg(BuildContext context) =>
      isDark(context) ? navBarBackground : navBarBackgroundLight;

  static Color inputFill(BuildContext context) =>
      isDark(context) ? backgroundCardDark : const Color(0xFFF8FAFC);

  static Color inputBorder(BuildContext context) =>
      isDark(context) ? glassBorderLight : const Color(0xFFCBD5E1);

  static Color dividerColor(BuildContext context) =>
      isDark(context) ? glassBorder : glassBorderLightMode;

  static Color chipBg(BuildContext context) =>
      isDark(context) ? glassSurface : const Color(0xFFE2E8F0);

  static Color chipBorder(BuildContext context) =>
      isDark(context) ? glassBorder : const Color(0xFFCBD5E1);

  static Color iconOnSurface(BuildContext context) =>
      isDark(context) ? textPrimary : textPrimaryLight;

  static Color iconMuted(BuildContext context) =>
      isDark(context) ? textMuted : textMutedLight;
}
