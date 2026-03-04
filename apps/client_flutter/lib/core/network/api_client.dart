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

  Future<List<QuestTemplate>> listQuestTemplates({
    required String guildId,
    bool? active,
  }) async {
    return const [];
  }

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

  Future<Submission> submitQuest({
    required String questInstanceId,
    String? note,
    String? evidenceUrl,
    String? idempotencyKey,
  }) async {
    final session = _requireSession();
    final data = await _authedPost(
      '/api/v1/quests/$questInstanceId/submit',
      const {},
      role: _AuthRole.hunter,
    );
    final quest = QuestInstance.fromJson(data as Map<String, dynamic>);
    return Submission.fromQuestResult(
      quest: quest,
      hunterId: session.hunterId ?? '',
      note: note,
    );
  }

  Future<ReviewSubmissionResult> reviewSubmission({
    required String submissionId,
    required bool approve,
    String? hunterId,
    String? reviewNote,
  }) async {
    final payload = <String, dynamic>{'approved': approve};
    if (approve) {
      final normalizedHunterId = hunterId?.trim();
      if (normalizedHunterId == null || normalizedHunterId.isEmpty) {
        throw ApiException('hunter_id is required when approving a quest', 400);
      }
      payload['hunter_id'] = normalizedHunterId;
    }

    final data = await _authedPost(
      '/api/v1/quests/$submissionId/review',
      payload,
      role: _AuthRole.master,
    );
    return ReviewSubmissionResult.fromReviewJson(data as Map<String, dynamic>);
  }

  Future<List<PendingSubmission>> listPendingSubmissions({
    int limit = 30,
  }) async {
    final data = await _authedGet(
      '/api/v1/quests',
      const {},
      role: _AuthRole.master,
    );
    final quests = (data as List)
        .map((item) => QuestInstance.fromJson(item as Map<String, dynamic>))
        .where((quest) => quest.status == QuestStatus.submitted)
        .take(limit)
        .toList();

    return quests
        .map(
          (quest) => PendingSubmission(
            submissionId: quest.id,
            questInstanceId: quest.id,
            assigneeMemberId: '',
            templateTitle: quest.templateTitle,
            note: null,
            evidenceUrl: null,
            submittedAt: quest.updatedAt,
          ),
        )
        .toList();
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

    if (session.role == AuthUserRole.guildMaster) {
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

  Future<List<LedgerEntry>> listLedger({
    required String childMemberId,
    int limit = 20,
  }) async {
    return const [];
  }

  Future<List<HunterProfile>> listHunters() async {
    final data = await _authedGet(
      '/api/v1/hunters',
      const {},
      role: _AuthRole.master,
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
    }, role: _AuthRole.master);
    return HunterProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<HunterProfile> resetHunterPin({
    required String hunterId,
    required String pinCode,
  }) async {
    final data = await _authedPatch('/api/v1/hunters/$hunterId/pin', {
      'pin_code': pinCode.trim(),
    }, role: _AuthRole.master);
    return HunterProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<HunterProfile> getHunterMe() async {
    final data = await _authedGet(
      '/api/v1/hunters/me',
      const {},
      role: _AuthRole.hunter,
    );
    return HunterProfile.fromJson(data as Map<String, dynamic>);
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

  String _resolveTokenForRole(_AuthRole role) {
    final session = _requireSession();
    switch (role) {
      case _AuthRole.any:
        return session.accessToken;
      case _AuthRole.master:
        if (session.role != AuthUserRole.guildMaster) {
          throw ApiException('guild master role required', 403);
        }
        return session.accessToken;
      case _AuthRole.hunter:
        if (session.role != AuthUserRole.hunter) {
          throw ApiException('hunter role required', 403);
        }
        return session.accessToken;
    }
  }

  AuthSession _requireSession() {
    final session = authSession;
    if (session == null || session.accessToken.isEmpty) {
      throw ApiException('authentication required', 401);
    }
    return session;
  }

  Map<String, String> _bearerHeaders(String token) => {
    'Authorization': 'Bearer $token',
  };

  Map<String, String> _jsonBearerHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  dynamic _parseResponse(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as dynamic;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (body is Map<String, dynamic> && body['error'] is String) {
      throw ApiException(body['error'] as String, response.statusCode);
    }

    throw ApiException(
      'API request failed with status ${response.statusCode}',
      response.statusCode,
    );
  }
}

enum _AuthRole { any, master, hunter }

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException(status: $statusCode, message: $message)';
}
