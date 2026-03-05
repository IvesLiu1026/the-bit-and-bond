enum QuestStatus { available, submitted, approved, rejected }

enum QuestCategory { chore, study, exam, habit, unknown }

enum QuestStatCategory {
  strength,
  intelligence,
  agility,
  vitality,
  charisma,
  none,
}

QuestStatus parseQuestStatus(String value) {
  switch (value.toLowerCase()) {
    case 'available':
      return QuestStatus.available;
    case 'pendingreview':
    case 'pending_review':
    case 'submitted':
      return QuestStatus.submitted;
    case 'completed':
    case 'approved':
      return QuestStatus.approved;
    case 'rejected':
      return QuestStatus.rejected;
    default:
      return QuestStatus.available;
  }
}

QuestCategory parseQuestCategory(String? value) {
  switch (value) {
    case 'chore':
      return QuestCategory.chore;
    case 'study':
      return QuestCategory.study;
    case 'exam':
      return QuestCategory.exam;
    case 'habit':
      return QuestCategory.habit;
    default:
      return QuestCategory.unknown;
  }
}

QuestStatCategory parseQuestStatCategory(String? value) {
  switch (value?.toLowerCase()) {
    case 'str':
    case 'strength':
      return QuestStatCategory.strength;
    case 'int':
    case 'intelligence':
      return QuestStatCategory.intelligence;
    case 'agi':
    case 'agility':
      return QuestStatCategory.agility;
    case 'vit':
    case 'vitality':
      return QuestStatCategory.vitality;
    case 'cha':
    case 'charisma':
      return QuestStatCategory.charisma;
    case 'none':
      return QuestStatCategory.none;
    default:
      return QuestStatCategory.none;
  }
}

String questStatCategoryToApiValue(QuestStatCategory value) {
  return switch (value) {
    QuestStatCategory.strength => 'STR',
    QuestStatCategory.intelligence => 'INT',
    QuestStatCategory.agility => 'AGI',
    QuestStatCategory.vitality => 'VIT',
    QuestStatCategory.charisma => 'CHA',
    QuestStatCategory.none => 'NONE',
  };
}

class QuestInstance {
  QuestInstance({
    required this.id,
    required this.templateId,
    required this.templateTitle,
    required this.category,
    required this.statCategory,
    required this.baseXp,
    required this.baseCoins,
    required this.status,
    required this.dueAt,
    required this.updatedAt,
  });

  final String id;
  final String templateId;
  final String? templateTitle;
  final QuestCategory category;
  final QuestStatCategory statCategory;
  final int? baseXp;
  final int? baseCoins;
  final QuestStatus status;
  final DateTime? dueAt;
  final DateTime updatedAt;

  factory QuestInstance.fromJson(Map<String, dynamic> json) {
    final updatedAtRaw =
        json['updated_at'] ?? json['submitted_at'] ?? json['reviewed_at'];

    return QuestInstance(
      id: json['id'] as String,
      templateId: (json['template_id'] ?? json['id']) as String,
      templateTitle: (json['template_title'] ?? json['title']) as String?,
      category: parseQuestCategory(json['category'] as String?),
      statCategory: parseQuestStatCategory(
        (json['stat_category'] ?? json['category']) as String?,
      ),
      baseXp: (json['base_xp'] ?? json['reward_xp']) as int?,
      baseCoins: (json['base_coins'] ?? json['reward_coins']) as int?,
      status: parseQuestStatus(json['status'] as String),
      dueAt: json['due_at'] != null
          ? DateTime.parse(json['due_at'] as String)
          : null,
      updatedAt: updatedAtRaw == null
          ? DateTime.now()
          : DateTime.parse(updatedAtRaw as String),
    );
  }
}

class Progression {
  Progression({
    required this.childMemberId,
    required this.level,
    required this.xp,
    required this.coins,
    required this.availableQuests,
    required this.submittedQuests,
  });

  final String childMemberId;
  final int level;
  final int xp;
  final int coins;
  final int availableQuests;
  final int submittedQuests;

  factory Progression.fromJson(Map<String, dynamic> json) {
    return Progression(
      childMemberId: (json['child_member_id'] ?? json['id'] ?? '') as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      coins: json['coins'] as int,
      availableQuests:
          (json['available_quests'] ?? json['available_quests_count'] ?? 0)
              as int,
      submittedQuests:
          (json['submitted_quests'] ?? json['pending_review_count'] ?? 0)
              as int,
    );
  }
}

class HunterProfile {
  HunterProfile({
    required this.id,
    required this.guildId,
    this.playerId,
    required this.name,
    required this.avatarType,
    required this.level,
    required this.xp,
    required this.coins,
  });

  final String id;
  final String guildId;
  final String? playerId;
  final String name;
  final String avatarType;
  final int level;
  final int xp;
  final int coins;

  factory HunterProfile.fromJson(Map<String, dynamic> json) {
    return HunterProfile(
      id: json['id'] as String,
      guildId: json['guild_id'] as String,
      playerId: json['player_id'] as String?,
      name: json['name'] as String,
      avatarType: json['avatar_type'] as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      coins: json['coins'] as int,
    );
  }
}

class HunterRewardSnapshot {
  HunterRewardSnapshot({
    required this.id,
    required this.guildId,
    required this.level,
    required this.xp,
    required this.coins,
  });

  final String id;
  final String guildId;
  final int level;
  final int xp;
  final int coins;

  factory HunterRewardSnapshot.fromJson(Map<String, dynamic> json) {
    return HunterRewardSnapshot(
      id: json['id'] as String,
      guildId: json['guild_id'] as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      coins: json['coins'] as int,
    );
  }
}

class QuestReviewReward {
  QuestReviewReward({
    required this.rewardEventId,
    required this.hunterId,
    required this.gainedXp,
    required this.gainedCoins,
    required this.leveledUp,
    required this.newLevel,
  });

  final String rewardEventId;
  final String hunterId;
  final int gainedXp;
  final int gainedCoins;
  final bool leveledUp;
  final int newLevel;

  factory QuestReviewReward.fromJson(Map<String, dynamic> json) {
    return QuestReviewReward(
      rewardEventId: json['reward_event_id'] as String,
      hunterId: json['hunter_id'] as String,
      gainedXp: json['gained_xp'] as int,
      gainedCoins: json['gained_coins'] as int,
      leveledUp: json['leveled_up'] as bool? ?? false,
      newLevel: json['new_level'] as int? ?? 1,
    );
  }
}

class QuestReviewResult {
  QuestReviewResult({
    required this.quest,
    required this.hunter,
    required this.reward,
  });

  final QuestInstance quest;
  final HunterRewardSnapshot? hunter;
  final QuestReviewReward? reward;

  factory QuestReviewResult.fromJson(Map<String, dynamic> json) {
    return QuestReviewResult(
      quest: QuestInstance.fromJson((json['quest'] as Map<String, dynamic>)),
      hunter: json['hunter'] is Map<String, dynamic>
          ? HunterRewardSnapshot.fromJson(
              json['hunter'] as Map<String, dynamic>,
            )
          : null,
      reward: json['reward'] is Map<String, dynamic>
          ? QuestReviewReward.fromJson(json['reward'] as Map<String, dynamic>)
          : null,
    );
  }
}

class FriendProfile {
  FriendProfile({
    required this.id,
    required this.playerId,
    required this.name,
    required this.guildId,
    required this.avatarType,
    required this.level,
    required this.xp,
    required this.coins,
  });

  final String id;
  final String playerId;
  final String name;
  final String guildId;
  final String avatarType;
  final int level;
  final int xp;
  final int coins;

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      name: json['name'] as String,
      guildId: json['guild_id'] as String,
      avatarType: json['avatar_type'] as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      coins: json['coins'] as int,
    );
  }
}

class GuildInviteInfo {
  GuildInviteInfo({
    required this.id,
    required this.guildId,
    required this.inviterHunterId,
    required this.inviterPlayerId,
    required this.inviterName,
    required this.invitedHunterId,
    required this.invitedPlayerId,
    required this.invitedName,
    required this.status,
    required this.createdAt,
    required this.respondedAt,
  });

  final String id;
  final String guildId;
  final String inviterHunterId;
  final String inviterPlayerId;
  final String inviterName;
  final String invitedHunterId;
  final String invitedPlayerId;
  final String invitedName;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  factory GuildInviteInfo.fromJson(Map<String, dynamic> json) {
    return GuildInviteInfo(
      id: json['id'] as String,
      guildId: json['guild_id'] as String,
      inviterHunterId: json['inviter_hunter_id'] as String,
      inviterPlayerId: json['inviter_player_id'] as String,
      inviterName: json['inviter_name'] as String,
      invitedHunterId: json['invited_hunter_id'] as String,
      invitedPlayerId: json['invited_player_id'] as String,
      invitedName: json['invited_name'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] == null
          ? null
          : DateTime.parse(json['responded_at'] as String),
    );
  }
}

class FriendRequestInfo {
  FriendRequestInfo({
    required this.id,
    required this.requesterHunterId,
    required this.requesterPlayerId,
    required this.requesterName,
    required this.targetHunterId,
    required this.targetPlayerId,
    required this.targetName,
    required this.status,
    required this.createdAt,
    required this.respondedAt,
  });

  final String id;
  final String requesterHunterId;
  final String requesterPlayerId;
  final String requesterName;
  final String targetHunterId;
  final String targetPlayerId;
  final String targetName;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  factory FriendRequestInfo.fromJson(Map<String, dynamic> json) {
    return FriendRequestInfo(
      id: json['id'] as String,
      requesterHunterId: json['requester_hunter_id'] as String,
      requesterPlayerId: json['requester_player_id'] as String,
      requesterName: json['requester_name'] as String,
      targetHunterId: json['target_hunter_id'] as String,
      targetPlayerId: json['target_player_id'] as String,
      targetName: json['target_name'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] == null
          ? null
          : DateTime.parse(json['responded_at'] as String),
    );
  }
}

class SocialProfile {
  SocialProfile({
    required this.guildId,
    required this.guildName,
    required this.roleTitle,
    required this.playerId,
    required this.hunterTag,
    required this.displayName,
    required this.level,
    required this.xp,
    required this.coins,
    this.motto,
  });

  final String guildId;
  final String guildName;
  final String roleTitle;
  final String? playerId;
  final String hunterTag;
  final String displayName;
  final int level;
  final int xp;
  final int coins;
  final String? motto;

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    return SocialProfile(
      guildId: json['guild_id'] as String,
      guildName: json['guild_name'] as String,
      roleTitle: json['role_title'] as String,
      playerId: json['player_id'] as String?,
      hunterTag: json['hunter_tag'] as String,
      displayName: json['display_name'] as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      coins: json['coins'] as int,
      motto: json['motto'] as String?,
    );
  }
}

class HunterStatsSummary {
  HunterStatsSummary({
    required this.hunterId,
    required this.guildId,
    required this.strXp,
    required this.intXp,
    required this.agiXp,
    required this.chaXp,
    required this.vitXp,
    required this.noneXp,
    required this.totalXp,
    required this.totalCoins,
    required this.entryCount,
  });

  final String hunterId;
  final String guildId;
  final int strXp;
  final int intXp;
  final int agiXp;
  final int chaXp;
  final int vitXp;
  final int noneXp;
  final int totalXp;
  final int totalCoins;
  final int entryCount;

  List<int> get radarValues => [strXp, intXp, agiXp, chaXp, vitXp];

  factory HunterStatsSummary.fromJson(Map<String, dynamic> json) {
    final stat = (json['stat_xp'] as Map<String, dynamic>?) ?? const {};
    return HunterStatsSummary(
      hunterId: json['hunter_id'] as String,
      guildId: json['guild_id'] as String,
      strXp: (stat['str_xp'] as int?) ?? 0,
      intXp: (stat['int_xp'] as int?) ?? 0,
      agiXp: (stat['agi_xp'] as int?) ?? 0,
      chaXp: (stat['cha_xp'] as int?) ?? 0,
      vitXp: (stat['vit_xp'] as int?) ?? 0,
      noneXp: (stat['none_xp'] as int?) ?? 0,
      totalXp: (json['total_xp'] as int?) ?? 0,
      totalCoins: (json['total_coins'] as int?) ?? 0,
      entryCount: (json['entry_count'] as int?) ?? 0,
    );
  }
}

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
}
