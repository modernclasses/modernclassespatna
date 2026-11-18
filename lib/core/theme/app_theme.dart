import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

export '../constants/app_colors.dart';
export '../constants/app_spacing.dart';
export 'app_typography.dart';

class AppTheme {
  // Alias references for backward compatibility
  static const Color background = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color surfaceLight = AppColors.surfaceSubtle;
  static const Color surfaceCard = AppColors.surfaceCard;
  static const Color surfaceElevated = AppColors.surfaceElevated;

  static const Color border = AppColors.border;
  static const Color borderLight = AppColors.borderSubtle;
  static const Color divider = AppColors.divider;

  // Accents
  static const Color primary = AppColors.primary;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color primaryDark = AppColors.primaryDark;

  static const Color secondary = AppColors.secondary;
  static const Color secondaryLight = AppColors.secondaryLight;

  static const Color success = AppColors.success;
  static const Color error = AppColors.error;
  static const Color warning = AppColors.warning;
  static const Color info = AppColors.info;
  static const Color purple = AppColors.purple;

  // Text Colors
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textMuted = AppColors.textMuted;

  /// Premium Academic Editorial Theme (Light Ivory Canvas & Deep Ink Navy Structure)
  static ThemeData get academicTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.warmIvory,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.deepInk,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.6,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
        bodySmall: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
        labelLarge: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.warmIvory,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.deepInk),
        titleTextStyle: TextStyle(
          color: AppColors.deepInk,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 4,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        indicatorColor: AppColors.saffronMuted,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryDark, size: 22);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 22);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.deepInk, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepInk,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepInk,
          side: const BorderSide(color: AppColors.border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.deepInk,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Dark Editorial Theme for night study sessions & comfortable reading
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondaryLight,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        outline: AppColors.darkBorder,
        error: AppColors.error,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onError: Colors.white,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.6,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.darkTextPrimary,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: AppColors.darkTextPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.darkTextSecondary,
          height: 1.45,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 11,
          color: AppColors.darkTextMuted,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.darkTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 4,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        indicatorColor: AppColors.primary.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryLight,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryLight, size: 22);
          }
          return const IconThemeData(color: AppColors.darkTextMuted, size: 22);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(
          color: AppColors.darkTextMuted,
          fontSize: 13,
        ),
        labelStyle: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: 13,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceCard,
        contentTextStyle: TextStyle(color: AppColors.darkTextPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Helper extension on BuildContext for quick theme and mode queries
extension ThemeContextExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Color get surfaceColor => isDarkMode ? AppColors.darkSurface : AppColors.surface;
  Color get cardColor => isDarkMode ? AppColors.darkSurfaceCard : AppColors.surfaceCard;
  Color get canvasColor => isDarkMode ? AppColors.darkBackground : AppColors.warmIvory;
  Color get borderColor => isDarkMode ? AppColors.darkBorder : AppColors.border;
  Color get textPrimaryColor => isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get textSecondaryColor => isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get textMutedColor => isDarkMode ? AppColors.darkTextMuted : AppColors.textMuted;
}
