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

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} $hour:$minute';
}
