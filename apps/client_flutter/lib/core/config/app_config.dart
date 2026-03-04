import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.lowFxMode});

  final String apiBaseUrl;
  final bool lowFxMode;

  static AppConfig fromEnvironment() {
    const apiBaseUrlFromEnv = String.fromEnvironment('API_BASE_URL');
    const lowFxFromEnv = String.fromEnvironment(
      'LOW_FX',
      defaultValue: 'false',
    );

    return AppConfig(
      apiBaseUrl: apiBaseUrlFromEnv.isEmpty
          ? _defaultApiBaseUrl()
          : apiBaseUrlFromEnv,
      lowFxMode: _parseBool(lowFxFromEnv),
    );
  }

  static bool _parseBool(String raw) {
    switch (raw.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'on':
        return true;
      default:
        return false;
    }
  }

  static String _defaultApiBaseUrl() {
    if (kIsWeb) {
      final host = Uri.base.host;
      return '${Uri.base.scheme}://$host:18080';
    }
    return 'http://127.0.0.1:18080';
  }
}
