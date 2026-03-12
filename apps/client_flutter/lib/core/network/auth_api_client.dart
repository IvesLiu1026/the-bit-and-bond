import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import 'http_transport.dart';

class AuthApiClient {
  AuthApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<AuthSession> registerPlayer({
    required String playerId,
    required String pinCode,
    required String displayName,
    String? avatarType,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/v1/auth/register'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'account': playerId,
            'secret': pinCode,
            'display_name': displayName,
            'avatar_type': avatarType,
          }),
        )
        .timeout(const Duration(seconds: 10));
    final data = _parseResponse(response) as Map<String, dynamic>;
    return _sessionFromAuthJson(data);
  }

  Future<AuthSession> loginPlayer({
    required String playerId,
    required String pinCode,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/v1/auth/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({'account': playerId, 'secret': pinCode}),
        )
        .timeout(const Duration(seconds: 10));
    final data = _parseResponse(response) as Map<String, dynamic>;
    return _sessionFromAuthJson(data);
  }

  Future<AuthSession> loginWithFirebaseIdToken({
    required String idToken,
    String? displayName,
    String? avatarType,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/v1/auth/firebase'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'id_token': idToken,
            'display_name': displayName,
            'avatar_type': avatarType,
          }),
        )
        .timeout(const Duration(seconds: 10));
    final data = _parseResponse(response) as Map<String, dynamic>;
    return _sessionFromAuthJson(data);
  }

  Future<AuthSession> me(
    String accessToken, {
    String? inviteCode,
    String? playerId,
    String? displayName,
  }) async {
    final response = await _httpClient
        .get(
          Uri.parse('$baseUrl/api/v1/auth/me'),
          headers: _bearerHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 10));
    final data = _parseResponse(response) as Map<String, dynamic>;
    final hunterId = (data['hunter_id'] as String?)?.trim();
    if (hunterId == null || hunterId.isEmpty) {
      throw AuthApiException(
        'session missing hunter_id, please login again',
        401,
      );
    }
    return AuthSession(
      accessToken: accessToken,
      guildId: (data['guild_id'] ?? '') as String,
      hunterId: hunterId,
      guildRole: _parseGuildRole(guildRoleRaw: data['guild_role'] as String?),
      inviteCode: inviteCode,
      playerId: (data['player_id'] as String?) ?? playerId,
      displayName: (data['display_name'] as String?) ?? displayName,
      avatarType: data['avatar_type'] as String?,
    );
  }

  Map<String, String> _jsonHeaders() => jsonHeaders();

  Map<String, String> _bearerHeaders(String token) => bearerHeaders(token);

  dynamic _parseResponse(http.Response response) {
    return parseJsonResponse<AuthApiException>(
      response,
      invalidJsonMessage: 'expected JSON auth response but received',
      ngrokInterceptMessage:
          'ngrok warning page intercepted auth API response; please refresh and retry',
      fallbackErrorLabel: 'auth request failed',
      errorFactory: AuthApiException.new,
    );
  }

  AuthSession _sessionFromAuthJson(Map<String, dynamic> json) {
    final hunterId = (json['hunter_id'] as String?)?.trim();
    if (hunterId == null || hunterId.isEmpty) {
      throw AuthApiException('auth response missing hunter_id', 500);
    }
    return AuthSession(
      accessToken: (json['access_token'] ?? '') as String,
      guildId: (json['guild_id'] ?? '') as String,
      hunterId: hunterId,
      guildRole: _parseGuildRole(guildRoleRaw: json['guild_role'] as String?),
      inviteCode: json['invite_code'] as String?,
      playerId: json['player_id'] as String?,
      displayName: json['display_name'] as String?,
      avatarType: json['avatar_type'] as String?,
    );
  }

  GuildRole _parseGuildRole({String? guildRoleRaw}) {
    final normalizedGuildRole = guildRoleRaw?.trim().toLowerCase();
    if (normalizedGuildRole == 'master') {
      return GuildRole.master;
    }
    if (normalizedGuildRole == 'member') {
      return GuildRole.member;
    }
    return GuildRole.member;
  }
}

class AuthApiException implements Exception {
  AuthApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() {
    return 'AuthApiException(status: $statusCode, message: $message)';
  }
}
