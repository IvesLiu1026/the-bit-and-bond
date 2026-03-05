import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/quests/models.dart';
import '../auth/auth_session.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.authSession,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final AuthSession? authSession;
  final http.Client _httpClient;
  static const int _maxErrorSnippetLength = 180;

  Future<List<QuestInstance>> listQuests() async {
    final data = await _authedGet(
      '/api/v1/quests',
      const {},
      role: _AuthRole.any,
    );
    return (data as List)
        .map((item) => QuestInstance.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitQuest({required String questInstanceId}) async {
    await _authedPost(
      '/api/v1/quests/$questInstanceId/submit',
      const {},
      role: _AuthRole.any,
    );
  }

  Future<QuestReviewResult> reviewSubmission({
    required String submissionId,
    required bool approve,
    String? hunterId,
    String? reviewNote,
  }) async {
    final payload = <String, dynamic>{'approved': approve};
    final normalizedHunterId = hunterId?.trim();
    if (normalizedHunterId != null && normalizedHunterId.isNotEmpty) {
      payload['hunter_id'] = normalizedHunterId;
    }
    if (reviewNote != null && reviewNote.trim().isNotEmpty) {
      payload['review_note'] = reviewNote.trim();
    }

    final data = await _authedPost(
      '/api/v1/quests/$submissionId/review',
      payload,
      role: _AuthRole.owner,
    );
    return QuestReviewResult.fromJson(data as Map<String, dynamic>);
  }

  Future<Progression> getProgression({String? hunterId}) async {
    final session = _requireSession();
    final quests = await listQuests();
    final availableQuests = quests
        .where((q) => q.status == QuestStatus.available)
        .length;
    final submittedQuests = quests
        .where((q) => q.status == QuestStatus.submitted)
        .length;

    if (session.isGuildMaster) {
      final hunters = await listHunters();
      if (hunters.isEmpty) {
        return Progression(
          childMemberId: hunterId ?? '',
          level: 1,
          xp: 0,
          coins: 0,
          availableQuests: availableQuests,
          submittedQuests: submittedQuests,
        );
      }

      final selected = _resolveHunterSelection(hunters, hunterId);
      return Progression(
        childMemberId: selected.id,
        level: selected.level,
        xp: selected.xp,
        coins: selected.coins,
        availableQuests: availableQuests,
        submittedQuests: submittedQuests,
      );
    }

    final me = await getHunterMe();
    return Progression(
      childMemberId: me.id,
      level: me.level,
      xp: me.xp,
      coins: me.coins,
      availableQuests: availableQuests,
      submittedQuests: submittedQuests,
    );
  }

  Future<List<HunterProfile>> listHunters() async {
    final data = await _authedGet(
      '/api/v1/hunters',
      const {},
      role: _AuthRole.owner,
    );
    return (data as List)
        .map((item) => HunterProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<HunterProfile>> listGuildHunters() async {
    final data = await _authedGet(
      '/api/v1/hunters/roster',
      const {},
      role: _AuthRole.any,
    );
    return (data as List)
        .map((item) => HunterProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<HunterProfile> createHunter({
    required String name,
    required String avatarType,
    required String pinCode,
  }) async {
    final data = await _authedPost('/api/v1/hunters', {
      'name': name.trim(),
      'avatar_type': avatarType.trim(),
      'pin_code': pinCode.trim(),
    }, role: _AuthRole.owner);
    return HunterProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<HunterProfile> resetHunterPin({
    required String hunterId,
    required String pinCode,
  }) async {
    final data = await _authedPatch('/api/v1/hunters/$hunterId/pin', {
      'pin_code': pinCode.trim(),
    }, role: _AuthRole.owner);
    return HunterProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<HunterProfile> getHunterMe() async {
    final data = await _authedGet(
      '/api/v1/hunters/me',
      const {},
      role: _AuthRole.any,
    );
    return HunterProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<HunterStatsSummary> getHunterStats({required String hunterId}) async {
    final data = await _authedGet(
      '/api/v1/hunters/$hunterId/stats',
      const {},
      role: _AuthRole.any,
    );
    return HunterStatsSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<QuestInstance> createQuest({
    required String title,
    String? description,
    required int rewardXp,
    required int rewardCoins,
    required QuestStatCategory statCategory,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'reward_xp': rewardXp,
      'reward_coins': rewardCoins,
      'stat_category': questStatCategoryToApiValue(statCategory),
    };
    final normalizedDescription = description?.trim();
    if (normalizedDescription != null && normalizedDescription.isNotEmpty) {
      payload['description'] = normalizedDescription;
    }
    final data = await _authedPost(
      '/api/v1/quests',
      payload,
      role: _AuthRole.owner,
    );
    return QuestInstance.fromJson(data as Map<String, dynamic>);
  }

  Future<List<GuildShopItem>> listShopItems({
    bool includeInactive = false,
  }) async {
    final query = <String, String>{};
    if (includeInactive) {
      query['include_inactive'] = 'true';
    }
    final data = await _authedGet(
      '/api/v1/shop/items',
      query,
      role: _AuthRole.any,
    );
    return (data as List)
        .map((item) => GuildShopItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ShopPurchaseResult> buyShopItem({
    required String itemId,
    required String idempotencyKey,
  }) async {
    final data = await _authedPost('/api/v1/shop/buy/$itemId', {
      'idempotency_key': idempotencyKey,
    }, role: _AuthRole.any);
    return ShopPurchaseResult.fromJson(data as Map<String, dynamic>);
  }

  Future<GuildShopItem> createShopItem({
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  }) async {
    final data = await _authedPost('/api/v1/shop/items', {
      'name': name,
      'description': description,
      'cost_coins': costCoins,
      'icon_tag': iconTag,
    }, role: _AuthRole.owner);
    return GuildShopItem.fromJson(data as Map<String, dynamic>);
  }

  Future<GuildShopItem> updateShopItem({
    required String itemId,
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  }) async {
    final data = await _authedPut('/api/v1/shop/items/$itemId', {
      'name': name,
      'description': description,
      'cost_coins': costCoins,
      'icon_tag': iconTag,
    }, role: _AuthRole.owner);
    return GuildShopItem.fromJson(data as Map<String, dynamic>);
  }

  Future<GuildShopItem> deactivateShopItem({required String itemId}) async {
    final data = await _authedDelete(
      '/api/v1/shop/items/$itemId',
      role: _AuthRole.owner,
    );
    return GuildShopItem.fromJson(data as Map<String, dynamic>);
  }

  Future<List<InventoryItem>> listInventory() async {
    final data = await _authedGet(
      '/api/v1/inventory',
      const {},
      role: _AuthRole.any,
    );
    return (data as List)
        .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<InventoryUseResult> useInventoryItem({required String itemId}) async {
    final data = await _authedPost(
      '/api/v1/inventory/use/$itemId',
      const {},
      role: _AuthRole.any,
    );
    return InventoryUseResult.fromJson(data as Map<String, dynamic>);
  }

  Future<RealtimeWsTicket> issueRealtimeTicket() async {
    final data = await _authedPost(
      '/api/v1/realtime/ticket',
      const {},
      role: _AuthRole.any,
    );
    return RealtimeWsTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<VoiceTokenBundle> issueVoiceToken({String? roomId}) async {
    final payload = <String, dynamic>{};
    final normalizedRoomId = roomId?.trim();
    if (normalizedRoomId != null && normalizedRoomId.isNotEmpty) {
      payload['room_id'] = normalizedRoomId;
    }
    final data = await _authedPost(
      '/api/v1/voice/token',
      payload,
      role: _AuthRole.any,
    );
    return VoiceTokenBundle.fromJson(data as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> getChatHistory({
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
    final data = await _authedGet(
      '/api/v1/chat/history',
      query,
      role: _AuthRole.any,
    );
    return (data as List)
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> persistChatMessage({
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
    final data = await _authedPost(
      '/api/v1/chat/messages',
      payload,
      role: _AuthRole.any,
    );
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  Future<List<FriendProfile>> listFriends() async {
    final data = await _authedGet(
      '/api/v1/social/friends',
      const {},
      role: _AuthRole.any,
    );
    return (data as List)
        .map((item) => FriendProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FriendProfile> addFriend({required String playerId}) async {
    final data = await _authedPost('/api/v1/social/friends', {
      'player_id': playerId.trim(),
    }, role: _AuthRole.any);
    return FriendProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<FriendRequestInfo> requestFriend({required String playerId}) async {
    final data = await _authedPost('/api/v1/friends/request', {
      'player_id': playerId.trim(),
    }, role: _AuthRole.any);
    return FriendRequestInfo.fromJson(data as Map<String, dynamic>);
  }

  Future<List<FriendRequestInfo>> listIncomingFriendRequests() async {
    final data = await _authedGet(
      '/api/v1/friends/requests/incoming',
      const {},
      role: _AuthRole.any,
    );
    return (data as List)
        .map((item) => FriendRequestInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FriendRequestInfo> respondFriendRequest({
    required String requestId,
    required bool accept,
  }) async {
    final data = await _authedPost(
      '/api/v1/friends/requests/$requestId/respond',
      {'accept': accept},
      role: _AuthRole.any,
    );
    return FriendRequestInfo.fromJson(data as Map<String, dynamic>);
  }

  Future<GuildInviteInfo> inviteFriendToGuild({
    required String playerId,
  }) async {
    final data = await _authedPost('/api/v1/guilds/summon', {
      'player_id': playerId.trim(),
    }, role: _AuthRole.any);
    return GuildInviteInfo.fromJson(data as Map<String, dynamic>);
  }

  Future<List<GuildInviteInfo>> listMyGuildInvites() async {
    final data = await _authedGet(
      '/api/v1/social/guild/invites',
      const {},
      role: _AuthRole.any,
    );
    return (data as List)
        .map((item) => GuildInviteInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GuildInviteInfo> respondGuildInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final data = await _authedPost(
      '/api/v1/social/guild/invites/$inviteId/respond',
      {'accept': accept},
      role: _AuthRole.any,
    );
    return GuildInviteInfo.fromJson(data as Map<String, dynamic>);
  }

  Future<SocialProfile> getSocialProfile() async {
    final data = await _authedGet(
      '/api/v1/social/profile',
      const {},
      role: _AuthRole.any,
    );
    return SocialProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<SocialProfile> updateSocialProfile({String? motto}) async {
    final payload = <String, dynamic>{'motto': motto?.trim() ?? ''};
    final data = await _authedPatch(
      '/api/v1/social/profile',
      payload,
      role: _AuthRole.any,
    );
    return SocialProfile.fromJson(data as Map<String, dynamic>);
  }

  HunterProfile _resolveHunterSelection(
    List<HunterProfile> hunters,
    String? hunterId,
  ) {
    if (hunterId == null || hunterId.trim().isEmpty) {
      return hunters.first;
    }
    final normalized = hunterId.trim();
    for (final hunter in hunters) {
      if (hunter.id == normalized) {
        return hunter;
      }
    }
    return hunters.first;
  }

  Future<dynamic> _authedGet(
    String path,
    Map<String, String> query, {
    required _AuthRole role,
  }) async {
    final token = _resolveTokenForRole(role);
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _httpClient
        .get(uri, headers: _bearerHeaders(token))
        .timeout(const Duration(seconds: 10));
    return _parseResponse(response);
  }

  Future<dynamic> _authedPost(
    String path,
    Map<String, dynamic> payload, {
    required _AuthRole role,
  }) async {
    final token = _resolveTokenForRole(role);
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient
        .post(
          uri,
          headers: _jsonBearerHeaders(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));
    return _parseResponse(response);
  }

  Future<dynamic> _authedPatch(
    String path,
    Map<String, dynamic> payload, {
    required _AuthRole role,
  }) async {
    final token = _resolveTokenForRole(role);
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient
        .patch(
          uri,
          headers: _jsonBearerHeaders(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));
    return _parseResponse(response);
  }

  Future<dynamic> _authedPut(
    String path,
    Map<String, dynamic> payload, {
    required _AuthRole role,
  }) async {
    final token = _resolveTokenForRole(role);
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient
        .put(uri, headers: _jsonBearerHeaders(token), body: jsonEncode(payload))
        .timeout(const Duration(seconds: 10));
    return _parseResponse(response);
  }

  Future<dynamic> _authedDelete(String path, {required _AuthRole role}) async {
    final token = _resolveTokenForRole(role);
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient
        .delete(uri, headers: _jsonBearerHeaders(token))
        .timeout(const Duration(seconds: 10));
    return _parseResponse(response);
  }

  String _resolveTokenForRole(_AuthRole role) {
    final session = _requireSession();
    switch (role) {
      case _AuthRole.any:
        return session.accessToken;
      case _AuthRole.owner:
        if (!session.isGuildMaster) {
          throw ApiException('guild owner role required', 403);
        }
        return session.accessToken;
    }
  }

  AuthSession _requireSession() {
    final session = authSession;
    if (session == null || session.accessToken.isEmpty) {
      throw ApiException('authentication required', 401);
    }
    if (session.hunterId.trim().isEmpty) {
      throw ApiException('session missing hunter_id, please login again', 401);
    }
    return session;
  }

  Map<String, String> _bearerHeaders(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  Map<String, String> _jsonBearerHeaders(String token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    'ngrok-skip-browser-warning': 'true',
  };

  dynamic _parseResponse(http.Response response) {
    final rawBody = response.body;
    dynamic body = <String, dynamic>{};
    if (rawBody.isNotEmpty) {
      try {
        body = jsonDecode(rawBody) as dynamic;
      } on FormatException {
        final snippet = _compactSnippet(rawBody);
        if (snippet.contains('ERR_NGROK_6024')) {
          throw ApiException(
            'ngrok warning page intercepted the API response; please refresh the app and retry',
            response.statusCode,
          );
        }
        throw ApiException(
          'expected JSON response but received: $snippet',
          response.statusCode,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (body is Map<String, dynamic> && body['error'] is String) {
      throw ApiException(body['error'] as String, response.statusCode);
    }

    throw ApiException(
      'API request failed with status ${response.statusCode}'
      '${rawBody.isEmpty ? '' : ' (${_compactSnippet(rawBody)})'}',
      response.statusCode,
    );
  }

  String _compactSnippet(String body) {
    final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= _maxErrorSnippetLength) {
      return compact;
    }
    return '${compact.substring(0, _maxErrorSnippetLength)}...';
  }
}

enum _AuthRole { any, owner }

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException(status: $statusCode, message: $message)';
}

class RealtimeWsTicket {
  const RealtimeWsTicket({required this.ticket, required this.expiresIn});

  final String ticket;
  final int expiresIn;

  factory RealtimeWsTicket.fromJson(Map<String, dynamic> json) {
    return RealtimeWsTicket(
      ticket: (json['ticket'] ?? '') as String,
      expiresIn: (json['expires_in'] ?? 0) as int,
    );
  }
}
