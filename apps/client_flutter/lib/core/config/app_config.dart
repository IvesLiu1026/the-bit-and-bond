import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.lowFxMode});

  final String apiBaseUrl;
  final bool lowFxMode;

  static AppConfig fromEnvironment() {
    const apiBaseUrlFromEnv = String.fromEnvironment('API_BASE_URL');
    const mobileApiBaseUrlFromEnv = String.fromEnvironment(
      'MOBILE_API_BASE_URL',
    );
    const lowFxFromEnv = String.fromEnvironment(
      'LOW_FX',
      defaultValue: 'false',
    );

    return AppConfig(
      apiBaseUrl: apiBaseUrlFromEnv.isEmpty
          ? _defaultApiBaseUrl(mobileApiBaseUrlFromEnv)
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

  @visibleForTesting
  static String defaultApiBaseUrlFor({
    required bool isWeb,
    required String webScheme,
    required String webHost,
    int? webPort,
    required TargetPlatform platform,
    String mobileApiBaseUrl = '',
  }) {
    if (isWeb) {
      // In production/tunnel deployments we want same-origin API calls so that
      // web + API can be reverse-proxied under one host (e.g. ngrok).
      if (webPort != null && webPort > 0) {
        if (webPort == 18081) {
          return '$webScheme://$webHost:18080';
        }
        return '$webScheme://$webHost:$webPort';
      }
      return '$webScheme://$webHost';
    }

    final normalizedMobileBaseUrl = mobileApiBaseUrl.trim();
    if (normalizedMobileBaseUrl.isNotEmpty) {
      return normalizedMobileBaseUrl;
    }

    return switch (platform) {
      TargetPlatform.android => 'http://10.0.2.2:18080',
      _ => 'http://127.0.0.1:18080',
    };
  }

  static String _defaultApiBaseUrl(String mobileApiBaseUrl) {
    final uri = Uri.base;
    return defaultApiBaseUrlFor(
      isWeb: kIsWeb,
      webScheme: uri.scheme,
      webHost: uri.host,
      webPort: uri.hasPort ? uri.port : null,
      platform: defaultTargetPlatform,
      mobileApiBaseUrl: mobileApiBaseUrl,
    );
  }
}
