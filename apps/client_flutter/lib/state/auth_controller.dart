import 'dart:convert';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/auth/auth_session.dart';
import '../core/auth/google_federated_auth_service.dart';
import '../core/network/auth_api_client.dart';

class AuthController extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthController({
    required AuthApiClient authApi,
    required FlutterSecureStorage storage,
    GoogleFederatedAuthService? googleAuth,
    bool restoreOnInit = true,
  }) : _authApi = authApi,
       _storage = storage,
       _googleAuth = googleAuth ?? const GoogleFederatedAuthService(),
       super(const AsyncValue.loading()) {
    if (restoreOnInit) {
      _restoreSession();
    } else {
      state = const AsyncValue.data(null);
    }
  }

  static const String storageKey = 'the_bit_and_bond_auth_session_v1';
  static const String _storageLoginMethodKey =
      'the_bit_and_bond_auth_login_method_v1';
  static const String _storageLoginAccountKey =
      'the_bit_and_bond_auth_login_account_v1';
  static const String _storageLoginSecretKey =
      'the_bit_and_bond_auth_login_secret_v1';

  final AuthApiClient _authApi;
  final FlutterSecureStorage _storage;
  final GoogleFederatedAuthService _googleAuth;
  Completer<AuthSession?>? _recoveringSessionCompleter;

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
          final recovered = await recoverSession();
          if (recovered != null) {
            return;
          }
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
    final previousSession = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      final session = await _authApi.registerPlayer(
        playerId: playerId,
        pinCode: pinCode,
        displayName: displayName,
        avatarType: avatarType,
      );
      await _persistManualCredentials(account: playerId, secret: pinCode);
      await _persist(session);
      state = AsyncValue.data(session);
      return session;
    } catch (error) {
      state = AsyncValue.data(previousSession);
      rethrow;
    }
  }

  Future<AuthSession> loginPlayer({
    required String playerId,
    required String pinCode,
  }) async {
    final previousSession = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      final session = await _authApi.loginPlayer(
        playerId: playerId,
        pinCode: pinCode,
      );
      await _persistManualCredentials(account: playerId, secret: pinCode);
      await _persist(session);
      state = AsyncValue.data(session);
      return session;
    } catch (error) {
      state = AsyncValue.data(previousSession);
      rethrow;
    }
  }

  Future<AuthSession> loginWithFirebaseIdToken({
    required String idToken,
    String? displayName,
    String? avatarType,
  }) async {
    final previousSession = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      final session = await _authApi.loginWithFirebaseIdToken(
        idToken: idToken,
        displayName: displayName,
        avatarType: avatarType,
      );
      await _persistFirebaseLoginMethod();
      await _persist(session);
      state = AsyncValue.data(session);
      return session;
    } catch (error) {
      state = AsyncValue.data(previousSession);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _clearPersisted();
    await _clearPersistedLoginMethod();
    state = const AsyncValue.data(null);
  }

  Future<AuthSession?> recoverSession() async {
    final inFlight = _recoveringSessionCompleter;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<AuthSession?>();
    _recoveringSessionCompleter = completer;
    try {
      final recovered = await _recoverSessionInternal();
      completer.complete(recovered);
      return recovered;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      _recoveringSessionCompleter = null;
    }
  }

  Future<AuthSession?> _recoverSessionInternal() async {
    final existing = state.valueOrNull;
    if (existing != null && existing.accessToken.trim().isNotEmpty) {
      try {
        final validated = await _authApi.me(
          existing.accessToken,
          inviteCode: existing.inviteCode,
          playerId: existing.playerId,
          displayName: existing.displayName,
        );
        await _persist(validated);
        state = AsyncValue.data(validated);
        return validated;
      } on AuthApiException catch (error) {
        if (error.statusCode != 401 && error.statusCode != 403) {
          return existing;
        }
      } catch (_) {
        return existing;
      }
    }

    final method = await _readPersistedLoginMethod();
    if (method == _PersistedLoginMethod.manual) {
      final account = (await _storage.read(
        key: _storageLoginAccountKey,
      ))?.trim();
      final secret = await _storage.read(key: _storageLoginSecretKey);
      if (account != null &&
          account.isNotEmpty &&
          secret != null &&
          secret.isNotEmpty) {
        try {
          final session = await _authApi.loginPlayer(
            playerId: account,
            pinCode: secret,
          );
          await _persistManualCredentials(account: account, secret: secret);
          await _persist(session);
          state = AsyncValue.data(session);
          return session;
        } catch (_) {
          // Continue to firebase fallback below.
        }
      }
    }

    final identity = await _googleAuth.tryRestoreIdentity();
    if (identity != null) {
      try {
        final session = await _authApi.loginWithFirebaseIdToken(
          idToken: identity.firebaseIdToken,
          displayName: identity.displayName,
        );
        await _persistFirebaseLoginMethod();
        await _persist(session);
        state = AsyncValue.data(session);
        return session;
      } catch (_) {
        // Fall through and return null.
      }
    }

    return null;
  }

  Future<void> _persist(AuthSession session) async {
    await _storage.write(key: storageKey, value: jsonEncode(session.toJson()));
  }

  Future<void> _clearPersisted() async {
    await _storage.delete(key: storageKey);
  }

  Future<void> _persistManualCredentials({
    required String account,
    required String secret,
  }) async {
    await _storage.write(
      key: _storageLoginMethodKey,
      value: _PersistedLoginMethod.manual.name,
    );
    await _storage.write(
      key: _storageLoginAccountKey,
      value: account.trim().toLowerCase(),
    );
    await _storage.write(key: _storageLoginSecretKey, value: secret);
  }

  Future<void> _persistFirebaseLoginMethod() async {
    await _storage.write(
      key: _storageLoginMethodKey,
      value: _PersistedLoginMethod.firebase.name,
    );
    await _storage.delete(key: _storageLoginAccountKey);
    await _storage.delete(key: _storageLoginSecretKey);
  }

  Future<void> _clearPersistedLoginMethod() async {
    await _storage.delete(key: _storageLoginMethodKey);
    await _storage.delete(key: _storageLoginAccountKey);
    await _storage.delete(key: _storageLoginSecretKey);
  }

  Future<_PersistedLoginMethod?> _readPersistedLoginMethod() async {
    final raw = (await _storage.read(key: _storageLoginMethodKey))?.trim();
    return _PersistedLoginMethod.fromStorageValue(raw);
  }
}

enum _PersistedLoginMethod {
  manual,
  firebase;

  static _PersistedLoginMethod? fromStorageValue(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final value in _PersistedLoginMethod.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }
}
