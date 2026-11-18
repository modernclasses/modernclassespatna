import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Premium Academic Editorial Typography Scale for Modern Classes Patna.
/// Combines authoritative screen titles with crisp, high-legibility body text
/// and tabular numerical styles for scores, metrics, and fees.
class AppTypography {
  AppTypography._();

  /// Primary Display Headings (Screen Heroes & Announcements)
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  /// Editorial Section Headings
  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static TextStyle get titleSmall => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// High-Legibility Editorial Body
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.45,
  );

  /// Action & Component Labels
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.textPrimary,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.textMuted,
  );

  /// Tabular Numerical Figures (Ranks, Scores, Percentiles, Fees)
  static TextStyle get statValue => GoogleFonts.plusJakartaSans(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static TextStyle get statLabel => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: AppColors.textMuted,
  );

  /// Editorial Eyebrow Tag (Small uppercase header above titles)
  static TextStyle get eyebrow => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: AppColors.primaryDark,
  );

  // Convenience aliases for backward and cross-component compatibility
  static TextStyle get caption => bodySmall;
  static TextStyle get subtitle1 => titleMedium;
  static TextStyle get subtitle2 => titleSmall;
  static TextStyle get button => labelLarge;
  static TextStyle get statLarge => statValue;
}
