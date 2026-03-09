part of 'models.dart';

class DirectMessageThread {
  DirectMessageThread({
    required this.conversationKey,
    required this.counterpartHunterId,
    required this.counterpartName,
    required this.counterpartPlayerId,
    required this.counterpartGuildId,
    required this.counterpartAvatarType,
    required this.lastMessage,
    required this.lastMessageSenderHunterId,
    required this.lastMessageSenderName,
    required this.lastMessageAt,
    required this.lastMessageAtMs,
    required this.encryptionMode,
    required this.unreadCount,
  });

  final String conversationKey;
  final String counterpartHunterId;
  final String counterpartName;
  final String counterpartPlayerId;
  final String counterpartGuildId;
  final String counterpartAvatarType;
  final String lastMessage;
  final String lastMessageSenderHunterId;
  final String lastMessageSenderName;
  final DateTime lastMessageAt;
  final int lastMessageAtMs;
  final String encryptionMode;
  final int unreadCount;

  factory DirectMessageThread.fromJson(Map<String, dynamic> json) {
    return DirectMessageThread(
      conversationKey: json['conversation_key'] as String,
      counterpartHunterId: json['counterpart_hunter_id'] as String,
      counterpartName: json['counterpart_name'] as String,
      counterpartPlayerId: json['counterpart_player_id'] as String,
      counterpartGuildId: json['counterpart_guild_id'] as String,
      counterpartAvatarType: json['counterpart_avatar_type'] as String,
      lastMessage: json['last_message'] as String,
      lastMessageSenderHunterId:
          json['last_message_sender_hunter_id'] as String,
      lastMessageSenderName: json['last_message_sender_name'] as String,
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      lastMessageAtMs:
          (json['last_message_at_ms'] as int?) ??
          DateTime.parse(
            json['last_message_at'] as String,
          ).millisecondsSinceEpoch,
      encryptionMode: (json['encryption_mode'] as String?) ?? 'plaintext',
      unreadCount: (json['unread_count'] as int?) ?? 0,
    );
  }
}

class DmDeviceKey {
  DmDeviceKey({
    required this.id,
    required this.hunterId,
    required this.deviceId,
    required this.deviceLabel,
    required this.signingPublicKey,
    required this.encryptionPublicKey,
    required this.createdAt,
    required this.lastSeenAt,
    required this.revokedAt,
  });

  final String id;
  final String hunterId;
  final String deviceId;
  final String? deviceLabel;
  final String signingPublicKey;
  final String encryptionPublicKey;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final DateTime? revokedAt;

  factory DmDeviceKey.fromJson(Map<String, dynamic> json) {
    return DmDeviceKey(
      id: json['id'] as String,
      hunterId: json['hunter_id'] as String,
      deviceId: json['device_id'] as String,
      deviceLabel: json['device_label'] as String?,
      signingPublicKey: json['signing_public_key'] as String,
      encryptionPublicKey: json['encryption_public_key'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
      revokedAt: json['revoked_at'] == null
          ? null
          : DateTime.parse(json['revoked_at'] as String),
    );
  }
}

class DirectMessage {
  DirectMessage({
    required this.id,
    required this.senderHunterId,
    required this.recipientHunterId,
    required this.counterpartHunterId,
    required this.counterpartName,
    required this.counterpartPlayerId,
    required this.counterpartGuildId,
    required this.senderName,
    required this.clientMessageId,
    required this.content,
    required this.sentAt,
    required this.sentAtMs,
    this.encryptionMode = 'plaintext',
    this.decryptionFailed = false,
  });

  final String id;
  final String senderHunterId;
  final String recipientHunterId;
  final String counterpartHunterId;
  final String counterpartName;
  final String counterpartPlayerId;
  final String counterpartGuildId;
  final String senderName;
  final String clientMessageId;
  final String content;
  final DateTime sentAt;
  final int sentAtMs;
  final String encryptionMode;
  final bool decryptionFailed;

  bool get isEncrypted => encryptionMode == 'encrypted';

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] as String,
      senderHunterId: json['sender_hunter_id'] as String,
      recipientHunterId: json['recipient_hunter_id'] as String,
      counterpartHunterId: json['counterpart_hunter_id'] as String,
      counterpartName: json['counterpart_name'] as String,
      counterpartPlayerId: json['counterpart_player_id'] as String,
      counterpartGuildId: json['counterpart_guild_id'] as String,
      senderName: json['sender_name'] as String,
      clientMessageId: json['client_message_id'] as String,
      content: json['content'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      sentAtMs:
          (json['sent_at_ms'] as int?) ??
          DateTime.parse(json['sent_at'] as String).millisecondsSinceEpoch,
      encryptionMode: (json['encryption_mode'] as String?) ?? 'plaintext',
      decryptionFailed: (json['decryption_failed'] as bool?) ?? false,
    );
  }
}

class EncryptedDirectMessage {
  EncryptedDirectMessage({
    required this.id,
    required this.senderHunterId,
    required this.recipientHunterId,
    required this.counterpartHunterId,
    required this.counterpartName,
    required this.counterpartPlayerId,
    required this.counterpartGuildId,
    required this.senderDeviceId,
    required this.recipientDeviceId,
    required this.clientMessageId,
    required this.protocolVersion,
    required this.ciphertext,
    required this.nonce,
    required this.sentAt,
    required this.sentAtMs,
    required this.encryptionMode,
  });

  final String id;
  final String senderHunterId;
  final String recipientHunterId;
  final String counterpartHunterId;
  final String counterpartName;
  final String counterpartPlayerId;
  final String counterpartGuildId;
  final String senderDeviceId;
  final String recipientDeviceId;
  final String clientMessageId;
  final String protocolVersion;
  final String ciphertext;
  final String nonce;
  final DateTime sentAt;
  final int sentAtMs;
  final String encryptionMode;

  factory EncryptedDirectMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedDirectMessage(
      id: json['id'] as String,
      senderHunterId: json['sender_hunter_id'] as String,
      recipientHunterId: json['recipient_hunter_id'] as String,
      counterpartHunterId: json['counterpart_hunter_id'] as String,
      counterpartName: json['counterpart_name'] as String,
      counterpartPlayerId: json['counterpart_player_id'] as String,
      counterpartGuildId: json['counterpart_guild_id'] as String,
      senderDeviceId: json['sender_device_id'] as String,
      recipientDeviceId: json['recipient_device_id'] as String,
      clientMessageId: json['client_message_id'] as String,
      protocolVersion: json['protocol_version'] as String,
      ciphertext: json['ciphertext'] as String,
      nonce: json['nonce'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      sentAtMs:
          (json['sent_at_ms'] as int?) ??
          DateTime.parse(json['sent_at'] as String).millisecondsSinceEpoch,
      encryptionMode: (json['encryption_mode'] as String?) ?? 'encrypted',
    );
  }
}
