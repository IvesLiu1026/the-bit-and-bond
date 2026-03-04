enum QuestStatus { available, submitted, approved, rejected }

enum SubmissionStatus { pending, approved, rejected }

enum QuestCategory { chore, study, exam, habit, unknown }

enum LedgerSourceType { questApproval, manualAdjust, rewardSpend, unknown }

QuestStatus parseQuestStatus(String value) {
  switch (value.toLowerCase()) {
    case 'available':
      return QuestStatus.available;
    case 'pendingreview':
    case 'pending_review':
    case 'submitted':
      return QuestStatus.submitted;
    case 'completed':
    case 'approved':
      return QuestStatus.approved;
    case 'rejected':
      return QuestStatus.rejected;
    default:
      return QuestStatus.available;
  }
}

SubmissionStatus parseSubmissionStatus(String value) {
  switch (value) {
    case 'approved':
      return SubmissionStatus.approved;
    case 'rejected':
      return SubmissionStatus.rejected;
    default:
      return SubmissionStatus.pending;
  }
}

QuestCategory parseQuestCategory(String? value) {
  switch (value) {
    case 'chore':
      return QuestCategory.chore;
    case 'study':
      return QuestCategory.study;
    case 'exam':
      return QuestCategory.exam;
    case 'habit':
      return QuestCategory.habit;
    default:
      return QuestCategory.unknown;
  }
}

LedgerSourceType parseLedgerSource(String value) {
  switch (value) {
    case 'quest_approval':
      return LedgerSourceType.questApproval;
    case 'manual_adjust':
      return LedgerSourceType.manualAdjust;
    case 'reward_spend':
      return LedgerSourceType.rewardSpend;
    default:
      return LedgerSourceType.unknown;
  }
}

class QuestTemplate {
  QuestTemplate({
    required this.id,
    required this.householdId,
    required this.title,
    required this.description,
    required this.category,
    required this.baseXp,
    required this.baseCoins,
    required this.active,
  });

  final String id;
  final String householdId;
  final String title;
  final String? description;
  final QuestCategory category;
  final int baseXp;
  final int baseCoins;
  final bool active;

  factory QuestTemplate.fromJson(Map<String, dynamic> json) {
    return QuestTemplate(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: parseQuestCategory(json['category'] as String?),
      baseXp: json['base_xp'] as int,
      baseCoins: json['base_coins'] as int,
      active: json['active'] as bool,
    );
  }
}

class QuestInstance {
  QuestInstance({
    required this.id,
    required this.templateId,
    required this.templateTitle,
    required this.category,
    required this.baseXp,
    required this.baseCoins,
    required this.status,
    required this.dueAt,
    required this.updatedAt,
  });

  final String id;
  final String templateId;
  final String? templateTitle;
  final QuestCategory category;
  final int? baseXp;
  final int? baseCoins;
  final QuestStatus status;
  final DateTime? dueAt;
  final DateTime updatedAt;

  factory QuestInstance.fromJson(Map<String, dynamic> json) {
    final updatedAtRaw =
        json['updated_at'] ?? json['submitted_at'] ?? json['reviewed_at'];

    return QuestInstance(
      id: json['id'] as String,
      templateId: (json['template_id'] ?? json['id']) as String,
      templateTitle: (json['template_title'] ?? json['title']) as String?,
      category: parseQuestCategory(json['category'] as String?),
      baseXp: (json['base_xp'] ?? json['reward_xp']) as int?,
      baseCoins: (json['base_coins'] ?? json['reward_coins']) as int?,
      status: parseQuestStatus(json['status'] as String),
      dueAt: json['due_at'] != null
          ? DateTime.parse(json['due_at'] as String)
          : null,
      updatedAt: updatedAtRaw == null
          ? DateTime.now()
          : DateTime.parse(updatedAtRaw as String),
    );
  }
}

class Submission {
  Submission({
    required this.id,
    required this.questInstanceId,
    required this.submittedByMemberId,
    required this.status,
    required this.note,
    required this.evidenceUrl,
    required this.submittedAt,
  });

  final String id;
  final String questInstanceId;
  final String submittedByMemberId;
  final SubmissionStatus status;
  final String? note;
  final String? evidenceUrl;
  final DateTime submittedAt;

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['id'] as String,
      questInstanceId: json['quest_instance_id'] as String,
      submittedByMemberId: json['submitted_by_member_id'] as String,
      status: parseSubmissionStatus(json['status'] as String),
      note: json['note'] as String?,
      evidenceUrl: json['evidence_url'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }

  factory Submission.fromQuestResult({
    required QuestInstance quest,
    required String hunterId,
    String? note,
  }) {
    return Submission(
      id: quest.id,
      questInstanceId: quest.id,
      submittedByMemberId: hunterId,
      status: SubmissionStatus.pending,
      note: note,
      evidenceUrl: null,
      submittedAt: DateTime.now(),
    );
  }
}

class ReviewSubmissionResult {
  ReviewSubmissionResult({
    required this.submissionId,
    required this.status,
    required this.questStatus,
    required this.xpDelta,
    required this.coinDelta,
    required this.childLevel,
    required this.childXp,
    required this.childCoins,
  });

  final String submissionId;
  final SubmissionStatus status;
  final QuestStatus questStatus;
  final int xpDelta;
  final int coinDelta;
  final int? childLevel;
  final int? childXp;
  final int? childCoins;

  factory ReviewSubmissionResult.fromJson(Map<String, dynamic> json) {
    return ReviewSubmissionResult(
      submissionId: json['submission_id'] as String,
      status: parseSubmissionStatus(json['status'] as String),
      questStatus: parseQuestStatus(json['quest_status'] as String),
      xpDelta: json['xp_delta'] as int,
      coinDelta: json['coin_delta'] as int,
      childLevel: json['child_level'] as int?,
      childXp: json['child_xp'] as int?,
      childCoins: json['child_coins'] as int?,
    );
  }

  factory ReviewSubmissionResult.fromReviewJson(Map<String, dynamic> json) {
    final questJson = (json['quest'] as Map<String, dynamic>? ?? const {});
    final hunterJson = (json['hunter'] as Map<String, dynamic>? ?? const {});
    final status = parseQuestStatus(
      (questJson['status'] ?? 'available') as String,
    );
    return ReviewSubmissionResult(
      submissionId: (questJson['id'] ?? '') as String,
      status: status == QuestStatus.approved
          ? SubmissionStatus.approved
          : SubmissionStatus.rejected,
      questStatus: status,
      xpDelta: (hunterJson['xp'] as int?) ?? 0,
      coinDelta: (hunterJson['coins'] as int?) ?? 0,
      childLevel: hunterJson['level'] as int?,
      childXp: hunterJson['xp'] as int?,
      childCoins: hunterJson['coins'] as int?,
    );
  }
}

class PendingSubmission {
  PendingSubmission({
    required this.submissionId,
    required this.questInstanceId,
    required this.assigneeMemberId,
    required this.templateTitle,
    required this.note,
    required this.evidenceUrl,
    required this.submittedAt,
  });

  final String submissionId;
  final String questInstanceId;
  final String assigneeMemberId;
  final String? templateTitle;
  final String? note;
  final String? evidenceUrl;
  final DateTime submittedAt;

  factory PendingSubmission.fromJson(Map<String, dynamic> json) {
    final submittedAtRaw = json['submitted_at'] ?? json['updated_at'];
    return PendingSubmission(
      submissionId: (json['submission_id'] ?? json['id']) as String,
      questInstanceId: (json['quest_instance_id'] ?? json['id']) as String,
      assigneeMemberId: (json['assignee_member_id'] ?? '') as String,
      templateTitle: (json['template_title'] ?? json['title']) as String?,
      note: json['note'] as String?,
      evidenceUrl: json['evidence_url'] as String?,
      submittedAt: submittedAtRaw == null
          ? DateTime.now()
          : DateTime.parse(submittedAtRaw as String),
    );
  }
}

class Progression {
  Progression({
    required this.childMemberId,
    required this.level,
    required this.xp,
    required this.coins,
    required this.availableQuests,
    required this.submittedQuests,
  });

  final String childMemberId;
  final int level;
  final int xp;
  final int coins;
  final int availableQuests;
  final int submittedQuests;

  factory Progression.fromJson(Map<String, dynamic> json) {
    return Progression(
      childMemberId: (json['child_member_id'] ?? json['id'] ?? '') as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      coins: json['coins'] as int,
      availableQuests:
          (json['available_quests'] ?? json['available_quests_count'] ?? 0)
              as int,
      submittedQuests:
          (json['submitted_quests'] ?? json['pending_review_count'] ?? 0)
              as int,
    );
  }
}

class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.xpDelta,
    required this.coinDelta,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final LedgerSourceType sourceType;
  final String? sourceId;
  final int xpDelta;
  final int coinDelta;
  final String? note;
  final DateTime createdAt;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'] as String,
      sourceType: parseLedgerSource(json['source_type'] as String),
      sourceId: json['source_id'] as String?,
      xpDelta: json['xp_delta'] as int,
      coinDelta: json['coin_delta'] as int,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class HunterProfile {
  HunterProfile({
    required this.id,
    required this.guildId,
    required this.name,
    required this.avatarType,
    required this.level,
    required this.xp,
    required this.coins,
  });

  final String id;
  final String guildId;
  final String name;
  final String avatarType;
  final int level;
  final int xp;
  final int coins;

  factory HunterProfile.fromJson(Map<String, dynamic> json) {
    return HunterProfile(
      id: json['id'] as String,
      guildId: json['guild_id'] as String,
      name: json['name'] as String,
      avatarType: json['avatar_type'] as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      coins: json['coins'] as int,
    );
  }
}
