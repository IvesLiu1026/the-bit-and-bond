part of '../game_shell_page.dart';

class _HudOverlay extends StatelessWidget {
  const _HudOverlay({required this.progressionState, required this.onRefresh});

  final AsyncValue<Progression> progressionState;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            _PixelLabelGlyph(glyph: 'BOX'),
            SizedBox(width: 6),
            Text(
              '冒險儲物箱',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.inkBrown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        progressionState.when(
          data: (p) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '玩家 等級 ${p.level}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppColors.inkBrown,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatGemChip(
                      icon: const _PixelLabelGlyph(glyph: 'XP'),
                      label: '${p.xp} XP',
                      color: AppColors.apSapphire,
                    ),
                    _StatGemChip(
                      icon: const _PixelLabelGlyph(glyph: 'CO'),
                      label: '${p.coins} 金幣',
                      color: const Color(0xFFB26A00),
                    ),
                    _StatGemChip(
                      icon: const _PixelLabelGlyph(glyph: 'Q'),
                      label: '${p.availableQuests} 任務',
                      color: AppColors.stampGreen,
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 68,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.8)),
          ),
          error: (err, _) => Text(
            '狀態讀取錯誤：$err',
            style: const TextStyle(
              color: AppColors.hpRuby,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _StampButton(
          label: '刷新狀態',
          icon: Icons.refresh,
          tone: _StampTone.wood,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

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

    if (title.isEmpty) {
      _showError('請輸入任務標題');
      return;
    }
    if (rewardXp == null || rewardXp < 0) {
      _showError('獎勵 XP 必須是 0 以上整數');
      return;
    }
    if (rewardCoins == null || rewardCoins < 0) {
      _showError('獎勵金幣必須是 0 以上整數');
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
      title: '公會工具',
      icon: Icons.construction_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: '任務標題',
              isDense: true,
              filled: true,
              fillColor: Color(0xFFE7DDC9),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descriptionController,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: '任務描述（可選）',
              isDense: true,
              filled: true,
              fillColor: Color(0xFFE7DDC9),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<QuestStatCategory>(
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
                        Text(_statCategoryLabel(value)),
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
            decoration: const InputDecoration(
              labelText: '能力標籤',
              isDense: true,
              filled: true,
              fillColor: Color(0xFFE7DDC9),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _xpController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'XP',
                    isDense: true,
                    filled: true,
                    fillColor: Color(0xFFE7DDC9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _coinsController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '金幣',
                    isDense: true,
                    filled: true,
                    fillColor: Color(0xFFE7DDC9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StampButton(
            label: _submitting ? '處理中...' : '建立任務',
            icon: Icons.post_add,
            tone: _StampTone.green,
            onPressed: _submitting ? null : _create,
          ),
          const SizedBox(height: 8),
          Text(
            '待審任務 ${pending.length} 筆',
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
            const Text('目前沒有待審任務', style: TextStyle(color: AppColors.navyBlue))
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
                            label: _statCategoryLabel(quest.statCategory),
                            color: _statCategoryColor(quest.statCategory),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _StampButton(
                                  label: '核准',
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
                                  label: '退回',
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
