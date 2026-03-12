part of 'models.dart';

class GuildShopItem {
  GuildShopItem({
    required this.id,
    required this.guildId,
    required this.name,
    required this.description,
    required this.costCoins,
    required this.iconTag,
    required this.isActive,
  });

  final String id;
  final String guildId;
  final String name;
  final String? description;
  final int costCoins;
  final String iconTag;
  final bool isActive;

  factory GuildShopItem.fromJson(Map<String, dynamic> json) {
    return GuildShopItem(
      id: json['id'] as String,
      guildId: json['guild_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      costCoins: (json['cost_coins'] as int?) ?? 0,
      iconTag: (json['icon_tag'] as String?) ?? 'UNKNOWN',
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

class ShopPurchaseResult {
  ShopPurchaseResult({
    required this.ledgerEventId,
    required this.idempotencyKey,
    required this.hunterId,
    required this.item,
    required this.spentCoins,
    required this.remainingCoins,
    required this.inventoryQuantity,
    required this.replayed,
  });

  final String ledgerEventId;
  final String idempotencyKey;
  final String hunterId;
  final GuildShopItem item;
  final int spentCoins;
  final int remainingCoins;
  final int inventoryQuantity;
  final bool replayed;

  factory ShopPurchaseResult.fromJson(Map<String, dynamic> json) {
    return ShopPurchaseResult(
      ledgerEventId: json['ledger_event_id'] as String,
      idempotencyKey: json['idempotency_key'] as String,
      hunterId: json['hunter_id'] as String,
      item: GuildShopItem.fromJson(json['item'] as Map<String, dynamic>),
      spentCoins: (json['spent_coins'] as int?) ?? 0,
      remainingCoins: (json['remaining_coins'] as int?) ?? 0,
      inventoryQuantity: (json['inventory_quantity'] as int?) ?? 0,
      replayed: json['replayed'] as bool? ?? false,
    );
  }
}

class InventoryItem {
  InventoryItem({
    required this.itemId,
    required this.name,
    required this.description,
    required this.iconTag,
    required this.quantity,
    required this.updatedAt,
  });

  final String itemId;
  final String name;
  final String? description;
  final String iconTag;
  final int quantity;
  final DateTime updatedAt;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      itemId: json['item_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconTag: (json['icon_tag'] as String?) ?? 'UNKNOWN',
      quantity: (json['quantity'] as int?) ?? 0,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class InventoryUseResult {
  InventoryUseResult({
    required this.itemId,
    required this.itemName,
    required this.remainingQuantity,
    required this.systemMessage,
    required this.chatMessageId,
  });

  final String itemId;
  final String itemName;
  final int remainingQuantity;
  final String systemMessage;
  final String chatMessageId;

  factory InventoryUseResult.fromJson(Map<String, dynamic> json) {
    return InventoryUseResult(
      itemId: json['item_id'] as String,
      itemName: json['item_name'] as String,
      remainingQuantity: (json['remaining_quantity'] as int?) ?? 0,
      systemMessage: (json['system_message'] as String?) ?? '',
      chatMessageId: (json['chat_message_id'] as String?) ?? '',
    );
  }
}

class VoiceTokenBundle {
  VoiceTokenBundle({
    required this.url,
    required this.roomId,
    required this.token,
    required this.identity,
    required this.displayName,
    required this.chatTopic,
    required this.expiresIn,
  });

  final String url;
  final String roomId;
  final String token;
  final String identity;
  final String displayName;
  final String chatTopic;
  final int expiresIn;

  factory VoiceTokenBundle.fromJson(Map<String, dynamic> json) {
    return VoiceTokenBundle(
      url: json['url'] as String,
      roomId: json['room_id'] as String,
      token: json['token'] as String,
      identity: json['identity'] as String,
      displayName: json['display_name'] as String,
      chatTopic: (json['chat_topic'] as String?) ?? 'guild.chat',
      expiresIn: (json['expires_in'] as int?) ?? 0,
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.guildId,
    required this.roomId,
    required this.senderHunterId,
    required this.senderName,
    required this.clientMessageId,
    required this.content,
    required this.sentAt,
    required this.sentAtMs,
  });

  final String id;
  final String guildId;
  final String roomId;
  final String senderHunterId;
  final String senderName;
  final String clientMessageId;
  final String content;
  final DateTime sentAt;
  final int sentAtMs;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      guildId: json['guild_id'] as String,
      roomId: json['room_id'] as String,
      senderHunterId: json['sender_hunter_id'] as String,
      senderName: json['sender_name'] as String,
      clientMessageId: json['client_message_id'] as String,
      content: json['content'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      sentAtMs:
          (json['sent_at_ms'] as int?) ??
          DateTime.parse(json['sent_at'] as String).millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'guild_id': guildId,
      'room_id': roomId,
      'sender_hunter_id': senderHunterId,
      'sender_name': senderName,
      'client_message_id': clientMessageId,
      'content': content,
      'sent_at': sentAt.toUtc().toIso8601String(),
      'sent_at_ms': sentAtMs,
    };
  }
}
