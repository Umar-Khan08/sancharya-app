import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// SANCHARYA Material 3 Design System
/// Specially crafted for farmer legibility, high contrast in sunlight,
/// large accessible touch targets, and clean agricultural aesthetics.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryGreen,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.primaryGreenLight.withAlpha(45),
      onPrimaryContainer: AppColors.primaryGreenDark,
      secondary: AppColors.resourceBlue,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.resourceBlueLight,
      onSecondaryContainer: AppColors.resourceBlue,
      tertiary: AppColors.accentYellowDark,
      onTertiary: AppColors.textDark,
      tertiaryContainer: AppColors.accentYellowLight,
      onTertiaryContainer: AppColors.deepGreen,
      error: AppColors.riskHigh,
      onError: AppColors.white,
      errorContainer: AppColors.riskHighBg,
      onErrorContainer: AppColors.riskHigh,
      surface: AppColors.white,
      onSurface: AppColors.textDark,
      surfaceContainerHighest: AppColors.surfaceMuted,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      fontFamily: null, // Uses default clean Android system font (Roboto) with crisp Hindi (Devanagari) rendering
      
      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(
          color: AppColors.deepGreen,
          size: 24,
        ),
      ),

      // Card Theme with soft shadows and rounded corners
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 1.5,
        shadowColor: AppColors.deepGreen.withAlpha(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.borderLight,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button Theme (Primary & Yellow CTAs)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 1.5,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.riskHigh, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.riskHigh, width: 2),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Typography
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textDark,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textDark,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.25,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        titleMedium: TextStyle(
          color: AppColors.textDark,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        titleSmall: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textDark,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: AppColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Navigation Bar (Bottom Navigation)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.primaryGreenLight.withAlpha(50),
        elevation: 3,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryGreen, size: 24);
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 24);
        }),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 24,
      ),
    );
  }
}
