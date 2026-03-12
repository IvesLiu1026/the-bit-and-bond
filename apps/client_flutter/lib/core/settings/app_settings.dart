import 'dart:convert';

import 'package:flutter/material.dart';

enum AppLanguage {
  traditionalChinese('zh-Hant', Locale('zh', 'TW')),
  english('en', Locale('en'));

  const AppLanguage(this.storageValue, this.locale);

  final String storageValue;
  final Locale locale;

  static AppLanguage fromStorage(String? raw) {
    return AppLanguage.values.firstWhere(
      (candidate) => candidate.storageValue == raw,
      orElse: () => AppLanguage.traditionalChinese,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.language,
    required this.soundEffectsEnabled,
    required this.musicEnabled,
    required this.hapticsEnabled,
    required this.uiScale,
    required this.pixelFxEnabled,
    required this.pixelFontEnabled,
  });

  static const double minUiScale = 0.9;
  static const double maxUiScale = 1.15;

  static const AppSettings defaults = AppSettings(
    language: AppLanguage.traditionalChinese,
    soundEffectsEnabled: true,
    musicEnabled: true,
    hapticsEnabled: true,
    uiScale: 1.0,
    pixelFxEnabled: true,
    pixelFontEnabled: true,
  );

  final AppLanguage language;
  final bool soundEffectsEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;
  final double uiScale;
  final bool pixelFxEnabled;
  final bool pixelFontEnabled;

  Locale get locale => language.locale;

  AppSettings copyWith({
    AppLanguage? language,
    bool? soundEffectsEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    double? uiScale,
    bool? pixelFxEnabled,
    bool? pixelFontEnabled,
  }) {
    return AppSettings(
      language: language ?? this.language,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      uiScale: (uiScale ?? this.uiScale).clamp(minUiScale, maxUiScale),
      pixelFxEnabled: pixelFxEnabled ?? this.pixelFxEnabled,
      pixelFontEnabled: pixelFontEnabled ?? this.pixelFontEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'language': language.storageValue,
      'sound_effects_enabled': soundEffectsEnabled,
      'music_enabled': musicEnabled,
      'haptics_enabled': hapticsEnabled,
      'ui_scale': uiScale,
      'pixel_fx_enabled': pixelFxEnabled,
      'pixel_font_enabled': pixelFontEnabled,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      language: AppLanguage.fromStorage(json['language'] as String?),
      soundEffectsEnabled:
          json['sound_effects_enabled'] as bool? ??
          AppSettings.defaults.soundEffectsEnabled,
      musicEnabled:
          json['music_enabled'] as bool? ?? AppSettings.defaults.musicEnabled,
      hapticsEnabled:
          json['haptics_enabled'] as bool? ??
          AppSettings.defaults.hapticsEnabled,
      uiScale:
          (json['ui_scale'] as num?)?.toDouble() ??
          AppSettings.defaults.uiScale,
      pixelFxEnabled:
          json['pixel_fx_enabled'] as bool? ??
          AppSettings.defaults.pixelFxEnabled,
      pixelFontEnabled:
          json['pixel_font_enabled'] as bool? ??
          AppSettings.defaults.pixelFontEnabled,
    );
  }

  String encode() => jsonEncode(toJson());

  factory AppSettings.decode(String raw) {
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
