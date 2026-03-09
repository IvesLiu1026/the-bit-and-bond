part of '../game_shell_page.dart';

enum _HabitProofState { done, review, pending, missed }

class _HabitChallengeCardData {
  const _HabitChallengeCardData({
    required this.questId,
    required this.title,
    required this.cadence,
    required this.streak,
    required this.bestStreak,
    required this.completionsCount,
    required this.rewardLabel,
    required this.proofState,
    required this.progress,
    this.proofNote,
    this.reviewNote,
    this.assignedBy,
    this.proofMedia = const <QuestProofMedia>[],
  });

  final String questId;
  final String title;
  final String cadence;
  final int streak;
  final int bestStreak;
  final int completionsCount;
  final String rewardLabel;
  final _HabitProofState proofState;
  final double progress;
  final String? proofNote;
  final String? reviewNote;
  final String? assignedBy;
  final List<QuestProofMedia> proofMedia;
}

class _HabitsPanel extends StatefulWidget {
  const _HabitsPanel({
    required this.questsState,
    required this.huntersState,
    required this.activeHunterId,
    required this.isMaster,
    required this.apiBaseUrl,
    required this.authToken,
    required this.onCreateHabit,
    required this.onSubmitHabit,
    required this.onReviewHabit,
  });

  final AsyncValue<List<QuestInstance>> questsState;
  final AsyncValue<List<HunterProfile>> huntersState;
  final String? activeHunterId;
  final bool isMaster;
  final String apiBaseUrl;
  final String? authToken;
  final Future<void> Function({
    required String title,
    String? description,
    required int rewardXp,
    required int rewardCoins,
    required QuestStatCategory statCategory,
    QuestCategory category,
    String? assignedHunterId,
    HabitCadence cadence,
  })
  onCreateHabit;
  final Future<void> Function(
    String questId, {
    String? proofNote,
    QuestProofUpload? proofMedia,
  })
  onSubmitHabit;
  final Future<void> Function({required String questId, required bool approve})
  onReviewHabit;

  @override
  State<_HabitsPanel> createState() => _HabitsPanelState();
}

class _HabitsPanelState extends State<_HabitsPanel> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _xpController = TextEditingController(text: '15');
  final TextEditingController _coinsController = TextEditingController(
    text: '5',
  );
  final ImagePicker _imagePicker = ImagePicker();
  HabitCadence _cadence = HabitCadence.daily;
  QuestStatCategory _statCategory = QuestStatCategory.none;
  String? _assignedHunterId;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  Future<void> _createHabit() async {
    if (_submitting) {
      return;
    }
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final rewardXp = int.tryParse(_xpController.text.trim());
    final rewardCoins = int.tryParse(_coinsController.text.trim());

    if (title.isEmpty || rewardXp == null || rewardCoins == null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onCreateHabit(
        title: title,
        description: description.isEmpty ? null : description,
        rewardXp: rewardXp,
        rewardCoins: rewardCoins,
        statCategory: _statCategory,
        category: QuestCategory.habit,
        assignedHunterId: _assignedHunterId,
        cadence: _cadence,
      );
      _titleController.clear();
      _descriptionController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _openProofDialog(_HabitChallengeCardData card) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _HabitProofDialog(
        card: card,
        imagePicker: _imagePicker,
        apiBaseUrl: widget.apiBaseUrl,
        authToken: widget.authToken,
        onSubmitHabit: widget.onSubmitHabit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final hunters = widget.huntersState.maybeWhen(
      data: (value) => value,
      orElse: () => const <HunterProfile>[],
    );
    final cards = widget.questsState.maybeWhen(
      data: (quests) => _habitCardsFromQuests(
        quests: quests,
        hunters: hunters,
        isMaster: widget.isMaster,
        activeHunterId: widget.activeHunterId,
        strings: strings,
      ),
      orElse: () => const <_HabitChallengeCardData>[],
    );
    final completedCount = cards
        .where((card) => card.proofState == _HabitProofState.done)
        .length;
    final reviewCount = cards
        .where((card) => card.proofState == _HabitProofState.review)
        .length;
    final streakPeak = cards.fold<int>(
      0,
      (best, card) => math.max(best, card.bestStreak),
    );
    final pendingReviewCards = cards
        .where((card) => card.proofState == _HabitProofState.review)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.tr(zh: '習慣養成板', en: 'Habit Board'),
          style: const TextStyle(
            color: AppColors.inkBrown,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          strings.tr(
            zh: '把生活任務拉成一條可見進度。朋友或家人指派的挑戰，也會在這裡等你回傳完成證明。',
            en: 'Turn routines into visible progress. Friend and family challenges wait here for proof, review, and streaks.',
          ),
          style: TextStyle(
            color: AppColors.inkBrown.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatGemChip(
              icon: const _PixelLabelGlyph(glyph: 'ACT'),
              label: strings.tr(
                zh: '進行中 ${cards.length} 項',
                en: '${cards.length} Active',
              ),
              color: AppColors.apSapphire,
            ),
            _StatGemChip(
              icon: const _PixelLabelGlyph(glyph: 'OK'),
              label: strings.tr(
                zh: '今日完成 $completedCount 項',
                en: '$completedCount Completed Today',
              ),
              color: AppColors.stampGreen,
            ),
            _StatGemChip(
              icon: const _PixelLabelGlyph(glyph: 'RVW'),
              label: strings.tr(
                zh: '待審核 $reviewCount 項',
                en: '$reviewCount In Review',
              ),
              color: const Color(0xFFB26A00),
            ),
            _StatGemChip(
              icon: const _PixelLabelGlyph(glyph: 'STR'),
              label: strings.tr(
                zh: '最佳連續 $streakPeak 天',
                en: 'Best Streak $streakPeak d',
              ),
              color: const Color(0xFF7C5FB3),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: widget.questsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                strings.tr(
                  zh: '習慣面板讀取失敗：$error',
                  en: 'Habit board failed to load: $error',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.hpRuby,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            data: (_) => ListView(
              children: [
                if (widget.isMaster) ...[
                  _ParchmentSection(
                    title: strings.tr(
                      zh: '建立習慣挑戰',
                      en: 'Create Habit Challenge',
                    ),
                    icon: Icons.post_add,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: strings.tr(zh: '習慣標題', en: 'Title'),
                            filled: true,
                            fillColor: const Color(0xFFE7DDC9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: strings.tr(
                              zh: '說明 / proof 提示',
                              en: 'Prompt / proof note',
                            ),
                            filled: true,
                            fillColor: const Color(0xFFE7DDC9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _xpController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'XP',
                                  filled: true,
                                  fillColor: Color(0xFFE7DDC9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _coinsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Coins',
                                  filled: true,
                                  fillColor: Color(0xFFE7DDC9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SizedBox(
                              width: 180,
                              child: DropdownButtonFormField<HabitCadence>(
                                initialValue: _cadence,
                                decoration: InputDecoration(
                                  labelText: strings.tr(
                                    zh: '頻率',
                                    en: 'Cadence',
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFE7DDC9),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: HabitCadence.daily,
                                    child: Text(
                                      strings.tr(zh: '每日', en: 'Daily'),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: HabitCadence.weekly,
                                    child: Text(
                                      strings.tr(zh: '每週', en: 'Weekly'),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _cadence = value);
                                  }
                                },
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<String?>(
                                initialValue: _assignedHunterId,
                                decoration: InputDecoration(
                                  labelText: strings.tr(
                                    zh: '指派給',
                                    en: 'Assign to',
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFE7DDC9),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      strings.tr(zh: '全家可用', en: 'Shared'),
                                    ),
                                  ),
                                  ...hunters.map(
                                    (hunter) => DropdownMenuItem<String?>(
                                      value: hunter.id,
                                      child: Text(hunter.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _assignedHunterId = value);
                                },
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<QuestStatCategory>(
                                initialValue: _statCategory,
                                decoration: InputDecoration(
                                  labelText: strings.tr(
                                    zh: '成長屬性',
                                    en: 'Growth Stat',
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFE7DDC9),
                                ),
                                items: QuestStatCategory.values
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(_statCategoryLabel(value)),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _statCategory = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        PixelButton(
                          label: _submitting
                              ? strings.tr(zh: '建立中...', en: 'Creating...')
                              : strings.tr(zh: '建立新習慣', en: 'Create Habit'),
                          tone: PixelTone.green,
                          onPressed: _submitting ? null : _createHabit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _ParchmentSection(
                  title: strings.tr(zh: '進行中習慣', en: 'Active Habits'),
                  icon: Icons.auto_awesome,
                  child: cards.isEmpty
                      ? Text(
                          strings.tr(
                            zh: '目前還沒有習慣挑戰。先建立一個 daily/weekly 挑戰，這裡就會開始長出 progress 與 proof 流程。',
                            en: 'No habit challenges yet. Create a daily or weekly challenge and this board will start tracking progress and proof.',
                          ),
                          style: const TextStyle(
                            color: AppColors.inkBrown,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        )
                      : Column(
                          children: cards
                              .map(
                                (card) => _HabitCard(
                                  card: card,
                                  isMaster: widget.isMaster,
                                  apiBaseUrl: widget.apiBaseUrl,
                                  authToken: widget.authToken,
                                  onSubmitProof: () => _openProofDialog(card),
                                  onApprove: () => widget.onReviewHabit(
                                    questId: card.questId,
                                    approve: true,
                                  ),
                                  onReject: () => widget.onReviewHabit(
                                    questId: card.questId,
                                    approve: false,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: 10),
                _ParchmentSection(
                  title: strings.tr(zh: '打卡進度牆', en: 'Progress Wall'),
                  icon: Icons.grid_view_rounded,
                  child: _HabitProgressBoard(
                    focusCard: cards.isEmpty ? null : cards.first,
                  ),
                ),
                const SizedBox(height: 10),
                _ParchmentSection(
                  title: strings.tr(
                    zh: widget.isMaster ? '待審核證明' : '我的證明狀態',
                    en: widget.isMaster ? 'Review Inbox' : 'My Proof Status',
                  ),
                  icon: Icons.mark_email_read_rounded,
                  child: pendingReviewCards.isEmpty
                      ? Text(
                          strings.tr(
                            zh: widget.isMaster
                                ? '目前沒有待審核習慣證明。孩子送出 proof 後，會在這裡等你核准。'
                                : '目前沒有待審核 proof。送審後，這裡會顯示最新狀態。',
                            en: widget.isMaster
                                ? 'No pending habit proof right now. Submitted proof lands here for approval.'
                                : 'No proof is waiting right now. Once you submit, the latest status will show here.',
                          ),
                          style: const TextStyle(
                            color: AppColors.inkBrown,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        )
                      : Column(
                          children: pendingReviewCards
                              .map(
                                (card) => _HabitCard(
                                  card: card,
                                  isMaster: widget.isMaster,
                                  apiBaseUrl: widget.apiBaseUrl,
                                  authToken: widget.authToken,
                                  onSubmitProof: () => _openProofDialog(card),
                                  onApprove: () => widget.onReviewHabit(
                                    questId: card.questId,
                                    approve: true,
                                  ),
                                  onReject: () => widget.onReviewHabit(
                                    questId: card.questId,
                                    approve: false,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
          proofMedia: quest.proofMedia,
        );
      })
      .toList(growable: false)
    ..sort((a, b) => a.title.compareTo(b.title));
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
