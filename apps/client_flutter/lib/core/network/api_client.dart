import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../features/quests/models.dart';
import '../auth/auth_session.dart';

part 'api_client_direct_messages.part.dart';
part 'api_client_hunters.part.dart';
part 'api_client_media.part.dart';
part 'api_client_quests.part.dart';
part 'api_client_shop_inventory.part.dart';
part 'api_client_social.part.dart';
part 'api_client_telemetry.part.dart';
part 'api_client_transport.part.dart';
part 'api_client_voice.part.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.authSession,
    this.authSessionResolver,
    this.onUnauthorizedRecover,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final AuthSession? authSession;
  final AuthSession? Function()? authSessionResolver;
  final Future<AuthSession?> Function()? onUnauthorizedRecover;
  final http.Client _httpClient;
  static const int _maxErrorSnippetLength = 180;
  Completer<AuthSession?>? _unauthorizedRecoveryCompleter;

  Future<List<QuestInstance>> listQuests() => _apiClientListQuests(this);

  Future<void> ensureAuthorizedSession() async {
    await _authedGet('/api/v1/auth/me', const {}, role: _AuthRole.any);
  }

  Future<void> sendTelemetryEvents({
    required List<TelemetryEventPayload> events,
    bool allowPublic = false,
  }) => _apiClientSendTelemetryEvents(
    this,
    events: events,
    allowPublic: allowPublic,
  );

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

  Future<List<MediaAssetItem>> listVaultMedia({int limit = 60}) =>
      _apiClientListVaultMedia(this, limit: limit);

  Future<MediaAssetItem> uploadVaultMedia({
    required MediaUpload upload,
    String? caption,
    bool includeInDump = false,
  }) => _apiClientUploadVaultMedia(
    this,
    upload: upload,
    caption: caption,
    includeInDump: includeInDump,
  );

  Future<MediaOnceDelivery> sendOnceMedia({
    required String recipientPlayerId,
    required MediaUpload upload,
    String? caption,
    int? ttlSeconds,
    MediaEncryptionMeta? encryption,
  }) => _apiClientSendOnceMedia(
    this,
    recipientPlayerId: recipientPlayerId,
    upload: upload,
    caption: caption,
    ttlSeconds: ttlSeconds,
    encryption: encryption,
  );

  Future<List<MediaOnceDelivery>> listOnceInbox({int limit = 60}) =>
      _apiClientListOnceInbox(this, limit: limit);

  Future<MediaOnceOpenResult> openOnceMedia({required String deliveryId}) =>
      _apiClientOpenOnceMedia(this, deliveryId: deliveryId);

  Future<List<int>> fetchMediaBytes({required String contentPath}) =>
      _apiClientFetchMediaBytes(this, contentPath: contentPath);

  Future<PhotoDumpExportItem> createPhotoDumpExport({
    required List<String> assetIds,
    String? title,
    String? style,
  }) => _apiClientCreatePhotoDumpExport(
    this,
    assetIds: assetIds,
    title: title,
    style: style,
  );

  Future<List<PhotoDumpExportItem>> listPhotoDumpExports({int limit = 20}) =>
      _apiClientListPhotoDumpExports(this, limit: limit);

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

  Future<List<HunterProfile>> listHunters() => _apiClientListHunters(this);

  Future<List<HunterProfile>> listGuildHunters() =>
      _apiClientListGuildHunters(this);

  Future<HunterProfile> createHunter({
    required String name,
    required String avatarType,
    required String pinCode,
  }) => _apiClientCreateHunter(
    this,
    name: name,
    avatarType: avatarType,
    pinCode: pinCode,
  );

  Future<HunterProfile> resetHunterPin({
    required String hunterId,
    required String pinCode,
  }) => _apiClientResetHunterPin(this, hunterId: hunterId, pinCode: pinCode);

  Future<HunterProfile> getHunterMe() => _apiClientGetHunterMe(this);

  Future<HunterStatsSummary> getHunterStats({required String hunterId}) =>
      _apiClientGetHunterStats(this, hunterId: hunterId);

  Future<List<GuildShopItem>> listShopItems({bool includeInactive = false}) =>
      _apiClientListShopItems(this, includeInactive: includeInactive);

  Future<ShopPurchaseResult> buyShopItem({
    required String itemId,
    required String idempotencyKey,
  }) => _apiClientBuyShopItem(
    this,
    itemId: itemId,
    idempotencyKey: idempotencyKey,
  );

  Future<GuildShopItem> createShopItem({
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  }) => _apiClientCreateShopItem(
    this,
    name: name,
    description: description,
    costCoins: costCoins,
    iconTag: iconTag,
  );

  Future<GuildShopItem> updateShopItem({
    required String itemId,
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  }) => _apiClientUpdateShopItem(
    this,
    itemId: itemId,
    name: name,
    description: description,
    costCoins: costCoins,
    iconTag: iconTag,
  );

  Future<GuildShopItem> deactivateShopItem({required String itemId}) =>
      _apiClientDeactivateShopItem(this, itemId: itemId);

  Future<List<InventoryItem>> listInventory() => _apiClientListInventory(this);

  Future<InventoryUseResult> useInventoryItem({required String itemId}) =>
      _apiClientUseInventoryItem(this, itemId: itemId);

  Future<RealtimeWsTicket> issueRealtimeTicket() =>
      _apiClientIssueRealtimeTicket(this);

  HunterProfile _resolveHunterSelection(
    List<HunterProfile> hunters,
    String? hunterId,
  ) => _apiClientResolveHunterSelection(hunters, hunterId);

  Future<dynamic> _authedGet(
    String path,
    Map<String, String> query, {
    required _AuthRole role,
  }) => _apiClientAuthedGet(this, path, query, role: role);

  Future<dynamic> _authedPost(
    String path,
    Map<String, dynamic> payload, {
    required _AuthRole role,
  }) => _apiClientAuthedPost(this, path, payload, role: role);

  Future<dynamic> _authedPatch(
    String path,
    Map<String, dynamic> payload, {
    required _AuthRole role,
  }) => _apiClientAuthedPatch(this, path, payload, role: role);

  Future<dynamic> _authedPut(
    String path,
    Map<String, dynamic> payload, {
    required _AuthRole role,
  }) => _apiClientAuthedPut(this, path, payload, role: role);

  Future<dynamic> _authedDelete(String path, {required _AuthRole role}) =>
      _apiClientAuthedDelete(this, path, role: role);

  Future<http.Response> _authedRequestResponse(
    _AuthRole role,
    Future<http.Response> Function(String token) send, {
    Duration timeout = const Duration(seconds: 10),
    bool retryTransportErrors = false,
  }) => _apiClientAuthedRequestResponse(
    this,
    role,
    send,
    timeout: timeout,
    retryTransportErrors: retryTransportErrors,
  );

  AuthSession _requireSession() => _apiClientRequireSession(this);

  String resolveMediaUrl(String contentPath) {
    return Uri.parse(baseUrl).resolve(contentPath).toString();
  }

  Map<String, String> mediaHeaders() {
    final session = authSessionResolver?.call() ?? authSession;
    final token = session?.accessToken.trim();
    if (token == null || token.isEmpty) {
      return const {'ngrok-skip-browser-warning': 'true'};
    }
    return _bearerHeaders(token);
  }

  Map<String, String> _bearerHeaders(String token) =>
      _apiClientBearerHeaders(token);

  dynamic _parseResponse(http.Response response) =>
      _apiClientParseResponse(this, response);
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

class TelemetryEventPayload {
  const TelemetryEventPayload({
    required this.eventName,
    this.status,
    this.source,
    this.platform,
    this.locale,
    this.appVersion,
    this.sessionId,
    this.occurredAtMs,
    this.properties = const <String, dynamic>{},
  });

  final String eventName;
  final String? status;
  final String? source;
  final String? platform;
  final String? locale;
  final String? appVersion;
  final String? sessionId;
  final int? occurredAtMs;
  final Map<String, dynamic> properties;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'event_name': eventName,
      if (status != null && status!.trim().isNotEmpty) 'status': status,
      if (source != null && source!.trim().isNotEmpty) 'source': source,
      if (platform != null && platform!.trim().isNotEmpty) 'platform': platform,
      if (locale != null && locale!.trim().isNotEmpty) 'locale': locale,
      if (appVersion != null && appVersion!.trim().isNotEmpty)
        'app_version': appVersion,
      if (sessionId != null && sessionId!.trim().isNotEmpty)
        'session_id': sessionId,
      if (occurredAtMs != null) 'occurred_at_ms': occurredAtMs,
      'properties': properties,
    };
  }
}
