import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:the_bit_and_bond_client/core/auth/auth_session.dart';
import 'package:the_bit_and_bond_client/core/network/api_client.dart';

void main() {
  test('retries once with recovered token after unauthorized', () async {
    final capturedAuthHeaders = <String?>[];
    final client = _QueueHttpClient(
      handlers: Queue<http.StreamedResponse Function(http.BaseRequest)>.from([
        (request) {
          capturedAuthHeaders.add(request.headers['Authorization']);
          return _jsonResponse(401, {'error': 'invalid or expired token'});
        },
        (request) {
          capturedAuthHeaders.add(request.headers['Authorization']);
          return _jsonResponse(200, <Object>[]);
        },
      ]),
    );

    var session = const AuthSession(
      accessToken: 'stale-token',
      guildId: 'guild',
      hunterId: 'hunter',
      guildRole: GuildRole.member,
    );
    var recoverCalls = 0;

    final api = ApiClient(
      baseUrl: 'http://127.0.0.1:18080',
      authSession: session,
      authSessionResolver: () => session,
      onUnauthorizedRecover: () async {
        recoverCalls += 1;
        session = const AuthSession(
          accessToken: 'fresh-token',
          guildId: 'guild',
          hunterId: 'hunter',
          guildRole: GuildRole.member,
        );
        return session;
      },
      httpClient: client,
    );

    final quests = await api.listQuests();
    expect(quests, isEmpty);
    expect(recoverCalls, 1);
    expect(capturedAuthHeaders, ['Bearer stale-token', 'Bearer fresh-token']);
  });

  test('keeps unauthorized error when recovery is unavailable', () async {
    final client = _QueueHttpClient(
      handlers: Queue<http.StreamedResponse Function(http.BaseRequest)>.from([
        (_) => _jsonResponse(401, {'error': 'invalid or expired token'}),
      ]),
    );

    var recoverCalls = 0;
    final api = ApiClient(
      baseUrl: 'http://127.0.0.1:18080',
      authSession: const AuthSession(
        accessToken: 'stale-token',
        guildId: 'guild',
        hunterId: 'hunter',
        guildRole: GuildRole.member,
      ),
      onUnauthorizedRecover: () async {
        recoverCalls += 1;
        return null;
      },
      httpClient: client,
    );

    await expectLater(
      api.listQuests(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(recoverCalls, 1);
  });

  test('does not recover on non-auth 403 responses', () async {
    final client = _QueueHttpClient(
      handlers: Queue<http.StreamedResponse Function(http.BaseRequest)>.from([
        (_) => _jsonResponse(403, {'error': 'guild owner role required'}),
      ]),
    );

    var recoverCalls = 0;
    final api = ApiClient(
      baseUrl: 'http://127.0.0.1:18080',
      authSession: const AuthSession(
        accessToken: 'member-token',
        guildId: 'guild',
        hunterId: 'hunter',
        guildRole: GuildRole.member,
      ),
      onUnauthorizedRecover: () async {
        recoverCalls += 1;
        return null;
      },
      httpClient: client,
    );

    await expectLater(
      api.listQuests(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
    expect(recoverCalls, 0);
  });

  test('fetchMediaBytes retries recoverable transport failures', () async {
    final client = _QueueHttpClient(
      handlers: Queue<http.StreamedResponse Function(http.BaseRequest)>.from([
        (_) => throw http.ClientException('write failed: Broken pipe'),
        (_) => http.StreamedResponse(
          Stream<List<int>>.value(const <int>[1, 2, 3]),
          200,
          headers: const {'content-type': 'image/jpeg'},
        ),
      ]),
    );

    final api = ApiClient(
      baseUrl: 'http://127.0.0.1:18080',
      authSession: const AuthSession(
        accessToken: 'token',
        guildId: 'guild',
        hunterId: 'hunter',
        guildRole: GuildRole.member,
      ),
      httpClient: client,
    );

    final bytes = await api.fetchMediaBytes(
      contentPath: '/api/v1/media/assets/demo/content',
    );
    expect(bytes, <int>[1, 2, 3]);
  });
}

class _QueueHttpClient extends http.BaseClient {
  _QueueHttpClient({
    required Queue<http.StreamedResponse Function(http.BaseRequest)> handlers,
  }) : _handlers = handlers;

  final Queue<http.StreamedResponse Function(http.BaseRequest)> _handlers;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_handlers.isEmpty) {
      throw StateError('Unexpected request with no queued response');
    }
    final handler = _handlers.removeFirst();
    return handler(request);
  }
}

http.StreamedResponse _jsonResponse(int status, Object body) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    status,
    headers: const {'content-type': 'application/json'},
  );
}
