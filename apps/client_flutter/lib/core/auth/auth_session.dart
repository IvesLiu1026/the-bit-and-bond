enum GuildRole { master, member }

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.guildId,
    required this.hunterId,
    required this.guildRole,
    this.inviteCode,
    this.playerId,
    this.displayName,
    this.avatarType,
  });

  final String accessToken;
  final String guildId;
  final String hunterId;
  final GuildRole guildRole;
  final String? inviteCode;
  final String? playerId;
  final String? displayName;
  final String? avatarType;

  bool get isGuildMaster => guildRole == GuildRole.master;
  bool get isMember => guildRole == GuildRole.member;

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'guild_id': guildId,
      'hunter_id': hunterId,
      'guild_role': _guildRoleToJson(guildRole),
      'invite_code': inviteCode,
      'player_id': playerId,
      'display_name': displayName,
      'avatar_type': avatarType,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawHunterId = (json['hunter_id'] as String?)?.trim();
    final hunterId = rawHunterId == null || rawHunterId.isEmpty
        ? ''
        : rawHunterId;
    return AuthSession(
      accessToken: (json['access_token'] ?? '') as String,
      guildId: (json['guild_id'] ?? '') as String,
      hunterId: hunterId,
      guildRole: _guildRoleFromJson(
        guildRoleRaw: json['guild_role'] as String?,
      ),
      inviteCode: json['invite_code'] as String?,
      playerId: json['player_id'] as String?,
      displayName: json['display_name'] as String?,
      avatarType: json['avatar_type'] as String?,
    );
  }

  static String _guildRoleToJson(GuildRole role) {
    return switch (role) {
      GuildRole.master => 'master',
      GuildRole.member => 'member',
    };
  }

  static GuildRole _guildRoleFromJson({String? guildRoleRaw}) {
    final normalizedGuildRole = guildRoleRaw?.trim().toLowerCase();
    if (normalizedGuildRole == 'master') {
      return GuildRole.master;
    }
    if (normalizedGuildRole == 'member') {
      return GuildRole.member;
    }
    return GuildRole.member;
  }
}
