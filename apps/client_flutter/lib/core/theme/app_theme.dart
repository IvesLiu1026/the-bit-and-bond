import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'pixel_typography.dart';

class AppTheme {
  static ThemeData get cozyGuildTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.apSapphire,
      brightness: Brightness.light,
      surface: AppColors.parchment,
      primary: AppColors.apSapphire,
      secondary: AppColors.stampGreen,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamilyFallback: PixelTypography.fallback,
      scaffoldBackgroundColor: AppColors.parchment,
      fontFamily: PixelTypography.family,
      textTheme: TextTheme(
        headlineLarge: PixelTypography.style(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w900,
          fontSize: 30,
          height: 1.05,
        ),
        headlineMedium: PixelTypography.style(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w900,
          fontSize: 26,
          height: 1.08,
        ),
        displayLarge: PixelTypography.style(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w900,
          fontSize: 28,
          height: 1.08,
        ),
        titleLarge: PixelTypography.style(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          height: 1.08,
        ),
        titleMedium: PixelTypography.style(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w800,
          fontSize: 16,
          height: 1.12,
        ),
        bodyLarge: PixelTypography.style(
          color: AppColors.inkBrown,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        bodyMedium: PixelTypography.style(
          color: AppColors.inkBrown,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.22,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.parchment,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.woodFrame, width: 3.0),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
          foregroundColor: const WidgetStatePropertyAll(AppColors.inkBrown),
          textStyle: WidgetStatePropertyAll(
            PixelTypography.style(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              height: 1,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final pressed =
                states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.disabled);
            if (pressed) {
              return const Color(0xFF9BCB91);
            }
            return const Color(0xFFAED49A);
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(
                color: AppColors.submitGreenEdge,
                width: 2,
              ),
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkBrown,
          side: const BorderSide(color: AppColors.woodFrame, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: PixelTypography.style(
            color: AppColors.inkBrown,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            height: 1,
          ),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.woodFrame, width: 2),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          foregroundColor: const WidgetStatePropertyAll(AppColors.inkBrown),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFE4D5B8);
            }
            return const Color(0xFFF4ECE1);
          }),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFFECE2D0),
        side: const BorderSide(color: AppColors.woodFrame, width: 1.6),
        labelStyle: PixelTypography.style(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          height: 1,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.inkBrown),
        titleTextStyle: PixelTypography.style(
          color: AppColors.inkBrown,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.woodFrame,
        thickness: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFF3E8CC),
        contentTextStyle: PixelTypography.style(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          height: 1.15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.woodFrame, width: 2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0E5CF),
        labelStyle: PixelTypography.style(
          color: AppColors.inkBrown.withValues(alpha: 0.82),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: PixelTypography.style(
          color: AppColors.inkBrown.withValues(alpha: 0.58),
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.woodFrame, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.woodFrame, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.apSapphire, width: 2),
        ),
      ),
    );
  }
}
