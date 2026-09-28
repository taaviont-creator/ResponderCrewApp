import 'package:flutter/material.dart';

abstract final class AppColors {
  // Light surfaces and dark text keep operational information readable outdoors.
  static const Color orange = Color(0xFFFF9B3D);
  static const Color navy = Color(0xFF14324F);
  static const Color deepSeaBlue = Color(0xFF155A80);
  static const Color actionBlue = Color(0xFF155A80);
  static const Color background = Color(0xFFF3F6F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceBlue = Color(0xFFEDF3F8);
  static const Color surfaceBlueStrong = Color(0xFFDCE7F0);
  static const Color border = Color(0xFF7C8DA1);
  static const Color textPrimary = Color(0xFF172B3A);
  static const Color textSecondary = Color(0xFF44566A);
  static const Color ready = Color(0xFF176247);
  static const Color readySurface = Color(0xFFE5F4EB);
  static const Color offDuty = Color(0xFF44566A);
  static const Color offDutySurface = Color(0xFFE7EDF3);
  static const Color delayed = Color(0xFF8C3B08);
  static const Color delayedSurface = Color(0xFFFFF0DF);
  static const Color activeCallout = Color(0xFF8C3B08);
  static const Color activeCalloutSurface = Color(0xFFFFF0DF);
  static const Color equipmentWarning = Color(0xFF8C3B08);
  static const Color equipmentWarningSurface = Color(0xFFFFF0DF);
  static const Color critical = Color(0xFFB3261E);
  static const Color criticalSurface = Color(0xFFFDEAE8);
}

abstract final class AppTheme {
  static const double screenPadding = 16;
  static const double sectionSpacing = 24;
  static const double itemSpacing = 12;
  static const double cardRadius = 16;
  static const double controlRadius = 8;
  static const double minimumTouchTarget = 48;
  static const double primaryActionHeight = 56;

  static ThemeData get light => maritime;

  static ThemeData get maritime {
    const colorScheme = ColorScheme.light(
      primary: AppColors.deepSeaBlue,
      onPrimary: AppColors.background,
      primaryContainer: AppColors.surfaceBlueStrong,
      onPrimaryContainer: AppColors.navy,
      secondary: AppColors.orange,
      onSecondary: AppColors.navy,
      secondaryContainer: AppColors.delayedSurface,
      onSecondaryContainer: AppColors.delayed,
      tertiary: AppColors.ready,
      onTertiary: AppColors.background,
      error: AppColors.critical,
      onError: AppColors.background,
      errorContainer: AppColors.criticalSurface,
      onErrorContainer: AppColors.critical,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surfaceBlue,
      surfaceContainerHigh: AppColors.surfaceBlueStrong,
      surfaceContainerHighest: AppColors.surfaceBlueStrong,
      outline: AppColors.border,
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
      brightness: Brightness.light,
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
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
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
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.navy,
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
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.navy,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        actionTextColor: AppColors.orange,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.orange,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.deepSeaBlue,
      ),
    );
  }
}
