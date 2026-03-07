part of 'game_shell_page.dart';

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
    return state.when(
      data: (quests) {
        if (quests.isEmpty) {
          return _QuestEmptyState(animateLockFlash: !lowFxMode);
        }

        return ListView.separated(
          itemCount: quests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final quest = quests[index];
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
            '任務讀取錯誤：$err',
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
                  label: _statCategoryLabel(widget.quest.statCategory),
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
                    '到期：${_formatDateTime(widget.quest.dueAt!)}',
                    style: const TextStyle(
                      color: AppColors.navyBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _StampButton(
                  label: '送審',
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
                const Text(
                  '目前沒有任務',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkBrown,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '公會寶箱正在等待新的冒險委託。',
                  style: TextStyle(
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

class _FloatingRewardEvent {
  const _FloatingRewardEvent({
    required this.id,
    required this.text,
    required this.tone,
    required this.hunterId,
    required this.lane,
  });

  final String id;
  final String text;
  final Color tone;
  final String hunterId;
  final int lane;
}

class _FloatingRewardText extends StatefulWidget {
  const _FloatingRewardText({
    super.key,
    required this.event,
    required this.anchorResolver,
    required this.onFinished,
  });

  final _FloatingRewardEvent event;
  final Offset Function() anchorResolver;
  final VoidCallback onFinished;

  @override
  State<_FloatingRewardText> createState() => _FloatingRewardTextState();
}

class _FloatingRewardTextState extends State<_FloatingRewardText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 980),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            widget.onFinished();
          }
        });
    _controller.forward();
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
        final progress = Curves.easeOutCubic.transform(_controller.value);
        final opacity = (1 - progress).clamp(0.0, 1.0);
        final riseY = -70 * progress;
        final anchor = widget.anchorResolver();
        return Transform.translate(
          offset: Offset(anchor.dx - 130, anchor.dy + riseY),
          child: Opacity(
            opacity: opacity,
            child: SizedBox(
              width: 260,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xF03B2A22),
                    border: Border.all(color: widget.event.tone, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.event.tone.withValues(alpha: 0.45),
                        blurRadius: 0,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.event.text,
                    style: TextStyle(
                      color: widget.event.tone,
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PixelLevelBurstPainter extends CustomPainter {
  const _PixelLevelBurstPainter({
    required this.progress,
    required this.burstColor,
  });

  final double progress;
  final Color burstColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final starCount = 14;
    final spread = (26 + (progress * 58));
    final alpha = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()..color = burstColor.withValues(alpha: 0.7 * alpha);
    final white = Paint()..color = Colors.white.withValues(alpha: 0.9 * alpha);

    for (var i = 0; i < starCount; i++) {
      final angle = ((2 * math.pi) * i / starCount) + (progress * 0.65);
      final p = Offset(
        center.dx + math.cos(angle) * spread,
        center.dy + math.sin(angle) * spread,
      );
      final pixel = 2.0 + ((i % 3) * 0.7);
      canvas.drawRect(
        Rect.fromCenter(center: p, width: pixel, height: pixel),
        paint,
      );
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromCenter(
            center: p.translate(0.8, -0.8),
            width: pixel * 0.5,
            height: pixel * 0.5,
          ),
          white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelLevelBurstPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.burstColor != burstColor;
  }
}

class _LevelUpDialog extends StatefulWidget {
  const _LevelUpDialog({required this.newLevel});

  final int newLevel;

  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    )..forward();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
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
        final progress = Curves.easeOutBack.transform(_controller.value);
        final scale = 0.82 + (progress * 0.18);
        final borderPulse = (math.sin(_controller.value * math.pi * 8) + 1) / 2;
        final borderColor = Color.lerp(
          const Color(0xFF6A4A2F),
          const Color(0xFFB8874A),
          borderPulse * 0.45,
        )!;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 360,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PixelLevelBurstPainter(
                        progress: _controller.value,
                        burstColor: const Color(0xFFFFD54F),
                      ),
                    ),
                  ),
                  Container(
                    width: 340,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9E9B4),
                      border: Border.all(color: borderColor, width: 4),
                      boxShadow: [
                        const BoxShadow(
                          color: Color(0xFF3E2723),
                          offset: Offset(0, 6),
                          blurRadius: 0,
                        ),
                        BoxShadow(
                          color: const Color(
                            0xFFFFE082,
                          ).withValues(alpha: 0.18 * borderPulse),
                          offset: const Offset(0, 0),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 260,
                          height: 52,
                          child: CustomPaint(
                            painter: const _PixelWordPainter(
                              text: 'LEVEL UP!',
                              color: AppColors.inkBrown,
                              shadowColor: Color(0xFFA06B39),
                              pixelSize: 3.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '你已升到 Lv.${widget.newLevel}',
                          style: const TextStyle(
                            color: AppColors.inkBrown,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '冒險者之魂正在閃耀',
                          style: TextStyle(
                            color: Color(0xFF6D4C41),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PixelWordPainter extends CustomPainter {
  const _PixelWordPainter({
    required this.text,
    required this.color,
    required this.shadowColor,
    required this.pixelSize,
  });

  final String text;
  final Color color;
  final Color shadowColor;
  final double pixelSize;

  static const Map<String, List<String>> _glyphs = {
    'L': ['10000', '10000', '10000', '10000', '11111'],
    'E': ['11111', '10000', '11110', '10000', '11111'],
    'V': ['10001', '10001', '10001', '01010', '00100'],
    'U': ['10001', '10001', '10001', '10001', '11111'],
    'P': ['11110', '10001', '11110', '10000', '10000'],
    '!': ['1', '1', '1', '0', '1'],
    ' ': ['0', '0', '0', '0', '0'],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final chars = text.toUpperCase().split('');
    final totalUnits = chars.fold<int>(0, (sum, ch) {
      final glyph = _glyphs[ch] ?? _glyphs[' '];
      return sum + (glyph!.first.length + 1);
    });
    final contentWidth = (totalUnits - 1).clamp(0, 9999) * pixelSize;
    var cursorX = ((size.width - contentWidth) / 2).clamp(0.0, size.width);
    final cursorY = ((size.height - (5 * pixelSize)) / 2).clamp(
      0.0,
      size.height,
    );

    final fg = Paint()..color = color;
    final sh = Paint()..color = shadowColor;

    for (final ch in chars) {
      final glyph = _glyphs[ch] ?? _glyphs[' '];
      if (glyph == null) {
        continue;
      }
      final width = glyph.first.length;
      for (var row = 0; row < glyph.length; row++) {
        final line = glyph[row];
        for (var col = 0; col < line.length; col++) {
          if (line.codeUnitAt(col) != 49) {
            continue;
          }
          final x = cursorX + (col * pixelSize);
          final y = cursorY + (row * pixelSize);
          canvas.drawRect(
            Rect.fromLTWH(x + 1, y + 1, pixelSize, pixelSize),
            sh,
          );
          canvas.drawRect(Rect.fromLTWH(x, y, pixelSize, pixelSize), fg);
        }
      }
      cursorX += (width + 1) * pixelSize;
    }
  }

  @override
  bool shouldRepaint(covariant _PixelWordPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.color != color ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.pixelSize != pixelSize;
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

class _ParchmentSection extends StatelessWidget {
  const _ParchmentSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.woodFrame, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowHard,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PixelLabelGlyph(glyph: _iconGlyph(icon)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppColors.inkBrown,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final QuestStatus status;

  @override
  Widget build(BuildContext context) {
    final (text, tint) = switch (status) {
      QuestStatus.available => ('可接取', AppColors.stampGreen),
      QuestStatus.submitted => ('待審', const Color(0xFFB26A00)),
      QuestStatus.approved => ('完成', AppColors.apSapphire),
      QuestStatus.rejected => ('重試', AppColors.hpRuby),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        border: Border.all(color: tint.withValues(alpha: 0.75), width: 2),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.3),
            offset: const Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: tint,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatGemChip extends StatelessWidget {
  const _StatGemChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final Widget icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            offset: const Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PixelLabelGlyph extends StatelessWidget {
  const _PixelLabelGlyph({required this.glyph});

  final String glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF3E2723),
        border: Border.all(color: const Color(0xFFBCA88C), width: 1),
      ),
      child: Text(
        glyph,
        style: const TextStyle(
          color: Color(0xFFF4ECE1),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _PixelStatIcon extends StatelessWidget {
  const _PixelStatIcon({
    required this.category,
    required this.size,
    required this.withFrame,
  });

  final QuestStatCategory category;
  final double size;
  final bool withFrame;

  @override
  Widget build(BuildContext context) {
    final iconWidget = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PixelStatPainter(
          category: category,
          tone: _statCategoryColor(category),
        ),
      ),
    );
    if (!withFrame) {
      return iconWidget;
    }
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE0C5),
        border: Border.all(color: const Color(0xFF6B4A32), width: 1.6),
      ),
      child: iconWidget,
    );
  }
}

class _PixelStatPainter extends CustomPainter {
  const _PixelStatPainter({required this.category, required this.tone});

  final QuestStatCategory category;
  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final pixel = math.max(1.0, (size.shortestSide / 8).floorToDouble());
    final bg = Paint()..color = const Color(0xFF2E2218);
    canvas.drawRect(Rect.fromLTWH(0, 0, pixel * 8, pixel * 8), bg);

    final fg = Paint()..color = tone;
    final hl = Paint()..color = Colors.white.withValues(alpha: 0.38);

    void px(int x, int y, Paint paint) {
      canvas.drawRect(Rect.fromLTWH(x * pixel, y * pixel, pixel, pixel), paint);
    }

    Iterable<(int, int)> pattern = switch (category) {
      QuestStatCategory.strength => const [
        (3, 0),
        (4, 0),
        (3, 1),
        (4, 1),
        (3, 2),
        (4, 2),
        (2, 3),
        (3, 3),
        (4, 3),
        (5, 3),
        (3, 4),
        (4, 4),
        (3, 5),
        (4, 5),
        (2, 6),
        (5, 6),
        (3, 7),
        (4, 7),
      ],
      QuestStatCategory.intelligence => const [
        (1, 1),
        (2, 1),
        (3, 1),
        (4, 1),
        (5, 1),
        (6, 1),
        (1, 2),
        (3, 2),
        (4, 2),
        (6, 2),
        (1, 3),
        (2, 3),
        (3, 3),
        (4, 3),
        (5, 3),
        (6, 3),
        (1, 4),
        (3, 4),
        (4, 4),
        (6, 4),
        (1, 5),
        (2, 5),
        (3, 5),
        (4, 5),
        (5, 5),
        (6, 5),
      ],
      QuestStatCategory.agility => const [
        (1, 5),
        (2, 4),
        (3, 3),
        (4, 2),
        (5, 1),
        (2, 6),
        (3, 5),
        (4, 4),
        (5, 3),
        (6, 2),
        (4, 6),
        (5, 5),
        (6, 4),
      ],
      QuestStatCategory.vitality => const [
        (3, 1),
        (4, 1),
        (2, 2),
        (3, 2),
        (4, 2),
        (5, 2),
        (1, 3),
        (2, 3),
        (3, 3),
        (4, 3),
        (5, 3),
        (6, 3),
        (2, 4),
        (3, 4),
        (4, 4),
        (5, 4),
        (3, 5),
        (4, 5),
        (3, 6),
        (4, 6),
      ],
      QuestStatCategory.charisma => const [
        (3, 0),
        (4, 0),
        (3, 1),
        (4, 1),
        (0, 3),
        (1, 3),
        (2, 3),
        (3, 3),
        (4, 3),
        (5, 3),
        (6, 3),
        (7, 3),
        (3, 4),
        (4, 4),
        (3, 5),
        (4, 5),
        (2, 6),
        (5, 6),
        (1, 7),
        (6, 7),
      ],
      QuestStatCategory.none => const [
        (1, 1),
        (2, 1),
        (3, 1),
        (4, 1),
        (5, 1),
        (6, 1),
        (1, 2),
        (6, 2),
        (1, 3),
        (6, 3),
        (1, 4),
        (6, 4),
        (1, 5),
        (6, 5),
        (1, 6),
        (2, 6),
        (3, 6),
        (4, 6),
        (5, 6),
        (6, 6),
      ],
    };

    for (final point in pattern) {
      px(point.$1, point.$2, fg);
    }
    px(1, 1, hl);
    px(2, 1, hl);
  }

  @override
  bool shouldRepaint(covariant _PixelStatPainter oldDelegate) {
    return oldDelegate.category != category || oldDelegate.tone != tone;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EED7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7B5A3C), width: 2),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navyBlue,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.inkBrown,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _StampButton extends StatefulWidget {
  const _StampButton({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.tone,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final _StampTone tone;
  final VoidCallback? onPressed;

  @override
  State<_StampButton> createState() => _StampButtonState();
}

class _StampButtonState extends State<_StampButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final palette = _buttonPalette(widget.tone, enabled);
    final leading =
        widget.iconWidget ??
        (widget.icon == null
            ? null
            : _PixelLabelGlyph(glyph: _iconGlyph(widget.icon!)));

    return GestureDetector(
      onTapDown: enabled
          ? (_) {
              setState(() {
                _pressed = true;
              });
            }
          : null,
      onTapUp: enabled
          ? (_) {
              setState(() {
                _pressed = false;
              });
            }
          : null,
      onTapCancel: enabled
          ? () {
              setState(() {
                _pressed = false;
              });
            }
          : null,
      onTap: widget.onPressed,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 70),
        offset: _pressed ? const Offset(0, 0.08) : Offset.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _pressed ? palette.pressedFace : palette.face,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              top: BorderSide(color: palette.edge, width: 2.2),
              left: BorderSide(color: palette.edge, width: 2.2),
              right: BorderSide(color: palette.edge, width: 2.2),
              bottom: BorderSide(
                color: palette.edge,
                width: _pressed ? 1.4 : 5,
              ),
            ),
            boxShadow: _pressed
                ? const []
                : [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.65),
                      offset: const Offset(0, 2),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(color: palette.text, size: 18),
                  child: leading,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _iconGlyph(IconData icon) {
  if (icon == Icons.groups_rounded) {
    return 'FRD';
  }
  if (icon == Icons.construction_rounded) {
    return 'TOOL';
  }
  if (icon == Icons.local_fire_department) {
    return 'FIR';
  }
  if (icon == Icons.refresh) {
    return 'REF';
  }
  if (icon == Icons.person_add_alt_1) {
    return 'ADD';
  }
  if (icon == Icons.mail_outline_rounded) {
    return 'MAIL';
  }
  if (icon == Icons.check_circle || icon == Icons.check_circle_rounded) {
    return 'OK';
  }
  if (icon == Icons.cancel || icon == Icons.close_rounded) {
    return 'NO';
  }
  if (icon == Icons.post_add) {
    return 'NEW';
  }
  if (icon == Icons.campaign) {
    return 'HORN';
  }
  if (icon == Icons.send_rounded) {
    return 'SEND';
  }
  if (icon == Icons.logout || icon == Icons.login_rounded) {
    return 'GO';
  }
  if (icon == Icons.touch_app_rounded) {
    return 'ACT';
  }
  if (icon == Icons.bookmark_add_rounded) {
    return 'SAVE';
  }
  if (icon == Icons.auto_awesome) {
    return 'STAR';
  }
  if (icon == Icons.inventory_2) {
    return 'BOX';
  }
  if (icon == Icons.badge_rounded || icon == Icons.badge) {
    return 'ID';
  }
  if (icon == Icons.menu_book_rounded) {
    return 'SC';
  }
  return 'UI';
}

class _ButtonPalette {
  const _ButtonPalette({
    required this.face,
    required this.pressedFace,
    required this.edge,
    required this.shadow,
    required this.text,
  });

  final Color face;
  final Color pressedFace;
  final Color edge;
  final Color shadow;
  final Color text;
}

_ButtonPalette _buttonPalette(_StampTone tone, bool enabled) {
  final raw = switch (tone) {
    _StampTone.wood => const _ButtonPalette(
      face: AppColors.woodButton,
      pressedFace: Color(0xFF775A52),
      edge: AppColors.woodButtonEdge,
      shadow: Color(0xFF4E342E),
      text: Color(0xFFF9F4EA),
    ),
    _StampTone.green => const _ButtonPalette(
      face: AppColors.submitGreen,
      pressedFace: Color(0xFF2E8B33),
      edge: AppColors.submitGreenEdge,
      shadow: Color(0xFF1B5E20),
      text: Color(0xFFF4F8EC),
    ),
    _StampTone.ruby => const _ButtonPalette(
      face: Color(0xFFD32F2F),
      pressedFace: Color(0xFFB71C1C),
      edge: Color(0xFF7F1111),
      shadow: Color(0xFF601010),
      text: Color(0xFFFDF1EF),
    ),
    _StampTone.blue => const _ButtonPalette(
      face: Color(0xFF1976D2),
      pressedFace: Color(0xFF125CA6),
      edge: Color(0xFF103F72),
      shadow: Color(0xFF0B2A4D),
      text: Color(0xFFEAF3FE),
    ),
  };

  if (enabled) {
    return raw;
  }

  return _ButtonPalette(
    face: raw.face.withValues(alpha: 0.45),
    pressedFace: raw.pressedFace.withValues(alpha: 0.45),
    edge: raw.edge.withValues(alpha: 0.5),
    shadow: raw.shadow.withValues(alpha: 0.35),
    text: raw.text.withValues(alpha: 0.55),
  );
}

Color _statCategoryColor(QuestStatCategory category) {
  return switch (category) {
    QuestStatCategory.strength => const Color(0xFFD84343),
    QuestStatCategory.intelligence => AppColors.apSapphire,
    QuestStatCategory.agility => const Color(0xFF2E7D32),
    QuestStatCategory.vitality => const Color(0xFF8E24AA),
    QuestStatCategory.charisma => const Color(0xFFF57C00),
    QuestStatCategory.none => AppColors.woodFrame,
  };
}

String _statCategoryLabel(QuestStatCategory category) {
  return switch (category) {
    QuestStatCategory.strength => 'STR 力量',
    QuestStatCategory.intelligence => 'INT 智力',
    QuestStatCategory.agility => 'AGI 敏捷',
    QuestStatCategory.vitality => 'VIT 耐力',
    QuestStatCategory.charisma => 'CHA 魅力',
    QuestStatCategory.none => 'NONE 未分類',
  };
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} $hour:$minute';
}
