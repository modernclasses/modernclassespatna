import 'package:flutter/material.dart';

/// Design Token Colors for Modern Classes Patna.
/// Premium Academic Editorial Palette:
/// - Warm ivory & crisp parchment surfaces
/// - Deep ink & slate navy for structure and authoritative typography
/// - Controlled saffron & warm amber for primary emphasis and progress
/// - Dignified, low-glare semantic status indicators
class AppColors {
  AppColors._();

  // Primary Accent: Controlled Academic Saffron & Amber
  static const Color primary = Color(0xFFD97706); // Amber 600 - Rich Saffron
  static const Color primaryDark = Color(
    0xFFB45309,
  ); // Amber 700 - Deep Pressed Accent
  static const Color primaryLight = Color(
    0xFFFDE68A,
  ); // Amber 200 - Soft Accent Highlight
  static const Color saffronMuted = Color(
    0xFFFFFBEB,
  ); // Amber 50 - Subtle Saffron Tint
  static const Color saffronBorder = Color(
    0xFFFCD34D,
  ); // Amber 300 - Hairline Accent

  // Secondary Accent: Oxford / Academic Navy
  static const Color secondary = Color(0xFF1E3A8A); // Deep Blue 900
  static const Color secondaryLight = Color(0xFF2563EB); // Royal Blue 600
  static const Color secondaryMuted = Color(0xFFEFF6FF); // Soft Blue Tint

  // Structural Deep Ink (Authoritative Foundation)
  static const Color deepInk = Color(0xFF0F172A); // Slate 900 - Deepest Ink
  static const Color deepInkMedium = Color(
    0xFF1E293B,
  ); // Slate 800 - Header Structure
  static const Color deepInkLight = Color(
    0xFF334155,
  ); // Slate 700 - Sub-structural

  // Academic Surfaces (Light / Warm Ivory Canvas)
  static const Color warmIvory = Color(0xFFF8F7F4); // Archival Ivory Canvas
  static const Color surface = Color(0xFFFFFFFF); // Crisp White Surface / Card
  static const Color surfaceCard = Color(0xFFFFFFFF); // Card Surface
  static const Color surfaceSubtle = Color(0xFFF3EFEA); // Warm Parchment Inset
  static const Color surfaceElevated = Color(
    0xFFEDE9E1,
  ); // Elevated Neutral Panel

  // Borders & Hairlines
  static const Color border = Color(0xFFE2DDD5); // Subtle Warm Stone Border
  static const Color borderSubtle = Color(0xFFEFECE6); // Whisper Hairline
  static const Color divider = Color(0xFFE5E0D7); // Editorial Divider

  // Typography Colors (High-Contrast Academic Readability)
  static const Color textPrimary = Color(
    0xFF0F172A,
  ); // Deep Ink for Maximum Contrast
  static const Color textSecondary = Color(
    0xFF475569,
  ); // Slate 600 - Secondary Editorial
  static const Color textMuted = Color(
    0xFF64748B,
  ); // Slate 500 - Meta, Captions, Dates
  static const Color textInverse = Color(
    0xFFF8FAFC,
  ); // White / Light on Dark elements

  // Semantic Status Colors (Disciplined, Dignified, Non-glaring)
  static const Color success = Color(0xFF15803D); // Forest Emerald 700
  static const Color successBg = Color(0xFFF0FDF4); // Soft Green Tint
  static const Color successBorder = Color(0xFFBBF7D0); // Green 200

  static const Color warning = Color(0xFFB45309); // Warm Ochre / Amber 700
  static const Color warningBg = Color(0xFFFFFBEB); // Soft Amber Tint
  static const Color warningBorder = Color(0xFFFDE68A); // Amber 200

  static const Color error = Color(
    0xFFBE123C,
  ); // Crimson Rose 700 - Dignified Alert
  static const Color errorBg = Color(0xFFFFF1F2); // Soft Crimson Tint
  static const Color errorBorder = Color(0xFFFECDD3); // Crimson 200

  static const Color info = Color(0xFF0369A1); // Deep Cerulean Sky 700
  static const Color infoBg = Color(0xFFF0F9FF); // Soft Sky Tint
  static const Color infoBorder = Color(0xFFBAE6FD); // Sky 200

  static const Color purple = Color(0xFF6D28D9); // Academic Violet 700
  static const Color purpleBg = Color(0xFFF5F3FF); // Soft Violet Tint
  static const Color purpleBorder = Color(0xFFDDD6FE); // Violet 200

  // Shimmer / Placeholder Skeleton Colors
  static const Color shimmerBase = Color(0xFFEFECE6);
  static const Color shimmerHighlight = Color(0xFFF9F8F5);

  // Convenience aliases for academic editorial design
  static const Color saffron = primary;
  static const Color saffronDark = primaryDark;
  static const Color emerald = success;
  static const Color emeraldBg = successBg;
  static const Color emeraldBorder = successBorder;
  static const Color amber = warning;
  static const Color amberBg = warningBg;
  static const Color amberBorder = warningBorder;
  static const Color surfaceMuted = surfaceSubtle;

  // Dark palette constants for Night Reading Mode
  static const Color darkBackground = Color(0xFF0B101D);
  static const Color darkSurface = Color(0xFF121A2B);
  static const Color darkSurfaceCard = Color(0xFF18233A);
  static const Color darkBorder = Color(0xFF23324C);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Background aliases for compatibility
  static const Color background = warmIvory;

  // Theme-aware Context Helpers
  static Color surfaceFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : surface;

  static Color cardSurfaceFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkSurfaceCard
      : surfaceCard;

  static Color canvasFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkBackground
      : warmIvory;

  static Color borderFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : border;

  static Color textPrimaryFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextPrimary
      : textPrimary;

  static Color textSecondaryFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextSecondary
      : textSecondary;

  static Color textMutedFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextMuted
      : textMuted;

  static Color surfaceSubtleFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkSurface
      : surfaceSubtle;

  static Color saffronBgFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? primary.withValues(alpha: 0.18)
      : saffronMuted;

  static Color errorBgFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? error.withValues(alpha: 0.18)
      : errorBg;

  static Color successBgFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? success.withValues(alpha: 0.18)
      : successBg;

  static Color purpleBgFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? purple.withValues(alpha: 0.18)
      : purpleBg;

  static Color secondaryBgFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? secondaryLight.withValues(alpha: 0.18)
      : secondaryMuted;

  static Color warningBgFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? warning.withValues(alpha: 0.18)
      : warningBg;
}
