part of 'api_client.dart';

Future<List<DirectMessageThread>> _apiClientListDirectMessageThreads(
  ApiClient api, {
  int limit = 40,
}) async {
  final data = await api._authedGet('/api/v1/direct-messages/threads', {
    'limit': '$limit',
  }, role: _AuthRole.any);
  return (data as List)
      .map((item) => DirectMessageThread.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<void> _apiClientMarkDirectMessageThreadRead(
  ApiClient api, {
  required String counterpartHunterId,
}) {
  return api._authedPost(
    '/api/v1/direct-messages/threads/$counterpartHunterId/read',
    const {},
    role: _AuthRole.any,
  );
}

Future<List<DmDeviceKey>> _apiClientListDirectMessageDeviceKeys(
  ApiClient api, {
  required String hunterId,
}) async {
  final data = await api._authedGet(
    '/api/v1/direct-messages/device-keys/$hunterId',
    const {},
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => DmDeviceKey.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<Map<String, List<DmDeviceKey>>>
_apiClientListDirectMessageDeviceKeysBatch(
  ApiClient api, {
  required List<String> hunterIds,
}) async {
  final normalized = hunterIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (normalized.isEmpty) {
    return const <String, List<DmDeviceKey>>{};
  }
  final data = await api._authedGet('/api/v1/direct-messages/device-keys', {
    'hunter_ids': normalized.join(','),
  }, role: _AuthRole.any);
  final rows = (data as List)
      .map((item) => item as Map<String, dynamic>)
      .toList(growable: false);
  final grouped = <String, List<DmDeviceKey>>{};
  for (final row in rows) {
    final hunterId = (row['hunter_id'] as String?)?.trim();
    if (hunterId == null || hunterId.isEmpty) {
      continue;
    }
    final keys = (row['keys'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => DmDeviceKey.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    grouped[hunterId] = keys;
  }
  for (final hunterId in normalized) {
    grouped.putIfAbsent(hunterId, () => const <DmDeviceKey>[]);
  }
  return grouped;
}

Future<DmDeviceKey> _apiClientRegisterDirectMessageDeviceKey(
  ApiClient api, {
  required String deviceId,
  String? deviceLabel,
  required String signingPublicKey,
  required String encryptionPublicKey,
}) async {
  final data = await api
      ._authedPost('/api/v1/direct-messages/device-keys/register', {
        'device_id': deviceId,
        'device_label': deviceLabel,
        'signing_public_key': signingPublicKey,
        'encryption_public_key': encryptionPublicKey,
      }, role: _AuthRole.any);
  return DmDeviceKey.fromJson(data as Map<String, dynamic>);
}

Future<DmDeviceKey> _apiClientRevokeDirectMessageDeviceKey(
  ApiClient api, {
  required String deviceId,
}) async {
  final data = await api._authedPost(
    '/api/v1/direct-messages/device-keys/revoke',
    {'device_id': deviceId},
    role: _AuthRole.any,
  );
  return DmDeviceKey.fromJson(data as Map<String, dynamic>);
}

Future<List<DirectMessage>> _apiClientGetDirectMessageHistory(
  ApiClient api, {
  required String counterpartHunterId,
  int limit = 50,
  int? beforeMs,
}) async {
  final query = <String, String>{
    'counterpart_hunter_id': counterpartHunterId,
    'limit': '$limit',
  };
  if (beforeMs != null) {
    query['before_ms'] = '$beforeMs';
  }
  final data = await api._authedGet(
    '/api/v1/direct-messages/history',
    query,
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => DirectMessage.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<DirectMessage> _apiClientPersistDirectMessage(
  ApiClient api, {
  required String recipientHunterId,
  required String content,
  String? clientMessageId,
  int? sentAtMs,
}) async {
  final payload = <String, dynamic>{
    'recipient_hunter_id': recipientHunterId,
    'content': content,
  };
  final normalizedClientMessageId = clientMessageId?.trim();
  if (normalizedClientMessageId != null &&
      normalizedClientMessageId.isNotEmpty) {
    payload['client_message_id'] = normalizedClientMessageId;
  }
  if (sentAtMs != null) {
    payload['sent_at_ms'] = sentAtMs;
  }
  final data = await api._authedPost(
    '/api/v1/direct-messages/messages',
    payload,
    role: _AuthRole.any,
  );
  return DirectMessage.fromJson(data as Map<String, dynamic>);
}

Future<List<EncryptedDirectMessage>> _apiClientGetEncryptedDirectMessageHistory(
  ApiClient api, {
  required String counterpartHunterId,
  int limit = 50,
  int? beforeMs,
}) async {
  final query = <String, String>{
    'counterpart_hunter_id': counterpartHunterId,
    'limit': '$limit',
  };
  if (beforeMs != null) {
    query['before_ms'] = '$beforeMs';
  }
  final data = await api._authedGet(
    '/api/v1/direct-messages/encrypted/history',
    query,
    role: _AuthRole.any,
  );
  return (data as List)
      .map(
        (item) => EncryptedDirectMessage.fromJson(item as Map<String, dynamic>),
      )
      .toList();
}

Future<EncryptedDirectMessage> _apiClientPersistEncryptedDirectMessage(
  ApiClient api, {
  required String recipientHunterId,
  required String senderDeviceId,
  required String recipientDeviceId,
  String? clientMessageId,
  String? protocolVersion,
  required String ciphertext,
  required String nonce,
  int? sentAtMs,
}) async {
  final payload = <String, dynamic>{
    'recipient_hunter_id': recipientHunterId,
    'sender_device_id': senderDeviceId,
    'recipient_device_id': recipientDeviceId,
    'ciphertext': ciphertext,
    'nonce': nonce,
  };
  final normalizedClientMessageId = clientMessageId?.trim();
  if (normalizedClientMessageId != null &&
      normalizedClientMessageId.isNotEmpty) {
    payload['client_message_id'] = normalizedClientMessageId;
  }
  final normalizedProtocolVersion = protocolVersion?.trim();
  if (normalizedProtocolVersion != null &&
      normalizedProtocolVersion.isNotEmpty) {
    payload['protocol_version'] = normalizedProtocolVersion;
  }
  if (sentAtMs != null) {
    payload['sent_at_ms'] = sentAtMs;
  }
  final data = await api._authedPost(
    '/api/v1/direct-messages/encrypted/messages',
    payload,
    role: _AuthRole.any,
  );
  return EncryptedDirectMessage.fromJson(data as Map<String, dynamic>);
}
