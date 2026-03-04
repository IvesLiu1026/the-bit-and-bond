import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/auth/auth_session.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/auth_api_client.dart';
import '../features/quests/quest_repository.dart';
import 'auth_controller.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return AuthApiClient(baseUrl: config.apiBaseUrl);
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>((ref) {
      final authApi = ref.watch(authApiClientProvider);
      final storage = ref.watch(secureStorageProvider);
      return AuthController(authApi: authApi, storage: storage);
    });

final authSessionProvider = Provider<AuthSession?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.maybeWhen(data: (session) => session, orElse: () => null);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final authSession = ref.watch(authSessionProvider);
  return ApiClient(baseUrl: config.apiBaseUrl, authSession: authSession);
});

final questRepositoryProvider = Provider<QuestRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return QuestRepository(api);
});
