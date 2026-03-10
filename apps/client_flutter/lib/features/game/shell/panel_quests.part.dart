part of '../game_shell_page.dart';

class _QuestList extends StatelessWidget {
  const _QuestList({
    required this.state,
    required this.onSubmit,
    required this.canSubmitQuests,
    required this.lowFxMode,
  });

  final AsyncValue<List<QuestInstance>> state;
  final void Function(String questId) onSubmit;
  final bool canSubmitQuests;
  final bool lowFxMode;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return state.when(
      data: (quests) {
        final taskQuests = quests
            .where((quest) => quest.category != QuestCategory.habit)
            .toList(growable: false);
        if (taskQuests.isEmpty) {
          return _QuestEmptyState(animateLockFlash: !lowFxMode);
        }

        return ListView.separated(
          itemCount: taskQuests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final quest = taskQuests[index];
            final canSubmit =
                canSubmitQuests &&
                (quest.status == QuestStatus.available ||
                    quest.status == QuestStatus.rejected);

            return _PixelQuestCard(
              quest: quest,
              canSubmit: canSubmit,
              lowFxMode: lowFxMode,
              onSubmit: () {
                onSubmit(quest.id);
              },
            );
          },
        );
      },
      loading: () => const Center(child: _PixelLoadingBar()),
      error: (err, _) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF4A2A20),
            border: Border.all(color: AppColors.hpRuby, width: 2.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA3E2723),
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Text(
            strings.tr(zh: '任務讀取錯誤：$err', en: 'Failed to load quests: $err'),
            style: const TextStyle(
              color: Color(0xFFFFD1CC),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelLoadingBar extends StatefulWidget {
  const _PixelLoadingBar();

  @override
  State<_PixelLoadingBar> createState() => _PixelLoadingBarState();
}

class _PixelLoadingBarState extends State<_PixelLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final segments = 9;
        final lit = ((t * (segments - 1)).round()).clamp(0, segments - 1);
        return Container(
          width: 210,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF2E2218),
            border: Border.all(color: const Color(0xFF6D4C41), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA3E2723),
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: List.generate(segments, (index) {
              final active = index <= lit;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: 12,
                  color: active
                      ? const Color(0xFF43A047)
                      : const Color(0xFF5D4037),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _PixelQuestCard extends StatefulWidget {
  const _PixelQuestCard({
    required this.quest,
    required this.canSubmit,
    required this.lowFxMode,
    required this.onSubmit,
  });

  final QuestInstance quest;
  final bool canSubmit;
  final bool lowFxMode;
  final VoidCallback onSubmit;

  @override
  State<_PixelQuestCard> createState() => _PixelQuestCardState();
}

class _PixelQuestCardState extends State<_PixelQuestCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final lifted = !widget.lowFxMode && (_hovered || _pressed);
    return MouseRegion(
      onEnter: widget.lowFxMode ? null : (_) => setState(() => _hovered = true),
      onExit: widget.lowFxMode ? null : (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: widget.lowFxMode
            ? null
            : (_) => setState(() => _pressed = true),
        onPointerUp: widget.lowFxMode
            ? null
            : (_) => setState(() => _pressed = false),
        onPointerCancel: widget.lowFxMode
            ? null
            : (_) => setState(() => _pressed = false),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 110),
          tween: Tween<double>(begin: 0, end: lifted ? -6 : 0),
          curve: Curves.easeOut,
          builder: (context, y, child) {
            return Transform.translate(offset: Offset(0, y), child: child);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4ECE1),
              border: Border.all(color: const Color(0xFF5D4037), width: 3),
              boxShadow: [
                const BoxShadow(
                  color: Color(0xFF3E2723),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
                if (lifted)
                  BoxShadow(
                    color: const Color(0xFF388E3C).withValues(alpha: 0.28),
                    offset: const Offset(0, 0),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PixelStatIcon(
                      category: widget.quest.statCategory,
                      size: 18,
                      withFrame: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.quest.templateTitle ?? widget.quest.templateId,
                        style: const TextStyle(
                          color: AppColors.inkBrown,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    _StatusBadge(status: widget.quest.status),
                  ],
                ),
                const SizedBox(height: 8),
                _StatGemChip(
                  icon: _PixelStatIcon(
                    category: widget.quest.statCategory,
                    size: 14,
                    withFrame: false,
                  ),
                  label: _statCategoryLabel(
                    widget.quest.statCategory,
                    strings: strings,
                  ),
                  color: _statCategoryColor(widget.quest.statCategory),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatGemChip(
                      icon: const _PixelLabelGlyph(glyph: 'XP'),
                      label: '${widget.quest.baseXp ?? 0}',
                      color: AppColors.apSapphire,
                    ),
                    const SizedBox(width: 6),
                    _StatGemChip(
                      icon: const _PixelLabelGlyph(glyph: 'CO'),
                      label: '${widget.quest.baseCoins ?? 0}',
                      color: const Color(0xFFB26A00),
                    ),
                  ],
                ),
                if (widget.quest.dueAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    strings.tr(
                      zh: '到期：${_formatDateTime(widget.quest.dueAt!)}',
                      en: 'Due: ${_formatDateTime(widget.quest.dueAt!)}',
                    ),
                    style: const TextStyle(
                      color: AppColors.navyBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _StampButton(
                  label: strings.tr(zh: '送審', en: 'Submit'),
                  iconWidget: const _PixelLabelGlyph(glyph: 'GO'),
                  tone: _StampTone.green,
                  onPressed: widget.canSubmit ? widget.onSubmit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestEmptyState extends StatefulWidget {
  const _QuestEmptyState({required this.animateLockFlash});

  final bool animateLockFlash;

  @override
  State<_QuestEmptyState> createState() => _QuestEmptyStateState();
}

class _QuestEmptyStateState extends State<_QuestEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.animateLockFlash) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _QuestEmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animateLockFlash == widget.animateLockFlash) {
      return;
    }
    if (widget.animateLockFlash) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1E7D2),
              border: Border.all(color: AppColors.woodFrame, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xAA3E2723),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 88,
                  height: 72,
                  child: CustomPaint(
                    painter: _PixelChestPainter(lockFlash: _controller.value),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.tr(zh: '目前沒有任務', en: 'No quests yet'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkBrown,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.tr(
                    zh: '公會寶箱正在等待新的冒險委託。',
                    en: 'The quest chest is waiting for new commissions.',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navyBlue,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PixelChestPainter extends CustomPainter {
  const _PixelChestPainter({required this.lockFlash});

  final double lockFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final pixel = size.width / 22;
    final flashProgress = lockFlash > 0.9 ? ((lockFlash - 0.9) / 0.1) : 0.0;
    final lockColor = Color.lerp(
      const Color(0xFFB26A00),
      const Color(0xFFFFE082),
      flashProgress,
    )!;

    void fill(int x, int y, int w, int h, Color color) {
      final paint = Paint()..color = color;
      canvas.drawRect(
        Rect.fromLTWH(x * pixel, y * pixel, w * pixel, h * pixel),
        paint,
      );
    }

    fill(1, 6, 20, 10, const Color(0xFF8D6E63));
    fill(1, 6, 20, 2, const Color(0xFFA1887F));
    fill(2, 8, 18, 8, const Color(0xFF6D4C41));
    fill(9, 8, 4, 8, lockColor);
    fill(9, 10, 4, 2, const Color(0xFFB26A00));
    fill(1, 5, 20, 1, const Color(0xFF3E2723));
    fill(1, 16, 20, 1, const Color(0xFF3E2723));
    fill(0, 6, 1, 10, const Color(0xFF3E2723));
    fill(21, 6, 1, 10, const Color(0xFF3E2723));
    fill(10, 11, 2, 2, const Color(0xFF5D4037));
    fill(
      9,
      9,
      4,
      1,
      Color.lerp(const Color(0xFFFFE082), Colors.white, flashProgress)!,
    );
    if (flashProgress > 0) {
      fill(11, 8, 1, 1, Colors.white.withValues(alpha: 0.9));
    }
  }

  @override
  bool shouldRepaint(covariant _PixelChestPainter oldDelegate) {
    return oldDelegate.lockFlash != lockFlash;
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} $hour:$minute';
}
