import 'package:flutter/material.dart';

class PixelTypography {
  static const String family = 'FusionPixelZhHant';
  static const List<String> fallback = <String>['Nunito'];
  static const Color defaultColor = Color(0xFF130E0C);

  static TextStyle style({
    Color? color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    double height = 1.15,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      color: color ?? defaultColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
