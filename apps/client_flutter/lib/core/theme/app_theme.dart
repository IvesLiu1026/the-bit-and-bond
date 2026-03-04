import 'package:flutter/material.dart';

import 'app_colors.dart';

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
      scaffoldBackgroundColor: AppColors.parchment,
      fontFamily: 'Nunito',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w900,
          fontSize: 34,
        ),
        headlineMedium: TextStyle(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w900,
          fontSize: 28,
        ),
        displayLarge: TextStyle(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w900,
          fontSize: 32,
        ),
        titleLarge: TextStyle(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w900,
          fontSize: 24,
        ),
        titleMedium: TextStyle(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
        bodyLarge: TextStyle(
          color: AppColors.inkBrown,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: AppColors.inkBrown,
          fontSize: 14,
          fontWeight: FontWeight.w500,
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
          foregroundColor: const WidgetStatePropertyAll(Color(0xFFF7F3E9)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final pressed =
                states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.disabled);
            if (pressed) {
              return AppColors.submitGreenEdge;
            }
            return AppColors.submitGreen;
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
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
        labelStyle: const TextStyle(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w800,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.inkBrown),
        titleTextStyle: TextStyle(
          color: AppColors.inkBrown,
          fontFamily: 'Nunito',
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.woodFrame,
        thickness: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.inkBrown,
        contentTextStyle: const TextStyle(
          color: Color(0xFFF8F3E8),
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.woodFrame, width: 2),
        ),
      ),
    );
  }
}
