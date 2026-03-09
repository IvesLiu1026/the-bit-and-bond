part of 'api_client.dart';

Future<List<QuestInstance>> _apiClientListQuests(ApiClient api) async {
  final data = await api._authedGet(
    '/api/v1/quests',
    const {},
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => QuestInstance.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<void> _apiClientSubmitQuest(
  ApiClient api, {
  required String questInstanceId,
}) {
  return api._authedPost(
    '/api/v1/quests/$questInstanceId/submit',
    const {},
    role: _AuthRole.any,
  );
}

Future<void> _apiClientSubmitQuestProof(
  ApiClient api, {
  required String questInstanceId,
  String? proofNote,
  QuestProofUpload? proofMedia,
}) async {
  if (proofMedia != null) {
    await _apiClientUploadQuestProofMedia(
      api,
      questInstanceId: questInstanceId,
      upload: proofMedia,
    );
  }
  final payload = <String, dynamic>{};
  final normalizedProof = proofNote?.trim();
  if (normalizedProof != null && normalizedProof.isNotEmpty) {
    payload['proof_note'] = normalizedProof;
  }
  await api._authedPost(
    '/api/v1/quests/$questInstanceId/submit',
    payload,
    role: _AuthRole.any,
  );
}

Future<QuestProofMedia> _apiClientUploadQuestProofMedia(
  ApiClient api, {
  required String questInstanceId,
  required QuestProofUpload upload,
}) async {
  final token = api._resolveTokenForRole(_AuthRole.any);
  final uri = Uri.parse(
    '${api.baseUrl}/api/v1/quests/$questInstanceId/proof-media',
  );
  final request = http.MultipartRequest('POST', uri)
    ..headers.addAll(api._bearerHeaders(token))
    ..files.add(
      http.MultipartFile.fromBytes(
        'file',
        upload.bytes,
        filename: upload.filename,
      ),
    );

  final streamed = await api._httpClient
      .send(request)
      .timeout(const Duration(seconds: 20));
  final response = await http.Response.fromStream(streamed);
  final data = api._parseResponse(response);
  return QuestProofMedia.fromJson(data as Map<String, dynamic>);
}

Future<QuestReviewResult> _apiClientReviewSubmission(
  ApiClient api, {
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

  final data = await api._authedPost(
    '/api/v1/quests/$submissionId/review',
    payload,
    role: _AuthRole.owner,
  );
  return QuestReviewResult.fromJson(data as Map<String, dynamic>);
}

Future<Progression> _apiClientGetProgression(
  ApiClient api, {
  String? hunterId,
}) async {
  final session = api._requireSession();
  final quests = await _apiClientListQuests(api);
  final availableQuests = quests
      .where(
        (q) =>
            q.category != QuestCategory.habit &&
            q.status == QuestStatus.available,
      )
      .length;
  final submittedQuests = quests
      .where(
        (q) =>
            q.category != QuestCategory.habit &&
            q.status == QuestStatus.submitted,
      )
      .length;

  if (session.isGuildMaster) {
    final hunters = await api.listHunters();
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

    final selected = api._resolveHunterSelection(hunters, hunterId);
    return Progression(
      childMemberId: selected.id,
      level: selected.level,
      xp: selected.xp,
      coins: selected.coins,
      availableQuests: availableQuests,
      submittedQuests: submittedQuests,
    );
  }

  final me = await api.getHunterMe();
  return Progression(
    childMemberId: me.id,
    level: me.level,
    xp: me.xp,
    coins: me.coins,
    availableQuests: availableQuests,
    submittedQuests: submittedQuests,
  );
}

Future<QuestInstance> _apiClientCreateQuest(
  ApiClient api, {
  required String title,
  String? description,
  required int rewardXp,
  required int rewardCoins,
  required QuestStatCategory statCategory,
  QuestCategory category = QuestCategory.chore,
  String? assignedHunterId,
  HabitCadence cadence = HabitCadence.none,
}) async {
  final payload = <String, dynamic>{
    'title': title.trim(),
    'reward_xp': rewardXp,
    'reward_coins': rewardCoins,
    'stat_category': questStatCategoryToApiValue(statCategory),
    'category': questCategoryToApiValue(category),
  };
  final normalizedDescription = description?.trim();
  if (normalizedDescription != null && normalizedDescription.isNotEmpty) {
    payload['description'] = normalizedDescription;
  }
  final normalizedAssignedHunterId = assignedHunterId?.trim();
  if (normalizedAssignedHunterId != null &&
      normalizedAssignedHunterId.isNotEmpty) {
    payload['assigned_hunter_id'] = normalizedAssignedHunterId;
  }
  final cadenceValue = habitCadenceToApiValue(cadence);
  if (cadenceValue != null) {
    payload['cadence'] = cadenceValue;
  }
  final data = await api._authedPost(
    '/api/v1/quests',
    payload,
    role: _AuthRole.owner,
  );
  return QuestInstance.fromJson(data as Map<String, dynamic>);
}
