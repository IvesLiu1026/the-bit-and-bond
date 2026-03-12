part of 'api_client.dart';

Future<List<FriendProfile>> _apiClientListFriends(ApiClient api) async {
  final data = await api._authedGet(
    '/api/v1/social/friends',
    const {},
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => FriendProfile.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<FriendProfile> _apiClientAddFriend(
  ApiClient api, {
  required String playerId,
}) async {
  final data = await api._authedPost('/api/v1/social/friends', {
    'player_id': playerId.trim(),
  }, role: _AuthRole.any);
  return FriendProfile.fromJson(data as Map<String, dynamic>);
}

Future<FriendRequestInfo> _apiClientRequestFriend(
  ApiClient api, {
  required String playerId,
}) async {
  final data = await api._authedPost('/api/v1/friends/request', {
    'player_id': playerId.trim(),
  }, role: _AuthRole.any);
  return FriendRequestInfo.fromJson(data as Map<String, dynamic>);
}

Future<List<FriendRequestInfo>> _apiClientListIncomingFriendRequests(
  ApiClient api,
) async {
  final data = await api._authedGet(
    '/api/v1/friends/requests/incoming',
    const {},
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => FriendRequestInfo.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<FriendRequestInfo> _apiClientRespondFriendRequest(
  ApiClient api, {
  required String requestId,
  required bool accept,
}) async {
  final data = await api._authedPost(
    '/api/v1/friends/requests/$requestId/respond',
    {'accept': accept},
    role: _AuthRole.any,
  );
  return FriendRequestInfo.fromJson(data as Map<String, dynamic>);
}

Future<GuildInviteInfo> _apiClientInviteFriendToGuild(
  ApiClient api, {
  required String playerId,
}) async {
  final data = await api._authedPost('/api/v1/guilds/summon', {
    'player_id': playerId.trim(),
  }, role: _AuthRole.any);
  return GuildInviteInfo.fromJson(data as Map<String, dynamic>);
}

Future<List<GuildInviteInfo>> _apiClientListMyGuildInvites(
  ApiClient api,
) async {
  final data = await api._authedGet(
    '/api/v1/social/guild/invites',
    const {},
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => GuildInviteInfo.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<GuildInviteInfo> _apiClientRespondGuildInvite(
  ApiClient api, {
  required String inviteId,
  required bool accept,
}) async {
  final data = await api._authedPost(
    '/api/v1/social/guild/invites/$inviteId/respond',
    {'accept': accept},
    role: _AuthRole.any,
  );
  return GuildInviteInfo.fromJson(data as Map<String, dynamic>);
}

Future<SocialProfile> _apiClientGetSocialProfile(ApiClient api) async {
  final data = await api._authedGet(
    '/api/v1/social/profile',
    const {},
    role: _AuthRole.any,
  );
  return SocialProfile.fromJson(data as Map<String, dynamic>);
}

Future<PlayerPassQrBundle> _apiClientGetPlayerPassQrBundle(
  ApiClient api,
) async {
  final data = await api._authedGet(
    '/api/v1/social/profile/pass-qr',
    const {},
    role: _AuthRole.any,
  );
  return PlayerPassQrBundle.fromJson(data as Map<String, dynamic>);
}

Future<SocialProfile> _apiClientUpdateSocialProfile(
  ApiClient api, {
  String? motto,
}) async {
  final payload = <String, dynamic>{'motto': motto?.trim() ?? ''};
  final data = await api._authedPatch(
    '/api/v1/social/profile',
    payload,
    role: _AuthRole.any,
  );
  return SocialProfile.fromJson(data as Map<String, dynamic>);
}
