part of 'api_client.dart';

Future<VoiceTokenBundle> _apiClientIssueVoiceToken(
  ApiClient api, {
  String? roomId,
}) async {
  final payload = <String, dynamic>{};
  final normalizedRoomId = roomId?.trim();
  if (normalizedRoomId != null && normalizedRoomId.isNotEmpty) {
    payload['room_id'] = normalizedRoomId;
  }
  final data = await api._authedPost(
    '/api/v1/voice/token',
    payload,
    role: _AuthRole.any,
  );
  return VoiceTokenBundle.fromJson(data as Map<String, dynamic>);
}

Future<List<ChatMessage>> _apiClientGetChatHistory(
  ApiClient api, {
  String? roomId,
  int limit = 50,
  int? beforeMs,
}) async {
  final query = <String, String>{'limit': '$limit'};
  final normalizedRoomId = roomId?.trim();
  if (normalizedRoomId != null && normalizedRoomId.isNotEmpty) {
    query['room_id'] = normalizedRoomId;
  }
  if (beforeMs != null) {
    query['before_ms'] = '$beforeMs';
  }
  final data = await api._authedGet(
    '/api/v1/chat/history',
    query,
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<ChatMessage> _apiClientPersistChatMessage(
  ApiClient api, {
  required String content,
  String? roomId,
  String? clientMessageId,
  int? sentAtMs,
}) async {
  final payload = <String, dynamic>{'content': content};
  final normalizedRoomId = roomId?.trim();
  if (normalizedRoomId != null && normalizedRoomId.isNotEmpty) {
    payload['room_id'] = normalizedRoomId;
  }
  final normalizedClientMessageId = clientMessageId?.trim();
  if (normalizedClientMessageId != null &&
      normalizedClientMessageId.isNotEmpty) {
    payload['client_message_id'] = normalizedClientMessageId;
  }
  if (sentAtMs != null) {
    payload['sent_at_ms'] = sentAtMs;
  }
  final data = await api._authedPost(
    '/api/v1/chat/messages',
    payload,
    role: _AuthRole.any,
  );
  return ChatMessage.fromJson(data as Map<String, dynamic>);
}
