import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../settings/app_settings.dart';

class ProductAnalytics {
  ProductAnalytics({
    required ApiClient api,
    required AppEnvironment environment,
    required AppLanguage language,
  }) : _api = api,
       _environment = environment,
       _language = language;

  final ApiClient _api;
  final AppEnvironment _environment;
  final AppLanguage _language;
  final String _sessionId = const Uuid().v4();

  static const String _source = 'client_flutter';
  static const String _appVersion = String.fromEnvironment(
    'APP_BUILD_VERSION',
    defaultValue: '0.1.0',
  );

  void track(
    String eventName, {
    String status = 'ok',
    Map<String, dynamic> properties = const <String, dynamic>{},
    bool allowPublic = false,
  }) {
    unawaited(
      _send(
        eventName,
        status: status,
        properties: properties,
        allowPublic: allowPublic,
      ),
    );
  }

  Future<void> _send(
    String eventName, {
    required String status,
    required Map<String, dynamic> properties,
    required bool allowPublic,
  }) async {
    try {
      await _api.sendTelemetryEvents(
        events: <TelemetryEventPayload>[
          TelemetryEventPayload(
            eventName: eventName,
            status: status,
            source: _source,
            platform: _platformLabel,
            locale: _localeLabel,
            appVersion: _appVersion,
            sessionId: _sessionId,
            occurredAtMs: DateTime.now().millisecondsSinceEpoch,
            properties: <String, dynamic>{
              ...properties,
              'environment': _environment.name,
            },
          ),
        ],
        allowPublic: allowPublic,
      );
    } catch (_) {
      // Telemetry should never break gameplay or auth flow.
    }
  }

  String get _platformLabel {
    if (kIsWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  String get _localeLabel => switch (_language) {
    AppLanguage.traditionalChinese => 'zh-TW',
    AppLanguage.english => 'en',
  };
}
