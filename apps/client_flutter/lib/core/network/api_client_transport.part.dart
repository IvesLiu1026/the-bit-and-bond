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
  ...bearerHeaders(token),
};

Map<String, String> _apiClientJsonBearerHeaders(String token) => {
  ...jsonHeaders(bearerToken: token),
};

dynamic _apiClientParseResponse(ApiClient api, http.Response response) {
  return parseJsonResponse<ApiException>(
    response,
    invalidJsonMessage: 'expected JSON response but received',
    ngrokInterceptMessage:
        'ngrok warning page intercepted the API response; please refresh the app and retry',
    fallbackErrorLabel: 'API request failed',
    errorFactory: ApiException.new,
    maxErrorSnippetLength: ApiClient._maxErrorSnippetLength,
  );
}
