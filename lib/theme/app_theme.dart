import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color navy = Color(0xFF001E40);
  static const Color deepSeaBlue = Color(0xFF003366);
  static const Color actionBlue = Color(0xFF1F477B);
  static const Color background = Color(0xFFF9FAFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceBlue = Color(0xFFF0F3FF);
  static const Color surfaceBlueStrong = Color(0xFFE2E8F8);
  static const Color border = Color(0xFFC3C6D1);
  static const Color textPrimary = Color(0xFF151C27);
  static const Color textSecondary = Color(0xFF43474F);
  static const Color ready = Color(0xFF2E7D32);
  static const Color readySurface = Color(0xFFE7F5E8);
  static const Color offDuty = Color(0xFF6B7280);
  static const Color offDutySurface = Color(0xFFF0F1F3);
  static const Color delayed = Color(0xFFB45309);
  static const Color delayedSurface = Color(0xFFFFF3D6);
  static const Color activeCallout = Color(0xFFC8171E);
  static const Color activeCalloutSurface = Color(0xFFFFE1DE);
  static const Color equipmentWarning = Color(0xFFD97706);
  static const Color equipmentWarningSurface = Color(0xFFFFF1D6);
  static const Color critical = Color(0xFFB91C1C);
  static const Color criticalSurface = Color(0xFFFFDAD6);
}

abstract final class AppTheme {
  static const double screenPadding = 16;
  static const double sectionSpacing = 24;
  static const double itemSpacing = 12;
  static const double cardRadius = 16;
  static const double controlRadius = 8;
  static const double minimumTouchTarget = 48;
  static const double primaryActionHeight = 56;

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.deepSeaBlue,
      onPrimary: Colors.white,
      primaryContainer: AppColors.surfaceBlueStrong,
      onPrimaryContainer: AppColors.navy,
      secondary: Color(0xFF526069),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD3E2ED),
      onSecondaryContainer: Color(0xFF0F1D25),
      tertiary: AppColors.ready,
      onTertiary: Colors.white,
      error: AppColors.critical,
      onError: Colors.white,
      errorContainer: AppColors.criticalSurface,
      onErrorContainer: Color(0xFF93000A),
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: Color(0xFF737780),
      outlineVariant: AppColors.border,
      shadow: Color(0x14001E40),
    );

    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        height: 1.33,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.42,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        height: 1.42,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        height: 1.33,
        fontWeight: FontWeight.w700,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.navy,
          fontSize: 20,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.navy),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
        shadowColor: const Color(0x14001E40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(
            color: AppColors.deepSeaBlue,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, minimumTouchTarget),
          backgroundColor: AppColors.deepSeaBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceBlueStrong,
          disabledForegroundColor: AppColors.offDuty,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, minimumTouchTarget),
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.deepSeaBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, minimumTouchTarget),
          foregroundColor: AppColors.deepSeaBlue,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.deepSeaBlue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.deepSeaBlue,
      ),
    );
  }
}
