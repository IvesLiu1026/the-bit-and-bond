part 'models_dm.part.dart';
part 'models_media.part.dart';
part 'models_quests.part.dart';
part 'models_shop_voice.part.dart';
part 'models_social.part.dart';

enum QuestStatus { available, submitted, approved, rejected }

enum QuestCategory { chore, study, exam, habit, unknown }

enum HabitCadence { daily, weekly, none }

enum QuestStatCategory {
  strength,
  intelligence,
  agility,
  vitality,
  charisma,
  none,
}

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

HabitCadence parseHabitCadence(String? value) {
  switch (value) {
    case 'daily':
      return HabitCadence.daily;
    case 'weekly':
      return HabitCadence.weekly;
    default:
      return HabitCadence.none;
  }
}

String? habitCadenceToApiValue(HabitCadence value) {
  return switch (value) {
    HabitCadence.daily => 'daily',
    HabitCadence.weekly => 'weekly',
    HabitCadence.none => null,
  };
}

String questCategoryToApiValue(QuestCategory value) {
  return switch (value) {
    QuestCategory.chore => 'chore',
    QuestCategory.study => 'study',
    QuestCategory.exam => 'exam',
    QuestCategory.habit => 'habit',
    QuestCategory.unknown => 'unknown',
  };
}

QuestStatCategory parseQuestStatCategory(String? value) {
  switch (value?.toLowerCase()) {
    case 'str':
    case 'strength':
      return QuestStatCategory.strength;
    case 'int':
    case 'intelligence':
      return QuestStatCategory.intelligence;
    case 'agi':
    case 'agility':
      return QuestStatCategory.agility;
    case 'vit':
    case 'vitality':
      return QuestStatCategory.vitality;
    case 'cha':
    case 'charisma':
      return QuestStatCategory.charisma;
    case 'none':
      return QuestStatCategory.none;
    default:
      return QuestStatCategory.none;
  }
}

String questStatCategoryToApiValue(QuestStatCategory value) {
  return switch (value) {
    QuestStatCategory.strength => 'STR',
    QuestStatCategory.intelligence => 'INT',
    QuestStatCategory.agility => 'AGI',
    QuestStatCategory.vitality => 'VIT',
    QuestStatCategory.charisma => 'CHA',
    QuestStatCategory.none => 'NONE',
  };
}
