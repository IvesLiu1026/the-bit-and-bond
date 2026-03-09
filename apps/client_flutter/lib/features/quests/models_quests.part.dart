part of 'models.dart';

class QuestProofMedia {
  QuestProofMedia({
    required this.id,
    required this.questId,
    this.originalFilename,
    required this.mimeType,
    required this.byteSize,
    required this.contentPath,
    required this.createdAt,
  });

  final String id;
  final String questId;
  final String? originalFilename;
  final String mimeType;
  final int byteSize;
  final String contentPath;
  final DateTime createdAt;

  factory QuestProofMedia.fromJson(Map<String, dynamic> json) {
    return QuestProofMedia(
      id: json['id'] as String,
      questId: json['quest_id'] as String,
      originalFilename: json['original_filename'] as String?,
      mimeType: (json['mime_type'] ?? 'application/octet-stream') as String,
      byteSize: (json['byte_size'] ?? 0) as int,
      contentPath: (json['content_path'] ?? '') as String,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
    );
  }
}

class QuestProofUpload {
  QuestProofUpload({
    required this.filename,
    required this.bytes,
    this.mimeType,
  });

  final String filename;
  final List<int> bytes;
  final String? mimeType;
}

class QuestInstance {
  QuestInstance({
    required this.id,
    required this.templateId,
    required this.templateTitle,
    required this.category,
    required this.statCategory,
    required this.baseXp,
    required this.baseCoins,
    required this.status,
    this.assignedHunterId,
    this.createdByHunterId,
    this.cadence = HabitCadence.none,
    this.streakCount = 0,
    this.bestStreak = 0,
    this.completionsCount = 0,
    this.proofNote,
    this.proofSubmittedAt,
    this.lastCompletedAt,
    this.lastReviewNote,
    this.proofMedia = const <QuestProofMedia>[],
    required this.dueAt,
    required this.updatedAt,
  });

  final String id;
  final String templateId;
  final String? templateTitle;
  final QuestCategory category;
  final QuestStatCategory statCategory;
  final int? baseXp;
  final int? baseCoins;
  final QuestStatus status;
  final String? assignedHunterId;
  final String? createdByHunterId;
  final HabitCadence cadence;
  final int streakCount;
  final int bestStreak;
  final int completionsCount;
  final String? proofNote;
  final DateTime? proofSubmittedAt;
  final DateTime? lastCompletedAt;
  final String? lastReviewNote;
  final List<QuestProofMedia> proofMedia;
  final DateTime? dueAt;
  final DateTime updatedAt;

  bool get isHabit => category == QuestCategory.habit;

  factory QuestInstance.fromJson(Map<String, dynamic> json) {
    final updatedAtRaw =
        json['updated_at'] ?? json['submitted_at'] ?? json['reviewed_at'];

    return QuestInstance(
      id: json['id'] as String,
      templateId: (json['template_id'] ?? json['id']) as String,
      templateTitle: (json['template_title'] ?? json['title']) as String?,
      category: parseQuestCategory(json['category'] as String?),
      statCategory: parseQuestStatCategory(
        (json['stat_category'] ?? json['category']) as String?,
      ),
      baseXp: (json['base_xp'] ?? json['reward_xp']) as int?,
      baseCoins: (json['base_coins'] ?? json['reward_coins']) as int?,
      status: parseQuestStatus(json['status'] as String),
      assignedHunterId: json['assigned_hunter_id'] as String?,
      createdByHunterId: json['created_by_hunter_id'] as String?,
      cadence: parseHabitCadence(json['cadence'] as String?),
      streakCount: (json['streak_count'] ?? 0) as int,
      bestStreak: (json['best_streak'] ?? 0) as int,
      completionsCount: (json['completions_count'] ?? 0) as int,
      proofNote: json['proof_note'] as String?,
      proofSubmittedAt: json['proof_submitted_at'] != null
          ? DateTime.parse(json['proof_submitted_at'] as String)
          : null,
      lastCompletedAt: json['last_completed_at'] != null
          ? DateTime.parse(json['last_completed_at'] as String)
          : null,
      lastReviewNote: json['last_review_note'] as String?,
      proofMedia: (json['proof_media'] as List<dynamic>? ?? const [])
          .map((item) => QuestProofMedia.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      dueAt: json['due_at'] != null
          ? DateTime.parse(json['due_at'] as String)
          : null,
      updatedAt: updatedAtRaw == null
          ? DateTime.now()
          : DateTime.parse(updatedAtRaw as String),
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

class HunterProfile {
  HunterProfile({
    required this.id,
    required this.guildId,
    this.playerId,
    required this.name,
    required this.avatarType,
    required this.level,
    required this.xp,
    required this.coins,
  });

  final String id;
  final String guildId;
  final String? playerId;
  final String name;
  final String avatarType;
  final int level;
  final int xp;
  final int coins;

  factory HunterProfile.fromJson(Map<String, dynamic> json) {
    return HunterProfile(
      id: json['id'] as String,
      guildId: json['guild_id'] as String,
      playerId: json['player_id'] as String?,
      name: json['name'] as String,
      avatarType: json['avatar_type'] as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      coins: json['coins'] as int,
    );
  }
}

class HunterRewardSnapshot {
  HunterRewardSnapshot({
    required this.id,
    required this.guildId,
    required this.level,
    required this.xp,
    required this.coins,
  });

  final String id;
  final String guildId;
  final int level;
  final int xp;
  final int coins;

  factory HunterRewardSnapshot.fromJson(Map<String, dynamic> json) {
    return HunterRewardSnapshot(
      id: json['id'] as String,
      guildId: json['guild_id'] as String,
      level: json['level'] as int,
      xp: json['xp'] as int,
      coins: json['coins'] as int,
    );
  }
}

class QuestReviewReward {
  QuestReviewReward({
    required this.rewardEventId,
    required this.hunterId,
    required this.gainedXp,
    required this.gainedCoins,
    required this.leveledUp,
    required this.newLevel,
  });

  final String rewardEventId;
  final String hunterId;
  final int gainedXp;
  final int gainedCoins;
  final bool leveledUp;
  final int newLevel;

  factory QuestReviewReward.fromJson(Map<String, dynamic> json) {
    return QuestReviewReward(
      rewardEventId: json['reward_event_id'] as String,
      hunterId: json['hunter_id'] as String,
      gainedXp: json['gained_xp'] as int,
      gainedCoins: json['gained_coins'] as int,
      leveledUp: json['leveled_up'] as bool? ?? false,
      newLevel: json['new_level'] as int? ?? 1,
    );
  }
}

class QuestReviewResult {
  QuestReviewResult({
    required this.quest,
    required this.hunter,
    required this.reward,
  });

  final QuestInstance quest;
  final HunterRewardSnapshot? hunter;
  final QuestReviewReward? reward;

  factory QuestReviewResult.fromJson(Map<String, dynamic> json) {
    return QuestReviewResult(
      quest: QuestInstance.fromJson((json['quest'] as Map<String, dynamic>)),
      hunter: json['hunter'] is Map<String, dynamic>
          ? HunterRewardSnapshot.fromJson(
              json['hunter'] as Map<String, dynamic>,
            )
          : null,
      reward: json['reward'] is Map<String, dynamic>
          ? QuestReviewReward.fromJson(json['reward'] as Map<String, dynamic>)
          : null,
    );
  }
}
