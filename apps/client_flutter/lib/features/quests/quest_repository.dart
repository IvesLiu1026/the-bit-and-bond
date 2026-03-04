import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import 'models.dart';

class QuestRepository {
  QuestRepository(this._apiClient);

  final ApiClient _apiClient;
  final Uuid _uuid = const Uuid();

  Future<List<QuestTemplate>> fetchTemplates(String guildId) {
    return _apiClient.listQuestTemplates(guildId: guildId, active: true);
  }

  Future<List<QuestInstance>> fetchQuests() {
    return _apiClient.listQuests();
  }

  Future<Submission> submitQuest({
    required String questInstanceId,
    String? note,
  }) {
    return _apiClient.submitQuest(
      questInstanceId: questInstanceId,
      note: note,
      idempotencyKey: _uuid.v4(),
    );
  }

  Future<ReviewSubmissionResult> reviewSubmission({
    required String submissionId,
    required bool approve,
    String? hunterId,
    String? reviewNote,
  }) {
    return _apiClient.reviewSubmission(
      submissionId: submissionId,
      approve: approve,
      hunterId: hunterId,
      reviewNote: reviewNote,
    );
  }

  Future<Progression> fetchProgression({String? hunterId}) {
    return _apiClient.getProgression(hunterId: hunterId);
  }

  Future<List<LedgerEntry>> fetchLedger(String childMemberId) {
    return _apiClient.listLedger(childMemberId: childMemberId, limit: 20);
  }

  Future<List<PendingSubmission>> fetchGuardianPending({int limit = 30}) {
    return _apiClient.listPendingSubmissions(limit: limit);
  }

  Future<List<HunterProfile>> fetchHunters() {
    return _apiClient.listHunters();
  }

  Future<List<HunterProfile>> fetchGuildHunters() {
    return _apiClient.listGuildHunters();
  }

  Future<HunterProfile> createHunter({
    required String name,
    required String avatarType,
    required String pinCode,
  }) {
    return _apiClient.createHunter(
      name: name,
      avatarType: avatarType,
      pinCode: pinCode,
    );
  }

  Future<HunterProfile> resetHunterPin({
    required String hunterId,
    required String pinCode,
  }) {
    return _apiClient.resetHunterPin(hunterId: hunterId, pinCode: pinCode);
  }
}
