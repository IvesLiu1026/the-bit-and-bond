import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/quests/models.dart';
import '../auth/auth_session.dart';

part 'api_client_direct_messages.part.dart';
part 'api_client_quests.part.dart';
part 'api_client_social.part.dart';
part 'api_client_voice.part.dart';

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

  Future<List<QuestInstance>> listQuests() => _apiClientListQuests(this);

  Future<void> submitQuest({required String questInstanceId}) =>
      _apiClientSubmitQuest(this, questInstanceId: questInstanceId);

  Future<void> submitQuestProof({
    required String questInstanceId,
    String? proofNote,
    QuestProofUpload? proofMedia,
  }) => _apiClientSubmitQuestProof(
    this,
    questInstanceId: questInstanceId,
    proofNote: proofNote,
    proofMedia: proofMedia,
  );

  Future<QuestProofMedia> uploadQuestProofMedia({
    required String questInstanceId,
    required QuestProofUpload upload,
  }) => _apiClientUploadQuestProofMedia(
    this,
    questInstanceId: questInstanceId,
    upload: upload,
  );

  Future<QuestReviewResult> reviewSubmission({
    required String submissionId,
    required bool approve,
    String? hunterId,
    String? reviewNote,
  }) => _apiClientReviewSubmission(
    this,
    submissionId: submissionId,
    approve: approve,
    hunterId: hunterId,
    reviewNote: reviewNote,
  );

  Future<Progression> getProgression({String? hunterId}) =>
      _apiClientGetProgression(this, hunterId: hunterId);

  Future<QuestInstance> createQuest({
    required String title,
    String? description,
    required int rewardXp,
    required int rewardCoins,
    required QuestStatCategory statCategory,
    QuestCategory category = QuestCategory.chore,
    String? assignedHunterId,
    HabitCadence cadence = HabitCadence.none,
  }) => _apiClientCreateQuest(
    this,
    title: title,
    description: description,
    rewardXp: rewardXp,
    rewardCoins: rewardCoins,
    statCategory: statCategory,
    category: category,
    assignedHunterId: assignedHunterId,
    cadence: cadence,
  );

  Future<VoiceTokenBundle> issueVoiceToken({String? roomId}) =>
      _apiClientIssueVoiceToken(this, roomId: roomId);

  Future<List<ChatMessage>> getChatHistory({
    String? roomId,
    int limit = 50,
    int? beforeMs,
  }) => _apiClientGetChatHistory(
    this,
    roomId: roomId,
    limit: limit,
    beforeMs: beforeMs,
  );

  Future<ChatMessage> persistChatMessage({
    required String content,
    String? roomId,
    String? clientMessageId,
    int? sentAtMs,
  }) => _apiClientPersistChatMessage(
    this,
    content: content,
    roomId: roomId,
    clientMessageId: clientMessageId,
    sentAtMs: sentAtMs,
  );

  Future<List<DirectMessageThread>> listDirectMessageThreads({
    int limit = 40,
  }) => _apiClientListDirectMessageThreads(this, limit: limit);

  Future<void> markDirectMessageThreadRead({
    required String counterpartHunterId,
  }) => _apiClientMarkDirectMessageThreadRead(
    this,
    counterpartHunterId: counterpartHunterId,
  );

  Future<List<DmDeviceKey>> listDirectMessageDeviceKeys({
    required String hunterId,
  }) => _apiClientListDirectMessageDeviceKeys(this, hunterId: hunterId);

  Future<Map<String, List<DmDeviceKey>>> listDirectMessageDeviceKeysBatch({
    required List<String> hunterIds,
  }) => _apiClientListDirectMessageDeviceKeysBatch(this, hunterIds: hunterIds);

  Future<DmDeviceKey> registerDirectMessageDeviceKey({
    required String deviceId,
    String? deviceLabel,
    required String signingPublicKey,
    required String encryptionPublicKey,
  }) => _apiClientRegisterDirectMessageDeviceKey(
    this,
    deviceId: deviceId,
    deviceLabel: deviceLabel,
    signingPublicKey: signingPublicKey,
    encryptionPublicKey: encryptionPublicKey,
  );

  Future<DmDeviceKey> revokeDirectMessageDeviceKey({
    required String deviceId,
  }) => _apiClientRevokeDirectMessageDeviceKey(this, deviceId: deviceId);

  Future<List<DirectMessage>> getDirectMessageHistory({
    required String counterpartHunterId,
    int limit = 50,
    int? beforeMs,
  }) => _apiClientGetDirectMessageHistory(
    this,
    counterpartHunterId: counterpartHunterId,
    limit: limit,
    beforeMs: beforeMs,
  );

  Future<DirectMessage> persistDirectMessage({
    required String recipientHunterId,
    required String content,
    String? clientMessageId,
    int? sentAtMs,
  }) => _apiClientPersistDirectMessage(
    this,
    recipientHunterId: recipientHunterId,
    content: content,
    clientMessageId: clientMessageId,
    sentAtMs: sentAtMs,
  );

  Future<List<EncryptedDirectMessage>> getEncryptedDirectMessageHistory({
    required String counterpartHunterId,
    int limit = 50,
    int? beforeMs,
  }) => _apiClientGetEncryptedDirectMessageHistory(
    this,
    counterpartHunterId: counterpartHunterId,
    limit: limit,
    beforeMs: beforeMs,
  );

  Future<EncryptedDirectMessage> persistEncryptedDirectMessage({
    required String recipientHunterId,
    required String senderDeviceId,
    required String recipientDeviceId,
    String? clientMessageId,
    String? protocolVersion,
    required String ciphertext,
    required String nonce,
    int? sentAtMs,
  }) => _apiClientPersistEncryptedDirectMessage(
    this,
    recipientHunterId: recipientHunterId,
    senderDeviceId: senderDeviceId,
    recipientDeviceId: recipientDeviceId,
    clientMessageId: clientMessageId,
    protocolVersion: protocolVersion,
    ciphertext: ciphertext,
    nonce: nonce,
    sentAtMs: sentAtMs,
  );

  Future<List<FriendProfile>> listFriends() => _apiClientListFriends(this);

  Future<FriendProfile> addFriend({required String playerId}) =>
      _apiClientAddFriend(this, playerId: playerId);

  Future<FriendRequestInfo> requestFriend({required String playerId}) =>
      _apiClientRequestFriend(this, playerId: playerId);

  Future<List<FriendRequestInfo>> listIncomingFriendRequests() =>
      _apiClientListIncomingFriendRequests(this);

  Future<FriendRequestInfo> respondFriendRequest({
    required String requestId,
    required bool accept,
  }) => _apiClientRespondFriendRequest(
    this,
    requestId: requestId,
    accept: accept,
  );

  Future<GuildInviteInfo> inviteFriendToGuild({required String playerId}) =>
      _apiClientInviteFriendToGuild(this, playerId: playerId);

  Future<List<GuildInviteInfo>> listMyGuildInvites() =>
      _apiClientListMyGuildInvites(this);

  Future<GuildInviteInfo> respondGuildInvite({
    required String inviteId,
    required bool accept,
  }) => _apiClientRespondGuildInvite(this, inviteId: inviteId, accept: accept);

  Future<SocialProfile> getSocialProfile() => _apiClientGetSocialProfile(this);

  Future<SocialProfile> updateSocialProfile({String? motto}) =>
      _apiClientUpdateSocialProfile(this, motto: motto);

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

  String resolveMediaUrl(String contentPath) {
    return Uri.parse(baseUrl).resolve(contentPath).toString();
  }

  Map<String, String> mediaHeaders() {
    final session = authSession;
    final token = session?.accessToken.trim();
    if (token == null || token.isEmpty) {
      return const {'ngrok-skip-browser-warning': 'true'};
    }
    return _bearerHeaders(token);
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
