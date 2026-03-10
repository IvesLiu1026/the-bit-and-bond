import 'package:flutter/foundation.dart';

enum AppEnvironment { local, staging, production }

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.lowFxMode,
    required this.environment,
  });

  final String apiBaseUrl;
  final bool lowFxMode;
  final AppEnvironment environment;

  static AppConfig fromEnvironment() {
    const apiBaseUrlFromEnv = String.fromEnvironment('API_BASE_URL');
    const mobileApiBaseUrlFromEnv = String.fromEnvironment(
      'MOBILE_API_BASE_URL',
    );
    const stagingApiBaseUrlFromEnv = String.fromEnvironment(
      'STAGING_API_BASE_URL',
    );
    const productionApiBaseUrlFromEnv = String.fromEnvironment(
      'PRODUCTION_API_BASE_URL',
    );
    const appEnvironmentRaw = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'local',
    );
    const lowFxFromEnv = String.fromEnvironment(
      'LOW_FX',
      defaultValue: 'false',
    );
    final environment = parseEnvironment(appEnvironmentRaw);

    return AppConfig(
      apiBaseUrl: resolveApiBaseUrlFor(
        apiBaseUrlFromEnv: apiBaseUrlFromEnv,
        mobileApiBaseUrlFromEnv: mobileApiBaseUrlFromEnv,
        stagingApiBaseUrlFromEnv: stagingApiBaseUrlFromEnv,
        productionApiBaseUrlFromEnv: productionApiBaseUrlFromEnv,
        environment: environment,
      ),
      lowFxMode: _parseBool(lowFxFromEnv),
      environment: environment,
    );
  }

  @visibleForTesting
  static AppEnvironment parseEnvironment(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.production;
      case 'stage':
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.local;
    }
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
  static String resolveApiBaseUrlFor({
    required String apiBaseUrlFromEnv,
    required String mobileApiBaseUrlFromEnv,
    required String stagingApiBaseUrlFromEnv,
    required String productionApiBaseUrlFromEnv,
    required AppEnvironment environment,
  }) {
    final explicitApiBaseUrl = apiBaseUrlFromEnv.trim();
    if (explicitApiBaseUrl.isNotEmpty) {
      return explicitApiBaseUrl;
    }

    final mobileOverride = mobileApiBaseUrlFromEnv.trim();
    if (!kIsWeb && mobileOverride.isNotEmpty) {
      return mobileOverride;
    }

    final stageOverride = stagingApiBaseUrlFromEnv.trim();
    final productionOverride = productionApiBaseUrlFromEnv.trim();
    if (environment == AppEnvironment.staging && stageOverride.isNotEmpty) {
      return stageOverride;
    }
    if (environment == AppEnvironment.production &&
        productionOverride.isNotEmpty) {
      return productionOverride;
    }

    return _defaultApiBaseUrl(mobileOverride);
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
