part of 'bitbond_game.dart';

enum FurnitureRenderMode { full, hotspot, flameOverlay }

class InteractiveFurniture extends PositionComponent {
  InteractiveFurniture({
    required this.type,
    required this.label,
    required Color tint,
    required Color accent,
    required super.size,
    this.spriteImage,
    this.interactive = true,
    this.collidable = true,
    this.renderMode = FurnitureRenderMode.full,
    this.showLabel = true,
  }) : _tint = tint,
       _accent = accent,
       super(anchor: Anchor.topLeft, priority: 500);

  final TavernFurnitureType type;
  final String label;
  final bool interactive;
  final bool collidable;
  final ui.Image? spriteImage;
  final FurnitureRenderMode renderMode;
  final bool showLabel;
  Color _tint;
  Color _accent;
  bool _campfireConnected = false;
  bool _campfireSpeaking = false;
  double _campfirePulse = 0;

  void applyPalette({required Color tint, required Color accent}) {
    _tint = tint;
    _accent = accent;
  }

  void setCampfireVisualState({
    required bool connected,
    required bool speaking,
    required double pulse,
  }) {
    _campfireConnected = connected;
    _campfireSpeaking = speaking;
    _campfirePulse = pulse.clamp(0.0, 1.0).toDouble();
  }

  @override
  Vector2 get center => position + (size / 2);

  Rect get boundsRect => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  Rect get collisionRect {
    final rect = boundsRect;
    return switch (type) {
      TavernFurnitureType.noticeBoard => Rect.fromLTWH(
        rect.left + 20,
        rect.bottom - 18,
        rect.width - 40,
        18,
      ),
      TavernFurnitureType.masterDesk => Rect.fromLTWH(
        rect.left + 8,
        rect.top + 18,
        rect.width - 16,
        rect.height - 24,
      ),
      TavernFurnitureType.guildChest => rect.deflate(8),
      TavernFurnitureType.campfireBar => rect.deflate(10),
      TavernFurnitureType.guildMerchant => Rect.fromLTWH(
        rect.left + 10,
        rect.top + 20,
        rect.width - 20,
        rect.height - 22,
      ),
      TavernFurnitureType.wallBookshelf => rect.deflate(8),
      TavernFurnitureType.honorBanner => rect.deflate(12),
      TavernFurnitureType.trainingDummy => Rect.fromLTWH(
        rect.left + 12,
        rect.top + 20,
        rect.width - 24,
        rect.height - 20,
      ),
    };
  }

  Vector2 get interactionPoint {
    if (!interactive) {
      final rect = boundsRect;
      return Vector2(rect.center.dx, rect.center.dy);
    }
    final rect = boundsRect;
    return switch (type) {
      TavernFurnitureType.noticeBoard => Vector2(
        rect.center.dx,
        rect.bottom + 26,
      ),
      TavernFurnitureType.masterDesk => Vector2(
        rect.center.dx,
        rect.bottom + 24,
      ),
      TavernFurnitureType.guildChest => Vector2(rect.center.dx, rect.center.dy),
      TavernFurnitureType.campfireBar => Vector2(rect.center.dx, rect.top - 10),
      TavernFurnitureType.guildMerchant => Vector2(
        rect.center.dx,
        rect.top - 8,
      ),
      TavernFurnitureType.wallBookshelf ||
      TavernFurnitureType.honorBanner ||
      TavernFurnitureType.trainingDummy => Vector2(
        rect.center.dx,
        rect.center.dy,
      ),
    };
  }

  double get interactionRadius {
    if (!interactive) {
      return 0;
    }
    return switch (type) {
      TavernFurnitureType.noticeBoard => 30,
      TavernFurnitureType.masterDesk => 32,
      TavernFurnitureType.guildChest => 42,
      TavernFurnitureType.campfireBar => 46,
      TavernFurnitureType.guildMerchant => 42,
      TavernFurnitureType.wallBookshelf ||
      TavernFurnitureType.honorBanner ||
      TavernFurnitureType.trainingDummy => 0,
    };
  }

  Rect get interactionZoneRect {
    if (!interactive) {
      return Rect.zero;
    }
    final rect = boundsRect;
    return switch (type) {
      TavernFurnitureType.noticeBoard => Rect.fromLTWH(
        rect.left + 12,
        rect.bottom - 12,
        rect.width - 24,
        56,
      ),
      TavernFurnitureType.masterDesk => Rect.fromLTWH(
        rect.left + 10,
        rect.bottom - 12,
        rect.width - 20,
        58,
      ),
      TavernFurnitureType.guildChest => rect.inflate(30),
      TavernFurnitureType.campfireBar => rect.inflate(32),
      TavernFurnitureType.guildMerchant => rect.inflate(30),
      TavernFurnitureType.wallBookshelf ||
      TavernFurnitureType.honorBanner ||
      TavernFurnitureType.trainingDummy => Rect.zero,
    };
  }

  bool hit(Vector2 point) {
    return boundsRect.contains(Offset(point.x, point.y));
  }

  double distanceToInteractionZone(Vector2 point) {
    if (!interactive) {
      return double.infinity;
    }
    final rect = interactionZoneRect;
    if (rect.isEmpty) {
      return double.infinity;
    }
    final px = point.x;
    final py = point.y;
    final dx = px < rect.left
        ? rect.left - px
        : (px > rect.right ? px - rect.right : 0.0);
    final dy = py < rect.top
        ? rect.top - py
        : (py > rect.bottom ? py - rect.bottom : 0.0);
    return math.sqrt((dx * dx) + (dy * dy));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF3E2723);

    switch (renderMode) {
      case FurnitureRenderMode.full:
        final shadow = Paint()..color = const Color(0x6633221A);
        canvas.drawRect(rect.shift(const Offset(2, 3)), shadow);
        switch (type) {
          case TavernFurnitureType.noticeBoard:
            _renderNoticeBoard(canvas, rect, border);
            break;
          case TavernFurnitureType.masterDesk:
            _renderMasterDesk(canvas, rect, border);
            break;
          case TavernFurnitureType.guildChest:
            _renderGuildChest(canvas, rect, border);
            break;
          case TavernFurnitureType.campfireBar:
            _renderCampfireBar(canvas, rect, border);
            break;
          case TavernFurnitureType.guildMerchant:
            _renderGuildMerchant(canvas, rect, border);
            break;
          case TavernFurnitureType.wallBookshelf:
            _renderWallBookshelf(canvas, rect, border);
            break;
          case TavernFurnitureType.honorBanner:
            _renderHonorBanner(canvas, rect, border);
            break;
          case TavernFurnitureType.trainingDummy:
            _renderTrainingDummy(canvas, rect, border);
            break;
        }
      case FurnitureRenderMode.hotspot:
        if (interactive) {
          final glow = Paint()
            ..color = _accent.withValues(alpha: 0.08)
            ..style = PaintingStyle.fill;
          final outline = Paint()
            ..color = _accent.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawRect(rect, glow);
          canvas.drawRect(rect, outline);
        }
      case FurnitureRenderMode.flameOverlay:
        if (type == TavernFurnitureType.campfireBar) {
          _renderCampfireFlameOverlay(canvas, rect);
        }
    }
    if (showLabel) {
      _renderFloatingLabel(canvas, rect);
    }
  }

  void _renderNoticeBoard(Canvas canvas, Rect rect, Paint border) {
    final woodFrame = Paint()..color = _tint;
    final parchment = Paint()..color = const Color(0xFFF4ECE1);
    final accentPaint = Paint()..color = _accent;
    final pinPaint = Paint()..color = const Color(0xFF3E2723);

    canvas.drawRect(rect, woodFrame);
    canvas.drawRect(rect, border);
    final paperRect = Rect.fromLTWH(
      rect.left + 10,
      rect.top + 14,
      rect.width - 20,
      rect.height - 38,
    );
    canvas.drawRect(paperRect, parchment);
    canvas.drawRect(paperRect, border);
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 8, rect.top + 8, rect.width - 16, 7),
      accentPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(paperRect.left + 8, paperRect.top + 8, 5, 5),
      pinPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(paperRect.right - 13, paperRect.top + 8, 5, 5),
      pinPaint,
    );
  }

  void _renderMasterDesk(Canvas canvas, Rect rect, Paint border) {
    final deskTop = Paint()..color = _tint;
    final deskBody = Paint()..color = const Color(0xFF5C3B2A);
    final scrollPaper = Paint()..color = const Color(0xFFF0E2C4);
    final scrollSeal = Paint()..color = _accent;

    final topRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      rect.height * 0.32,
    );
    final bodyRect = Rect.fromLTWH(
      rect.left + 6,
      rect.top + (rect.height * 0.30),
      rect.width - 12,
      rect.height * 0.66,
    );
    canvas.drawRect(topRect, deskTop);
    canvas.drawRect(bodyRect, deskBody);
    canvas.drawRect(rect, border);

    final scrollRect = Rect.fromLTWH(
      rect.left + 20,
      rect.top + 8,
      rect.width - 40,
      math.max(8, rect.height * 0.18),
    );
    canvas.drawRect(scrollRect, scrollPaper);
    canvas.drawRect(scrollRect, border);
    canvas.drawRect(
      Rect.fromLTWH(scrollRect.center.dx - 5, scrollRect.center.dy - 3, 10, 6),
      scrollSeal,
    );
  }

  void _renderGuildChest(Canvas canvas, Rect rect, Paint border) {
    final chestBody = Paint()..color = _tint;
    final chestLid = Paint()..color = const Color(0xFF6C4A32);
    final trim = Paint()..color = _accent;
    final lock = Paint()..color = const Color(0xFF3E2723);

    final lidRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      rect.height * 0.38,
    );
    final bodyRect = Rect.fromLTWH(
      rect.left,
      rect.top + (rect.height * 0.34),
      rect.width,
      rect.height * 0.66,
    );
    canvas.drawRect(bodyRect, chestBody);
    canvas.drawRect(lidRect, chestLid);
    canvas.drawRect(rect, border);

    canvas.drawRect(
      Rect.fromLTWH(rect.left + 8, rect.top + 8, rect.width - 16, 6),
      trim,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 8, rect.center.dy - 3, rect.width - 16, 6),
      trim,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.center.dx - 5, rect.center.dy - 7, 10, 14),
      lock,
    );
  }

  void _renderCampfireBar(Canvas canvas, Rect rect, Paint border) {
    final base = Paint()..color = _tint;
    final ring = Paint()..color = const Color(0xFF3E2723);
    final ember = Paint()..color = const Color(0xFF8D6E63);
    final frame = (DateTime.now().millisecondsSinceEpoch ~/ 115) % 4;
    final glowAlpha = _campfireSpeaking
        ? (0.24 + (_campfirePulse * 0.40))
        : (_campfireConnected ? 0.20 : 0.10);
    final glow = Paint()..color = _accent.withValues(alpha: glowAlpha);
    final flameCore = Paint()..color = const Color(0xFFFFF176);
    final flameOuter = Paint()..color = _accent;
    final aura = Paint()
      ..color = (_campfireSpeaking ? const Color(0xFFFFD54F) : _accent)
          .withValues(
            alpha: _campfireSpeaking ? (0.20 + (_campfirePulse * 0.28)) : 0.12,
          );

    canvas.drawRect(rect, base);
    canvas.drawRect(rect, border);

    final pitRect = Rect.fromLTWH(
      rect.left + 14,
      rect.top + 10,
      rect.width - 28,
      rect.height - 20,
    );
    canvas.drawRect(pitRect, ring);
    canvas.drawRect(pitRect.inflate(8), glow);
    if (_campfireConnected) {
      final auraRadius = _campfireSpeaking ? (18 + (_campfirePulse * 14)) : 12;
      canvas.drawCircle(
        Offset(pitRect.center.dx, pitRect.bottom - 8),
        auraRadius.toDouble(),
        aura,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        pitRect.left + 10,
        pitRect.top + 16,
        pitRect.width - 20,
        pitRect.height - 24,
      ),
      ember,
    );

    final fireImage = spriteImage;
    if (fireImage != null) {
      const frameSize = 32.0;
      final sourceRect = Rect.fromLTWH(
        frame * frameSize,
        0,
        frameSize,
        frameSize,
      );
      final destinationRect = Rect.fromCenter(
        center: Offset(pitRect.center.dx, pitRect.center.dy - 1),
        width: 54,
        height: 54,
      );
      canvas.drawImageRect(fireImage, sourceRect, destinationRect, Paint());
      canvas.drawCircle(
        Offset(destinationRect.center.dx, destinationRect.bottom - 10),
        7,
        flameCore,
      );
    } else {
      final center = pitRect.center;
      final frameHeight = switch (frame) {
        0 => 30,
        1 => 34,
        2 => 28,
        _ => 32,
      };
      final flame = Path()
        ..moveTo(center.dx, pitRect.bottom - frameHeight.toDouble())
        ..lineTo(center.dx - 16, pitRect.bottom - 14)
        ..lineTo(center.dx, pitRect.bottom - 32)
        ..lineTo(center.dx + 16, pitRect.bottom - 14)
        ..close();
      canvas.drawPath(flame, flameOuter);
      canvas.drawCircle(
        Offset(center.dx, pitRect.bottom - (26 + (frame.isEven ? 1 : -1))),
        8,
        flameCore,
      );
    }
  }

  void _renderCampfireFlameOverlay(Canvas canvas, Rect rect) {
    final glowAlpha = _campfireSpeaking
        ? (0.24 + (_campfirePulse * 0.30))
        : (_campfireConnected ? 0.18 : 0.10);
    final glow = Paint()..color = _accent.withValues(alpha: glowAlpha);
    final aura = Paint()
      ..color = (_campfireSpeaking ? const Color(0xFFFFD54F) : _accent)
          .withValues(
            alpha: _campfireSpeaking ? (0.18 + (_campfirePulse * 0.22)) : 0.08,
          );
    final center = Offset(rect.center.dx, rect.center.dy);
    canvas.drawCircle(center, rect.width * 0.46, glow);
    if (_campfireConnected) {
      canvas.drawCircle(
        Offset(center.dx, center.dy + 8),
        rect.width *
            (_campfireSpeaking ? (0.34 + (_campfirePulse * 0.08)) : 0.28),
        aura,
      );
    }

    final fireImage = spriteImage;
    if (fireImage != null) {
      const frameSize = 32.0;
      final frame = (DateTime.now().millisecondsSinceEpoch ~/ 115) % 4;
      final sourceRect = Rect.fromLTWH(
        frame * frameSize,
        0,
        frameSize,
        frameSize,
      );
      final destinationRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy - 2),
        width: rect.width * 0.74,
        height: rect.height * 0.74,
      );
      canvas.drawImageRect(fireImage, sourceRect, destinationRect, Paint());
    }
  }

  void _renderGuildMerchant(Canvas canvas, Rect rect, Paint border) {
    final body = Paint()..color = _tint;
    final canopy = Paint()..color = _accent;
    final counter = Paint()..color = const Color(0xFF4E342E);
    final gem = Paint()..color = const Color(0xFF64B5F6);
    final coin = Paint()..color = const Color(0xFFFFD54F);
    final shade = Paint()..color = const Color(0x5523110A);

    canvas.drawRect(rect, body);
    canvas.drawRect(rect, border);
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 4, rect.top + 4, rect.width - 8, 20),
      canopy,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 8, rect.top + 30, rect.width - 16, 14),
      counter,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 12, rect.top + 50, rect.width - 24, 26),
      shade,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.center.dx - 18, rect.top + 34, 10, 10),
      gem,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.center.dx + 8, rect.top + 34, 10, 10),
      coin,
    );
  }

  void _renderWallBookshelf(Canvas canvas, Rect rect, Paint border) {
    final body = Paint()..color = _tint;
    final shelf = Paint()..color = const Color(0xFF4E342E);
    final bookA = Paint()..color = _accent;
    final bookB = Paint()..color = const Color(0xFF64B5F6);
    final bookC = Paint()..color = const Color(0xFFE57373);
    canvas.drawRect(rect, body);
    canvas.drawRect(rect, border);
    for (var i = 0; i < 3; i++) {
      final y = rect.top + 10 + (i * 22);
      canvas.drawRect(
        Rect.fromLTWH(rect.left + 6, y, rect.width - 12, 5),
        shelf,
      );
      for (var b = 0; b < 5; b++) {
        final x = rect.left + 10 + (b * 14);
        final paint = switch ((i + b) % 3) {
          0 => bookA,
          1 => bookB,
          _ => bookC,
        };
        canvas.drawRect(Rect.fromLTWH(x, y + 6, 9, 13), paint);
      }
    }
  }

  void _renderHonorBanner(Canvas canvas, Rect rect, Paint border) {
    final pole = Paint()..color = const Color(0xFF5D4037);
    final cloth = Paint()..color = _accent;
    final trim = Paint()..color = _tint;
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 4, rect.top, 6, rect.height),
      pole,
    );
    final bannerRect = Rect.fromLTWH(
      rect.left + 10,
      rect.top + 8,
      rect.width - 12,
      rect.height - 16,
    );
    canvas.drawRect(bannerRect, cloth);
    canvas.drawRect(bannerRect, border);
    canvas.drawRect(
      Rect.fromLTWH(
        bannerRect.left + 5,
        bannerRect.top + 6,
        bannerRect.width - 10,
        5,
      ),
      trim,
    );
    canvas.drawRect(
      Rect.fromLTWH(bannerRect.center.dx - 8, bannerRect.center.dy - 8, 16, 16),
      Paint()..color = const Color(0xFFF4ECE1),
    );
  }

  void _renderTrainingDummy(Canvas canvas, Rect rect, Paint border) {
    final stand = Paint()..color = _tint;
    final body = Paint()..color = _accent;
    final highlight = Paint()..color = const Color(0x66FFF8E1);
    final baseRect = Rect.fromLTWH(
      rect.left + 20,
      rect.bottom - 16,
      rect.width - 40,
      10,
    );
    final postRect = Rect.fromLTWH(
      rect.center.dx - 4,
      rect.top + 14,
      8,
      rect.height - 24,
    );
    final bodyRect = Rect.fromLTWH(
      rect.left + 16,
      rect.top + 10,
      rect.width - 32,
      32,
    );
    canvas.drawRect(baseRect, stand);
    canvas.drawRect(postRect, stand);
    canvas.drawRect(bodyRect, body);
    canvas.drawRect(bodyRect, border);
    canvas.drawRect(
      Rect.fromLTWH(bodyRect.left + 4, bodyRect.top + 4, bodyRect.width - 8, 4),
      highlight,
    );
  }

  void _renderFloatingLabel(Canvas canvas, Rect rect) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '[$label]',
        style: const TextStyle(
          color: Color(0xFFF8F0DD),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final padding = const Offset(8, 5);
    final tagWidth = textPainter.width + (padding.dx * 2);
    final tagHeight = textPainter.height + (padding.dy * 2);
    final left = rect.center.dx - (tagWidth / 2);
    final top = rect.top - tagHeight - 8;
    final tagRect = Rect.fromLTWH(left, top, tagWidth, tagHeight);
    final tagBg = Paint()..color = const Color(0xC433221A);
    final tagBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF8D6E63);
    canvas.drawRect(tagRect, tagBg);
    canvas.drawRect(tagRect, tagBorder);
    textPainter.paint(
      canvas,
      Offset(tagRect.left + padding.dx, tagRect.top + padding.dy - 1),
    );
  }
}
