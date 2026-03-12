import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/auth/auth_session.dart';
import '../core/auth/google_federated_auth_service.dart';
import '../core/config/app_config.dart';
import '../core/l10n/app_strings.dart';
import '../core/models/models.dart';
import '../core/network/api_client.dart';
import '../core/network/auth_api_client.dart';
import '../core/security/dm_e2ee_service.dart';
import '../core/settings/app_settings.dart';
import '../core/telemetry/product_analytics.dart';
import '../features/quests/quest_repository.dart';
import 'auth_controller.dart';
import 'settings_controller.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
      final storage = ref.watch(secureStorageProvider);
      return SettingsController(storage: storage);
    });

final appSettingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsControllerProvider);
});

final appStringsProvider = Provider<AppStrings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return AppStrings(settings.language);
});

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return AuthApiClient(baseUrl: config.apiBaseUrl);
});

final googleFederatedAuthServiceProvider = Provider<GoogleFederatedAuthService>(
  (ref) => const GoogleFederatedAuthService(),
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>((ref) {
      final authApi = ref.watch(authApiClientProvider);
      final storage = ref.watch(secureStorageProvider);
      final googleAuth = ref.watch(googleFederatedAuthServiceProvider);
      return AuthController(
        authApi: authApi,
        storage: storage,
        googleAuth: googleAuth,
      );
    });

final authSessionProvider = Provider<AuthSession?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.maybeWhen(data: (session) => session, orElse: () => null);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final authSession = ref.watch(authSessionProvider);
  return ApiClient(
    baseUrl: config.apiBaseUrl,
    authSession: authSession,
    authSessionResolver: () => ref.read(authSessionProvider),
    onUnauthorizedRecover: () =>
        ref.read(authControllerProvider.notifier).recoverSession(),
  );
});

final dmE2eeServiceProvider = Provider<DmE2eeService>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return DmE2eeService(api: api, store: FlutterDmSecureStore(storage));
});

final productAnalyticsProvider = Provider<ProductAnalytics>((ref) {
  final api = ref.watch(apiClientProvider);
  final config = ref.watch(appConfigProvider);
  final settings = ref.watch(appSettingsProvider);
  return ProductAnalytics(
    api: api,
    environment: config.environment,
    language: settings.language,
  );
});

final questRepositoryProvider = Provider<QuestRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return QuestRepository(api);
});

final dmSmokeMediaUploadProvider = Provider<MediaUpload?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.smokeMediaUploadsEnabled) {
    return null;
  }
  return MediaUpload(
    filename: 'dm-smoke-upload-fixture.png',
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+y0n8AAAAASUVORK5CYII=',
    ),
    mimeType: 'image/png',
  );
});
