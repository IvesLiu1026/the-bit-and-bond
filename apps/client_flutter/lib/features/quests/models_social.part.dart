part of 'models.dart';

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

class PlayerPassQrBundle {
  PlayerPassQrBundle({
    required this.qrValue,
    required this.tokenType,
    required this.expiresIn,
    required this.expiresAt,
  });

  final String qrValue;
  final String tokenType;
  final int expiresIn;
  final DateTime expiresAt;

  factory PlayerPassQrBundle.fromJson(Map<String, dynamic> json) {
    return PlayerPassQrBundle(
      qrValue: json['qr_value'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.parse(json['expires_at'] as String),
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
