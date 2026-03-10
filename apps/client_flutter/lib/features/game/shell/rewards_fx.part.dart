part of '../game_shell_page.dart';

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
    final strings = AppStrings.of(context);
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
                          strings.tr(
                            zh: '你已升到 Lv.${widget.newLevel}',
                            en: 'You reached Lv.${widget.newLevel}',
                          ),
                          style: const TextStyle(
                            color: AppColors.inkBrown,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.tr(
                            zh: '冒險者之魂正在閃耀',
                            en: 'Your adventurer spirit is shining',
                          ),
                          style: const TextStyle(
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
