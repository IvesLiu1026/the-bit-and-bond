import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/settings/app_settings.dart';

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController({
    required FlutterSecureStorage storage,
    bool restoreOnInit = true,
  }) : _storage = storage,
       super(AppSettings.defaults) {
    if (restoreOnInit) {
      _restore();
    }
  }

  static const String storageKey = 'the_bit_and_bond_settings_v1';

  final FlutterSecureStorage _storage;

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      state = AppSettings.decode(raw);
    } catch (_) {
      state = AppSettings.defaults;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    await _persist();
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    state = state.copyWith(soundEffectsEnabled: value);
    await _persist();
  }

  Future<void> setMusicEnabled(bool value) async {
    state = state.copyWith(musicEnabled: value);
    await _persist();
  }

  Future<void> setHapticsEnabled(bool value) async {
    state = state.copyWith(hapticsEnabled: value);
    await _persist();
  }

  Future<void> setUiScale(double value) async {
    state = state.copyWith(uiScale: value);
    await _persist();
  }

  Future<void> setPixelFxEnabled(bool value) async {
    state = state.copyWith(pixelFxEnabled: value);
    await _persist();
  }

  Future<void> _persist() async {
    await _storage.write(key: storageKey, value: state.encode());
  }
}
