part of '../../game_shell_page.dart';

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
    this.proofSubmittedAt,
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
  final DateTime? proofSubmittedAt;
  final List<QuestProofMedia> proofMedia;

  _HabitChallengeCardData copyWith({
    _HabitProofState? proofState,
    String? proofNote,
    DateTime? proofSubmittedAt,
  }) {
    return _HabitChallengeCardData(
      questId: questId,
      title: title,
      cadence: cadence,
      streak: streak,
      bestStreak: bestStreak,
      completionsCount: completionsCount,
      rewardLabel: rewardLabel,
      proofState: proofState ?? this.proofState,
      progress: progress,
      proofNote: proofNote ?? this.proofNote,
      reviewNote: reviewNote,
      assignedBy: assignedBy,
      proofSubmittedAt: proofSubmittedAt ?? this.proofSubmittedAt,
      proofMedia: proofMedia,
    );
  }
}

class _HabitProofOptimisticUpdate {
  const _HabitProofOptimisticUpdate({
    required this.submittedAt,
    this.proofNote,
  });

  final DateTime submittedAt;
  final String? proofNote;
}

class _HabitsPanel extends StatefulWidget {
  const _HabitsPanel({
    super.key,
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
  final Map<String, _HabitProofOptimisticUpdate> _optimisticProofUpdates =
      <String, _HabitProofOptimisticUpdate>{};
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
    final result = await showDialog<_HabitProofOptimisticUpdate>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _HabitProofDialog(
        card: card,
        imagePicker: _imagePicker,
        apiBaseUrl: widget.apiBaseUrl,
        authToken: widget.authToken,
        onSubmitHabit: widget.onSubmitHabit,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _optimisticProofUpdates[card.questId] = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final media = MediaQuery.of(context);
    final compactPanel = media.size.width < 420 || media.size.height < 760;
    final hunters = widget.huntersState.maybeWhen(
      data: (value) => value,
      orElse: () => const <HunterProfile>[],
    );
    final cards = widget.questsState.maybeWhen(
      data: (quests) {
        final nextCards = _habitCardsFromQuests(
          quests: quests,
          hunters: hunters,
          isMaster: widget.isMaster,
          activeHunterId: widget.activeHunterId,
          strings: strings,
        ).map((card) {
          final optimistic = _optimisticProofUpdates[card.questId];
          if (optimistic == null ||
              card.proofState == _HabitProofState.review ||
              card.proofState == _HabitProofState.done) {
            return card;
          }
          return card.copyWith(
            proofState: _HabitProofState.review,
            proofNote: optimistic.proofNote,
            proofSubmittedAt: optimistic.submittedAt,
          );
        }).toList(growable: false);
        return nextCards;
      },
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
    final sectionSpacing = compactPanel ? 8.0 : 10.0;
    final pendingReviewCards =
        cards
            .where((card) => card.proofState == _HabitProofState.review)
            .toList(growable: false)
          ..sort((a, b) {
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
    final activeCards = cards
        .where((card) => card.proofState != _HabitProofState.review)
        .toList(growable: false);

    final children = <Widget>[
      Text(
        strings.tr(zh: '習慣養成板', en: 'Habit Board'),
        style: TextStyle(
          color: AppColors.inkBrown,
          fontSize: compactPanel ? 22 : 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      SizedBox(height: compactPanel ? 4 : 6),
      Text(
        strings.tr(
          zh: '把生活任務拉成一條可見進度。朋友或家人指派的挑戰，也會在這裡等你回傳完成證明。',
          en: 'Turn routines into visible progress. Friend and family challenges wait here for proof, review, and streaks.',
        ),
        style: TextStyle(
          color: AppColors.inkBrown.withValues(alpha: 0.78),
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
      SizedBox(height: sectionSpacing),
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
      SizedBox(height: sectionSpacing),
    ];

    widget.questsState.when(
      loading: () {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      },
      error: (error, _) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
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
        );
      },
      data: (_) {
        if (widget.isMaster) {
          children.addAll([
            _HabitCreationSection(
              titleController: _titleController,
              descriptionController: _descriptionController,
              xpController: _xpController,
              coinsController: _coinsController,
              cadence: _cadence,
              onCadenceChanged: (value) => setState(() => _cadence = value),
              assignedHunterId: _assignedHunterId,
              onAssignedHunterChanged: (value) =>
                  setState(() => _assignedHunterId = value),
              statCategory: _statCategory,
              onStatCategoryChanged: (value) =>
                  setState(() => _statCategory = value),
              hunters: hunters,
              submitting: _submitting,
              onCreateHabit: _createHabit,
            ),
            SizedBox(height: sectionSpacing),
          ]);
        }

        children.addAll([
          _ParchmentSection(
            title: strings.tr(zh: '進行中習慣', en: 'Active Habits'),
            icon: Icons.auto_awesome,
            child: activeCards.isEmpty
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
                    children: activeCards
                        .map(
                          (card) => _HabitCard(
                            cardKey: AppTestIds.habitActiveCard(card.questId),
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
          SizedBox(height: sectionSpacing),
          _ParchmentSection(
            title: strings.tr(zh: '打卡進度牆', en: 'Progress Wall'),
            icon: Icons.grid_view_rounded,
            child: _HabitProgressBoard(
              focusCard: activeCards.isNotEmpty
                  ? activeCards.first
                  : (cards.isEmpty ? null : cards.first),
            ),
          ),
          SizedBox(height: sectionSpacing),
          KeyedSubtree(
            key: AppTestIds.habitsReviewSectionKey,
            child: _ParchmentSection(
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
                              cardKey: AppTestIds.habitReviewCard(card.questId),
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
          ),
        ]);
      },
    );

    return ListView(
      cacheExtent: 2048,
      padding: EdgeInsets.only(bottom: compactPanel ? 12 : 16),
      children: children,
    );
  }
}
