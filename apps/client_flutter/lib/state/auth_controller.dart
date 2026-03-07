import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/auth/auth_session.dart';
import '../core/network/auth_api_client.dart';

class AuthController extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthController({
    required AuthApiClient authApi,
    required FlutterSecureStorage storage,
    bool restoreOnInit = true,
  }) : _authApi = authApi,
       _storage = storage,
       super(const AsyncValue.loading()) {
    if (restoreOnInit) {
      _restoreSession();
    } else {
      state = const AsyncValue.data(null);
    }
  }

  static const String storageKey = 'the_bit_and_bond_auth_session_v1';

  final AuthApiClient _authApi;
  final FlutterSecureStorage _storage;

  Future<void> _restoreSession() async {
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == null || raw.isEmpty) {
        state = const AsyncValue.data(null);
        return;
      }

      final parsed = AuthSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      try {
        final validated = await _authApi.me(
          parsed.accessToken,
          inviteCode: parsed.inviteCode,
          playerId: parsed.playerId,
          displayName: parsed.displayName,
        );
        await _persist(validated);
        state = AsyncValue.data(validated);
      } on AuthApiException catch (err) {
        if (err.statusCode == 401 || err.statusCode == 403) {
          await _clearPersisted();
          state = const AsyncValue.data(null);
          return;
        }
        state = AsyncValue.data(parsed);
      }
    } catch (error, stackTrace) {
      await _clearPersisted();
      state = AsyncValue.error(error, stackTrace);
      state = const AsyncValue.data(null);
    }
  }

  Future<AuthSession> registerPlayer({
    required String playerId,
    required String pinCode,
    required String displayName,
    String? avatarType,
  }) async {
    state = const AsyncValue.loading();
    try {
      final session = await _authApi.registerPlayer(
        playerId: playerId,
        pinCode: pinCode,
        displayName: displayName,
        avatarType: avatarType,
      );
      await _persist(session);
      state = AsyncValue.data(session);
      return session;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<AuthSession> loginPlayer({
    required String playerId,
    required String pinCode,
  }) async {
    state = const AsyncValue.loading();
    try {
      final session = await _authApi.loginPlayer(
        playerId: playerId,
        pinCode: pinCode,
      );
      await _persist(session);
      state = AsyncValue.data(session);
      return session;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _clearPersisted();
    state = const AsyncValue.data(null);
  }

  Future<void> _persist(AuthSession session) async {
    await _storage.write(key: storageKey, value: jsonEncode(session.toJson()));
  }

  Future<void> _clearPersisted() async {
    await _storage.delete(key: storageKey);
  }
}
