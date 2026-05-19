import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Audesiq typography system.
/// Montserrat = brand / headings · Open Sans = body / long copy.
abstract final class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.montserrat(
        fontSize: 32, fontWeight: FontWeight.w700, height: 1.25,
        color: AppColors.primary, letterSpacing: -0.5);

  static TextStyle get headingLarge => GoogleFonts.montserrat(
        fontSize: 24, fontWeight: FontWeight.w600, height: 1.25,
        color: AppColors.textPrimary);

  static TextStyle get titleLarge => GoogleFonts.montserrat(
        fontSize: 18, fontWeight: FontWeight.w600, height: 1.33,
        color: AppColors.textPrimary);

  static TextStyle get playerTitle => GoogleFonts.montserrat(
        fontSize: 24, fontWeight: FontWeight.w600, height: 1.25,
        color: AppColors.textPrimary);

  static TextStyle get bodyLarge => GoogleFonts.openSans(
        fontSize: 16, fontWeight: FontWeight.w400, height: 1.375,
        color: AppColors.textPrimary);

  static TextStyle get bodyLargeSecondary => GoogleFonts.openSans(
        fontSize: 16, fontWeight: FontWeight.w400, height: 1.375,
        color: AppColors.textSecondary);

  static TextStyle get subhead => GoogleFonts.montserrat(
        fontSize: 14, fontWeight: FontWeight.w500, height: 1.43,
        color: AppColors.textSecondary);

  /// Default CC / subtitle text — 24sp SemiBold.
  static TextStyle get subtitle => GoogleFonts.montserrat(
        fontSize: 24, fontWeight: FontWeight.w600, height: 1.42,
        color: AppColors.textPrimary);

  static TextStyle get subtitleLarge => GoogleFonts.montserrat(
        fontSize: 28, fontWeight: FontWeight.w600, height: 1.43,
        color: AppColors.textPrimary);

  static TextStyle get subtitleXL => GoogleFonts.montserrat(
        fontSize: 32, fontWeight: FontWeight.w600, height: 1.375,
        color: AppColors.textPrimary);

  static TextStyle get badge => GoogleFonts.montserrat(
        fontSize: 12, fontWeight: FontWeight.w600, height: 1.33,
        color: AppColors.surface, letterSpacing: 0.3);

  static TextStyle get button => GoogleFonts.montserrat(
        fontSize: 16, fontWeight: FontWeight.w600, height: 1.25,
        color: AppColors.surface, letterSpacing: 0.2);

  static TextStyle get buttonSmall => GoogleFonts.montserrat(
        fontSize: 14, fontWeight: FontWeight.w600, height: 1.25,
        color: AppColors.surface);

  static TextStyle get searchPlaceholder => GoogleFonts.openSans(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: AppColors.textSecondary);

  static TextStyle get timestamp => GoogleFonts.montserrat(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: AppColors.textSecondary);

  static TextStyle get navLabel => GoogleFonts.montserrat(
        fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3);
}

TextTheme buildTextTheme() => TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      headlineLarge: AppTextStyles.headingLarge,
      headlineMedium: AppTextStyles.titleLarge,
      titleLarge: AppTextStyles.playerTitle,
      titleMedium: AppTextStyles.subhead,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyLargeSecondary,
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.buttonSmall,
      labelSmall: AppTextStyles.badge,
    );

