part of '../game_shell_page.dart';

class _GuildToolsPanel extends StatefulWidget {
  const _GuildToolsPanel({
    required this.questsState,
    required this.onCreateQuest,
    required this.onReviewQuest,
  });

  final AsyncValue<List<QuestInstance>> questsState;
  final Future<void> Function({
    required String title,
    String? description,
    required int rewardXp,
    required int rewardCoins,
    required QuestStatCategory statCategory,
  })
  onCreateQuest;
  final Future<void> Function({required String questId, required bool approve})
  onReviewQuest;

  @override
  State<_GuildToolsPanel> createState() => _GuildToolsPanelState();
}

class _GuildToolsPanelState extends State<_GuildToolsPanel> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _xpController = TextEditingController(text: '20');
  final TextEditingController _coinsController = TextEditingController(
    text: '10',
  );
  QuestStatCategory _selectedStatCategory = QuestStatCategory.none;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_submitting) {
      return;
    }
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final rewardXp = int.tryParse(_xpController.text.trim());
    final rewardCoins = int.tryParse(_coinsController.text.trim());

    final strings = AppStrings.of(context);
    if (title.isEmpty) {
      _showError(strings.tr(zh: '請輸入任務標題', en: 'Please enter a quest title'));
      return;
    }
    if (rewardXp == null || rewardXp < 0) {
      _showError(
        strings.tr(
          zh: '獎勵 XP 必須是 0 以上整數',
          en: 'Reward XP must be an integer >= 0',
        ),
      );
      return;
    }
    if (rewardCoins == null || rewardCoins < 0) {
      _showError(
        strings.tr(
          zh: '獎勵金幣必須是 0 以上整數',
          en: 'Reward coins must be an integer >= 0',
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onCreateQuest(
        title: title,
        description: description.isEmpty ? null : description,
        rewardXp: rewardXp,
        rewardCoins: rewardCoins,
        statCategory: _selectedStatCategory,
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

  Future<void> _review(String questId, bool approve) async {
    if (_submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onReviewQuest(questId: questId, approve: approve);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.hpRuby),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final pending = widget.questsState.maybeWhen(
      data: (items) => items
          .where(
            (q) =>
                q.category != QuestCategory.habit &&
                q.status == QuestStatus.submitted,
          )
          .toList(),
      orElse: () => const <QuestInstance>[],
    );
    return _ParchmentSection(
      title: strings.tr(zh: '公會工具', en: 'Family Tools'),
      icon: Icons.construction_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PixelTextInput(
            controller: _titleController,
            enabled: !_submitting,
            label: strings.tr(zh: '任務標題', en: 'Quest Title'),
          ),
          const SizedBox(height: 6),
          _PixelTextInput(
            controller: _descriptionController,
            enabled: !_submitting,
            label: strings.tr(zh: '任務描述（可選）', en: 'Description (Optional)'),
          ),
          const SizedBox(height: 6),
          _PixelDropdownField<QuestStatCategory>(
            label: strings.tr(zh: '能力標籤', en: 'Stat Tag'),
            initialValue: _selectedStatCategory,
            items: QuestStatCategory.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Row(
                      children: [
                        _PixelStatIcon(
                          category: value,
                          size: 18,
                          withFrame: true,
                        ),
                        const SizedBox(width: 6),
                        Text(_statCategoryLabel(value, strings: strings)),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _submitting
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedStatCategory = value;
                    });
                  },
            enabled: !_submitting,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _PixelTextInput(
                  controller: _xpController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  label: 'XP',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PixelTextInput(
                  controller: _coinsController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  label: strings.tr(zh: '金幣', en: 'Coins'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StampButton(
            label: _submitting
                ? strings.tr(zh: '處理中...', en: 'Working...')
                : strings.tr(zh: '建立任務', en: 'Create Quest'),
            icon: Icons.post_add,
            tone: _StampTone.green,
            onPressed: _submitting ? null : _create,
          ),
          const SizedBox(height: 8),
          Text(
            strings.tr(
              zh: '待審任務 ${pending.length} 筆',
              en: '${pending.length} pending reviews',
            ),
            style: const TextStyle(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.questsState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: _PixelLoadingBar()),
            )
          else if (pending.isEmpty)
            Text(
              strings.tr(zh: '目前沒有待審任務', en: 'No pending reviews right now'),
              style: const TextStyle(color: AppColors.navyBlue),
            )
          else
            Column(
              children: pending
                  .map(
                    (quest) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8EED7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF7B5A3C),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quest.templateTitle ?? quest.templateId,
                            style: const TextStyle(
                              color: AppColors.inkBrown,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _StatGemChip(
                            icon: _PixelStatIcon(
                              category: quest.statCategory,
                              size: 14,
                              withFrame: false,
                            ),
                            label: _statCategoryLabel(
                              quest.statCategory,
                              strings: strings,
                            ),
                            color: _statCategoryColor(quest.statCategory),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _StampButton(
                                  label: strings.tr(zh: '核准', en: 'Approve'),
                                  iconWidget: const _PixelLabelGlyph(
                                    glyph: 'OK',
                                  ),
                                  tone: _StampTone.green,
                                  onPressed: _submitting
                                      ? null
                                      : () {
                                          _review(quest.id, true);
                                        },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _StampButton(
                                  label: strings.tr(zh: '退回', en: 'Reject'),
                                  iconWidget: const _PixelLabelGlyph(
                                    glyph: 'NO',
                                  ),
                                  tone: _StampTone.ruby,
                                  onPressed: _submitting
                                      ? null
                                      : () {
                                          _review(quest.id, false);
                                        },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}
