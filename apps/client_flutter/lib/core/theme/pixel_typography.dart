import 'package:flutter/material.dart';

class PixelTypography {
  static const String family = 'FusionPixelZhHant';
  static const List<String> fallback = <String>['Nunito'];
  static const String nonPixelFamily = 'Nunito';
  static const Color defaultColor = Color(0xFF130E0C);
  static bool _pixelModeEnabled = true;

  static bool get pixelModeEnabled => _pixelModeEnabled;

  static void setPixelMode(bool enabled) {
    _pixelModeEnabled = enabled;
  }

  static TextStyle style({
    Color? color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    double height = 1.15,
    double letterSpacing = 0,
    bool? pixelModeEnabled,
  }) {
    final usePixel = pixelModeEnabled ?? _pixelModeEnabled;
    return TextStyle(
      fontFamily: usePixel ? family : nonPixelFamily,
      fontFamilyFallback: usePixel ? fallback : null,
      color: color ?? defaultColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
