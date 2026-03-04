enum AuthUserRole { guildMaster, hunter }

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.role,
    required this.guildId,
    required this.hunterId,
    this.inviteCode,
  });

  final String accessToken;
  final AuthUserRole role;
  final String guildId;
  final String? hunterId;
  final String? inviteCode;

  bool get isGuildMaster => role == AuthUserRole.guildMaster;
  bool get isHunter => role == AuthUserRole.hunter;

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'role': _roleToJson(role),
      'guild_id': guildId,
      'hunter_id': hunterId,
      'invite_code': inviteCode,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: (json['access_token'] ?? '') as String,
      role: _roleFromJson((json['role'] ?? 'hunter') as String),
      guildId: (json['guild_id'] ?? '') as String,
      hunterId: json['hunter_id'] as String?,
      inviteCode: json['invite_code'] as String?,
    );
  }

  static String _roleToJson(AuthUserRole role) {
    return switch (role) {
      AuthUserRole.guildMaster => 'guild_master',
      AuthUserRole.hunter => 'hunter',
    };
  }

  static AuthUserRole _roleFromJson(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'guild_master':
        return AuthUserRole.guildMaster;
      case 'hunter':
      default:
        return AuthUserRole.hunter;
    }
  }
}
