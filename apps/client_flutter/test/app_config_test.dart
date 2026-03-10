import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:the_bit_and_bond_client/core/config/app_config.dart';

void main() {
  test('web default api base url follows current host/port', () {
    final sameOrigin = AppConfig.defaultApiBaseUrlFor(
      isWeb: true,
      webScheme: 'https',
      webHost: 'example.com',
      webPort: 443,
      platform: TargetPlatform.android,
    );
    expect(sameOrigin, 'https://example.com:443');

    final proxiedLocal = AppConfig.defaultApiBaseUrlFor(
      isWeb: true,
      webScheme: 'http',
      webHost: '127.0.0.1',
      webPort: 18081,
      platform: TargetPlatform.android,
    );
    expect(proxiedLocal, 'http://127.0.0.1:18080');

    final url = AppConfig.defaultApiBaseUrlFor(
      isWeb: true,
      webScheme: 'https',
      webHost: 'example.com',
      platform: TargetPlatform.android,
    );

    expect(url, 'https://example.com');
  });

  test('mobile override wins on native targets', () {
    final url = AppConfig.defaultApiBaseUrlFor(
      isWeb: false,
      webScheme: 'http',
      webHost: 'localhost',
      platform: TargetPlatform.iOS,
      mobileApiBaseUrl: 'http://192.168.123.88:18080',
    );

    expect(url, 'http://192.168.123.88:18080');
  });

  test('android native fallback uses emulator loopback', () {
    final url = AppConfig.defaultApiBaseUrlFor(
      isWeb: false,
      webScheme: 'http',
      webHost: 'localhost',
      platform: TargetPlatform.android,
    );

    expect(url, 'http://10.0.2.2:18080');
  });

  test('non-android native fallback uses localhost', () {
    final url = AppConfig.defaultApiBaseUrlFor(
      isWeb: false,
      webScheme: 'http',
      webHost: 'localhost',
      platform: TargetPlatform.iOS,
    );

    expect(url, 'http://127.0.0.1:18080');
  });

  test('app environment parser supports local staging production', () {
    expect(AppConfig.parseEnvironment('local'), AppEnvironment.local);
    expect(AppConfig.parseEnvironment('staging'), AppEnvironment.staging);
    expect(AppConfig.parseEnvironment('stage'), AppEnvironment.staging);
    expect(AppConfig.parseEnvironment('production'), AppEnvironment.production);
    expect(AppConfig.parseEnvironment('prod'), AppEnvironment.production);
    expect(AppConfig.parseEnvironment('unknown'), AppEnvironment.local);
  });

  test('env specific api base urls are applied when present', () {
    final staging = AppConfig.resolveApiBaseUrlFor(
      apiBaseUrlFromEnv: '',
      mobileApiBaseUrlFromEnv: '',
      stagingApiBaseUrlFromEnv: 'https://staging.api.bitbond.app',
      productionApiBaseUrlFromEnv: 'https://api.bitbond.app',
      environment: AppEnvironment.staging,
    );
    final production = AppConfig.resolveApiBaseUrlFor(
      apiBaseUrlFromEnv: '',
      mobileApiBaseUrlFromEnv: '',
      stagingApiBaseUrlFromEnv: 'https://staging.api.bitbond.app',
      productionApiBaseUrlFromEnv: 'https://api.bitbond.app',
      environment: AppEnvironment.production,
    );

    expect(staging, 'https://staging.api.bitbond.app');
    expect(production, 'https://api.bitbond.app');
  });

  test('explicit API_BASE_URL has highest priority', () {
    final url = AppConfig.resolveApiBaseUrlFor(
      apiBaseUrlFromEnv: 'https://override.bitbond.app',
      mobileApiBaseUrlFromEnv: 'http://192.168.0.1:18080',
      stagingApiBaseUrlFromEnv: 'https://staging.api.bitbond.app',
      productionApiBaseUrlFromEnv: 'https://api.bitbond.app',
      environment: AppEnvironment.production,
    );

    expect(url, 'https://override.bitbond.app');
  });
}
