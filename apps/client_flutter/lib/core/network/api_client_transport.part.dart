part of 'api_client.dart';

Future<dynamic> _apiClientAuthedGet(
  ApiClient api,
  String path,
  Map<String, String> query, {
  required _AuthRole role,
}) async {
  final uri = Uri.parse('${api.baseUrl}$path').replace(queryParameters: query);
  final response = await _apiClientAuthedRequestResponse(
    api,
    role,
    (token) =>
        api._httpClient.get(uri, headers: _apiClientBearerHeaders(token)),
  );
  return _apiClientParseResponse(api, response);
}

Future<dynamic> _apiClientAuthedPost(
  ApiClient api,
  String path,
  Map<String, dynamic> payload, {
  required _AuthRole role,
}) async {
  final uri = Uri.parse('${api.baseUrl}$path');
  final response = await _apiClientAuthedRequestResponse(
    api,
    role,
    (token) => api._httpClient.post(
      uri,
      headers: _apiClientJsonBearerHeaders(token),
      body: jsonEncode(payload),
    ),
  );
  return _apiClientParseResponse(api, response);
}

Future<dynamic> _apiClientAuthedPatch(
  ApiClient api,
  String path,
  Map<String, dynamic> payload, {
  required _AuthRole role,
}) async {
  final uri = Uri.parse('${api.baseUrl}$path');
  final response = await _apiClientAuthedRequestResponse(
    api,
    role,
    (token) => api._httpClient.patch(
      uri,
      headers: _apiClientJsonBearerHeaders(token),
      body: jsonEncode(payload),
    ),
  );
  return _apiClientParseResponse(api, response);
}

Future<dynamic> _apiClientAuthedPut(
  ApiClient api,
  String path,
  Map<String, dynamic> payload, {
  required _AuthRole role,
}) async {
  final uri = Uri.parse('${api.baseUrl}$path');
  final response = await _apiClientAuthedRequestResponse(
    api,
    role,
    (token) => api._httpClient.put(
      uri,
      headers: _apiClientJsonBearerHeaders(token),
      body: jsonEncode(payload),
    ),
  );
  return _apiClientParseResponse(api, response);
}

Future<dynamic> _apiClientAuthedDelete(
  ApiClient api,
  String path, {
  required _AuthRole role,
}) async {
  final uri = Uri.parse('${api.baseUrl}$path');
  final response = await _apiClientAuthedRequestResponse(
    api,
    role,
    (token) => api._httpClient.delete(
      uri,
      headers: _apiClientJsonBearerHeaders(token),
    ),
  );
  return _apiClientParseResponse(api, response);
}

Future<http.Response> _apiClientAuthedRequestResponse(
  ApiClient api,
  _AuthRole role,
  Future<http.Response> Function(String token) send, {
  Duration timeout = const Duration(seconds: 10),
  bool retryTransportErrors = false,
}) async {
  var unauthorizedRetryCount = 0;
  var transportRetryCount = 0;
  final maxUnauthorizedRetries = 2;
  final maxTransportRetries = retryTransportErrors ? 2 : 0;
  while (true) {
    final token = _apiClientResolveTokenForRole(api, role);
    try {
      final response = await send(token).timeout(timeout);
      if (unauthorizedRetryCount < maxUnauthorizedRetries &&
          _apiClientShouldRecoverUnauthorized(response) &&
          await _apiClientRecoverUnauthorizedSession(api)) {
        unauthorizedRetryCount += 1;
        continue;
      }
      return response;
    } catch (error) {
      if (transportRetryCount < maxTransportRetries &&
          _apiClientIsRecoverableTransportError(error)) {
        transportRetryCount += 1;
        final backoff = Duration(
          milliseconds: 120 * transportRetryCount * transportRetryCount,
        );
        await Future<void>.delayed(backoff);
        continue;
      }
      rethrow;
    }
  }
}

bool _apiClientShouldRecoverUnauthorized(http.Response response) {
  if (response.statusCode == 401) {
    return true;
  }
  if (response.statusCode != 403) {
    return false;
  }
  final lower = response.body.toLowerCase();
  return lower.contains('token') ||
      lower.contains('expired') ||
      lower.contains('authentication') ||
      lower.contains('session');
}

bool _apiClientIsRecoverableTransportError(Object error) {
  if (error is TimeoutException) {
    return true;
  }
  if (error is SocketException) {
    final code = error.osError?.errorCode;
    final message = error.message.toLowerCase();
    const recoverableSocketCodes = <int>{32, 54, 57, 60, 61, 64, 104};
    return (code != null && recoverableSocketCodes.contains(code)) ||
        message.contains('broken pipe') ||
        message.contains('connection reset') ||
        message.contains('connection refused') ||
        message.contains('write failed') ||
        message.contains('timed out');
  }
  if (error is http.ClientException) {
    final message = error.message.toLowerCase();
    return message.contains('broken pipe') ||
        message.contains('write failed') ||
        message.contains('connection reset') ||
        message.contains('connection refused') ||
        message.contains('timed out');
  }
  return false;
}

Future<bool> _apiClientRecoverUnauthorizedSession(ApiClient api) async {
  final recover = api.onUnauthorizedRecover;
  if (recover == null) {
    return false;
  }
  final inFlight = api._unauthorizedRecoveryCompleter;
  if (inFlight != null) {
    final recovered = await inFlight.future;
    return recovered != null && recovered.accessToken.trim().isNotEmpty;
  }
  final completer = Completer<AuthSession?>();
  api._unauthorizedRecoveryCompleter = completer;
  try {
    final recovered = await recover();
    completer.complete(recovered);
    return recovered != null && recovered.accessToken.trim().isNotEmpty;
  } catch (_) {
    completer.complete(null);
    return false;
  } finally {
    api._unauthorizedRecoveryCompleter = null;
  }
}

String _apiClientResolveTokenForRole(ApiClient api, _AuthRole role) {
  final session = _apiClientRequireSession(api);
  switch (role) {
    case _AuthRole.any:
      return session.accessToken;
    case _AuthRole.owner:
      if (!session.isGuildMaster) {
        throw ApiException('guild owner role required', 403);
      }
      return session.accessToken;
  }
}

AuthSession _apiClientRequireSession(ApiClient api) {
  final session = api.authSessionResolver?.call() ?? api.authSession;
  if (session == null || session.accessToken.isEmpty) {
    throw ApiException('authentication required', 401);
  }
  if (session.hunterId.trim().isEmpty) {
    throw ApiException('session missing hunter_id, please login again', 401);
  }
  return session;
}

Map<String, String> _apiClientBearerHeaders(String token) => {
  'Authorization': 'Bearer $token',
  'Accept': 'application/json',
  'ngrok-skip-browser-warning': 'true',
};

Map<String, String> _apiClientJsonBearerHeaders(String token) => {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'Authorization': 'Bearer $token',
  'ngrok-skip-browser-warning': 'true',
};

dynamic _apiClientParseResponse(ApiClient api, http.Response response) {
  final rawBody = response.body;
  dynamic body = <String, dynamic>{};
  if (rawBody.isNotEmpty) {
    try {
      body = jsonDecode(rawBody) as dynamic;
    } on FormatException {
      final snippet = _apiClientCompactSnippet(api, rawBody);
      if (snippet.contains('ERR_NGROK_6024')) {
        throw ApiException(
          'ngrok warning page intercepted the API response; please refresh the app and retry',
          response.statusCode,
        );
      }
      throw ApiException(
        'expected JSON response but received: $snippet',
        response.statusCode,
      );
    }
  }

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return body;
  }

  if (body is Map<String, dynamic> && body['error'] is String) {
    throw ApiException(body['error'] as String, response.statusCode);
  }

  throw ApiException(
    'API request failed with status ${response.statusCode}'
    '${rawBody.isEmpty ? '' : ' (${_apiClientCompactSnippet(api, rawBody)})'}',
    response.statusCode,
  );
}

String _apiClientCompactSnippet(ApiClient api, String body) {
  final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= ApiClient._maxErrorSnippetLength) {
    return compact;
  }
  return '${compact.substring(0, ApiClient._maxErrorSnippetLength)}...';
}
