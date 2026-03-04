import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';

class AuthApiClient {
  AuthApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<AuthSession> registerMaster({
    required String email,
    required String password,
    required String guildName,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/v1/auth/master/register'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'email': email,
            'password': password,
            'guild_name': guildName,
          }),
        )
        .timeout(const Duration(seconds: 10));
    final data = _parseResponse(response) as Map<String, dynamic>;
    return _sessionFromAuthJson(data);
  }

  Future<AuthSession> loginMaster({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/v1/auth/master/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));
    final data = _parseResponse(response) as Map<String, dynamic>;
    return _sessionFromAuthJson(data);
  }

  Future<AuthSession> loginHunter({
    required String inviteCode,
    required String pinCode,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/api/v1/auth/hunter/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({'invite_code': inviteCode, 'pin_code': pinCode}),
        )
        .timeout(const Duration(seconds: 10));
    final data = _parseResponse(response) as Map<String, dynamic>;
    return _sessionFromAuthJson(data);
  }

  Future<AuthSession> me(String accessToken, {String? inviteCode}) async {
    final response = await _httpClient
        .get(
          Uri.parse('$baseUrl/api/v1/auth/me'),
          headers: _bearerHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 10));
    final data = _parseResponse(response) as Map<String, dynamic>;
    return AuthSession(
      accessToken: accessToken,
      role: _parseRole((data['role'] ?? 'hunter') as String),
      guildId: (data['guild_id'] ?? '') as String,
      hunterId: data['hunter_id'] as String?,
      inviteCode: inviteCode,
    );
  }

  Map<String, String> _jsonHeaders() => const {
    'Content-Type': 'application/json',
  };

  Map<String, String> _bearerHeaders(String token) => {
    'Authorization': 'Bearer $token',
  };

  dynamic _parseResponse(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as dynamic;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (body is Map<String, dynamic> && body['error'] is String) {
      throw AuthApiException(body['error'] as String, response.statusCode);
    }

    throw AuthApiException(
      'auth request failed with status ${response.statusCode}',
      response.statusCode,
    );
  }

  AuthSession _sessionFromAuthJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: (json['access_token'] ?? '') as String,
      role: _parseRole((json['role'] ?? 'hunter') as String),
      guildId: (json['guild_id'] ?? '') as String,
      hunterId: json['hunter_id'] as String?,
      inviteCode: json['invite_code'] as String?,
    );
  }

  AuthUserRole _parseRole(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'guild_master':
        return AuthUserRole.guildMaster;
      case 'hunter':
      default:
        return AuthUserRole.hunter;
    }
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
