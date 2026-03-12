import 'package:flutter_test/flutter_test.dart';
import 'package:the_bit_and_bond_client/core/models/models.dart';
import 'package:the_bit_and_bond_client/state/voice_chat_controller.dart';

void main() {
  test('voice room payload round-trips persisted chat messages', () {
    final message = ChatMessage(
      id: 'chat-1',
      guildId: 'guild-1',
      roomId: 'guild_guild-1:campfire',
      senderHunterId: 'hunter-1',
      senderName: 'Ives',
      clientMessageId: 'client-1',
      content: 'hello campfire',
      sentAt: DateTime.utc(2026, 3, 11, 12, 30),
      sentAtMs: DateTime.utc(2026, 3, 11, 12, 30).millisecondsSinceEpoch,
    );

    final payload = buildVoiceRoomChatPayload(message);
    final parsed = parseVoiceRoomChatPayload(payload);

    expect(parsed, isNotNull);
    expect(parsed!.id, message.id);
    expect(parsed.clientMessageId, message.clientMessageId);
    expect(parsed.senderHunterId, message.senderHunterId);
    expect(parsed.senderName, message.senderName);
    expect(parsed.content, message.content);
  });

  test('voice room payload supports legacy sender-shaped messages', () {
    final payload = <String, dynamic>{
      'type': 'chat.message',
      'guild_id': 'guild-1',
      'room_id': 'guild_guild-1:campfire',
      'sender_hunter_id': 'hunter-2',
      'sender_name': 'Friend',
      'client_message_id': 'local:client-legacy',
      'content': 'legacy hello',
      'sent_at_ms': 1_762_000_000_000,
    };

    final parsed = parseVoiceRoomChatPayload(payload);

    expect(parsed, isNotNull);
    expect(parsed!.id, 'live:client-legacy');
    expect(parsed.clientMessageId, 'client-legacy');
    expect(parsed.senderHunterId, 'hunter-2');
    expect(parsed.content, 'legacy hello');
  });
}
