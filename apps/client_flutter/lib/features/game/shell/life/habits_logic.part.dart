part of '../../game_shell_page.dart';

List<_HabitChallengeCardData> _habitCardsFromQuests({
  required List<QuestInstance> quests,
  required List<HunterProfile> hunters,
  required bool isMaster,
  required String? activeHunterId,
  required AppStrings strings,
}) {
  final hunterNames = <String, String>{
    for (final hunter in hunters) hunter.id: hunter.name,
  };
  final now = DateTime.now();
  return quests
      .where((quest) => quest.category == QuestCategory.habit)
      .where((quest) {
        if (isMaster) {
          return true;
        }
        return quest.assignedHunterId == null ||
            quest.assignedHunterId == activeHunterId;
      })
      .map((quest) {
        final state = _habitProofStateFor(quest, now);
        final assignedByName = quest.createdByHunterId == null
            ? null
            : hunterNames[quest.createdByHunterId!];
        final rewardParts = <String>[];
        if ((quest.baseXp ?? 0) > 0) {
          rewardParts.add('+${quest.baseXp} XP');
        }
        if ((quest.baseCoins ?? 0) > 0) {
          rewardParts.add('+${quest.baseCoins} Coins');
        }
        final progressDivisor = quest.cadence == HabitCadence.weekly ? 4 : 7;
        final streakProgress = quest.streakCount <= 0
            ? 0
            : quest.streakCount % progressDivisor;
        final progress = ((streakProgress / progressDivisor))
            .clamp(0.12, 1.0)
            .toDouble();
        return _HabitChallengeCardData(
          questId: quest.id,
          title: quest.templateTitle ?? quest.templateId,
          cadence: switch (quest.cadence) {
            HabitCadence.weekly => strings.tr(zh: '每週', en: 'Weekly'),
            HabitCadence.daily => strings.tr(zh: '每日', en: 'Daily'),
            HabitCadence.none => strings.tr(zh: '彈性', en: 'Flexible'),
          },
          streak: quest.streakCount,
          bestStreak: quest.bestStreak,
          completionsCount: quest.completionsCount,
          rewardLabel: rewardParts.isEmpty ? '+0' : rewardParts.join(' / '),
          proofState: state,
          progress: progress,
          proofNote: quest.proofNote,
          reviewNote: quest.lastReviewNote,
          assignedBy: assignedByName,
          proofSubmittedAt: quest.proofSubmittedAt,
          proofMedia: quest.proofMedia,
        );
      })
      .toList(growable: false)
    ..sort((a, b) {
      final rankDiff =
          _habitProofStateSortRank(a.proofState) -
          _habitProofStateSortRank(b.proofState);
      if (rankDiff != 0) {
        return rankDiff;
      }
      final at = a.proofSubmittedAt;
      final bt = b.proofSubmittedAt;
      if (at != null && bt != null) {
        final cmp = bt.compareTo(at);
        if (cmp != 0) {
          return cmp;
        }
      } else if (bt != null) {
        return 1;
      } else if (at != null) {
        return -1;
      }
      return a.title.compareTo(b.title);
    });
}

_HabitProofState _habitProofStateFor(QuestInstance quest, DateTime now) {
  if (quest.status == QuestStatus.submitted) {
    return _HabitProofState.review;
  }
  if (_isHabitCompletedInCurrentCycle(quest, now)) {
    return _HabitProofState.done;
  }
  final lastCompleted = quest.lastCompletedAt;
  if (lastCompleted != null) {
    final normalizedLast = DateTime(
      lastCompleted.year,
      lastCompleted.month,
      lastCompleted.day,
    );
    final anchorNow = _habitCadenceAnchor(quest.cadence, now);
    final anchorLast = _habitCadenceAnchor(quest.cadence, normalizedLast);
    if (anchorLast.isBefore(
      _previousHabitCadenceAnchor(quest.cadence, anchorNow),
    )) {
      return _HabitProofState.missed;
    }
  }
  return _HabitProofState.pending;
}

bool _isHabitCompletedInCurrentCycle(QuestInstance quest, DateTime now) {
  final lastCompleted = quest.lastCompletedAt;
  if (lastCompleted == null) {
    return false;
  }
  final normalizedLast = DateTime(
    lastCompleted.year,
    lastCompleted.month,
    lastCompleted.day,
  );
  return _habitCadenceAnchor(quest.cadence, normalizedLast) ==
      _habitCadenceAnchor(quest.cadence, now);
}

DateTime _habitCadenceAnchor(HabitCadence cadence, DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  if (cadence == HabitCadence.weekly) {
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }
  return normalized;
}

DateTime _previousHabitCadenceAnchor(HabitCadence cadence, DateTime date) {
  return cadence == HabitCadence.weekly
      ? date.subtract(const Duration(days: 7))
      : date.subtract(const Duration(days: 1));
}

List<_HabitProofState> _habitProgressTiles(_HabitChallengeCardData card) {
  final tiles = List<_HabitProofState>.filled(14, _HabitProofState.missed);
  var cursor = 13;
  for (var i = 0; i < card.streak && cursor >= 0; i += 1) {
    tiles[cursor] = _HabitProofState.done;
    cursor -= 1;
  }
  if (cursor >= 0) {
    tiles[cursor] = card.proofState;
  }
  return tiles;
}

int _habitProofStateSortRank(_HabitProofState state) {
  return switch (state) {
    _HabitProofState.review => 0,
    _HabitProofState.pending => 1,
    _HabitProofState.missed => 2,
    _HabitProofState.done => 3,
  };
}
