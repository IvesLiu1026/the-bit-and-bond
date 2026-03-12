import 'dart:convert';

import 'package:http/http.dart' as http;

const String ngrokSkipBrowserWarningHeaderName = 'ngrok-skip-browser-warning';
const String ngrokSkipBrowserWarningHeaderValue = 'true';
const int defaultHttpErrorSnippetLength = 180;

typedef HttpExceptionFactory<T extends Exception> = T Function(
  String message,
  int statusCode,
);

Map<String, String> jsonHeaders({String? bearerToken}) {
  return <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (bearerToken != null && bearerToken.trim().isNotEmpty)
      'Authorization': 'Bearer ${bearerToken.trim()}',
    ngrokSkipBrowserWarningHeaderName: ngrokSkipBrowserWarningHeaderValue,
  };
}

Map<String, String> bearerHeaders(String token) {
  return <String, String>{
    'Authorization': 'Bearer ${token.trim()}',
    'Accept': 'application/json',
    ngrokSkipBrowserWarningHeaderName: ngrokSkipBrowserWarningHeaderValue,
  };
}

String compactResponseSnippet(
  String body, {
  int maxLength = defaultHttpErrorSnippetLength,
}) {
  final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= maxLength) {
    return compact;
  }
  return '${compact.substring(0, maxLength)}...';
}

dynamic parseJsonResponse<T extends Exception>(
  http.Response response, {
  required String invalidJsonMessage,
  required String ngrokInterceptMessage,
  required String fallbackErrorLabel,
  required HttpExceptionFactory<T> errorFactory,
  int maxErrorSnippetLength = defaultHttpErrorSnippetLength,
}) {
  final rawBody = response.body;
  dynamic body = <String, dynamic>{};
  if (rawBody.isNotEmpty) {
    try {
      body = jsonDecode(rawBody) as dynamic;
    } on FormatException {
      final snippet = compactResponseSnippet(
        rawBody,
        maxLength: maxErrorSnippetLength,
      );
      if (snippet.contains('ERR_NGROK_6024')) {
        throw errorFactory(ngrokInterceptMessage, response.statusCode);
      }
      throw errorFactory('$invalidJsonMessage: $snippet', response.statusCode);
    }
  }

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return body;
  }

  if (body is Map<String, dynamic> && body['error'] is String) {
    throw errorFactory(body['error'] as String, response.statusCode);
  }

  final suffix = rawBody.isEmpty
      ? ''
      : ' (${compactResponseSnippet(rawBody, maxLength: maxErrorSnippetLength)})';
  throw errorFactory(
    '$fallbackErrorLabel with status ${response.statusCode}$suffix',
    response.statusCode,
  );
}
