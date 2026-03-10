part of '../game_shell_page.dart';

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
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      cut: 12,
      shadowDepth: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelTag(
                label: _iconGlyph(icon),
                tone: PixelTone.wood,
                compact: true,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: PixelTypography.style(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.inkBrown,
                    height: 1.02,
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
    final strings = AppStrings.of(context);
    final (text, tint) = switch (status) {
      QuestStatus.available => (
        strings.tr(zh: '可接取', en: 'Available'),
        AppColors.stampGreen,
      ),
      QuestStatus.submitted => (
        strings.tr(zh: '待審', en: 'Pending'),
        const Color(0xFFB26A00),
      ),
      QuestStatus.approved => (
        strings.tr(zh: '完成', en: 'Complete'),
        AppColors.apSapphire,
      ),
      QuestStatus.rejected => (
        strings.tr(zh: '重試', en: 'Retry'),
        AppColors.hpRuby,
      ),
    };

    return PixelPanel(
      tone: _pixelToneForTint(tint),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      cut: 8,
      borderWidth: 2,
      shadowDepth: 2,
      faceColor: tint.withValues(alpha: 0.16),
      edgeColor: tint.withValues(alpha: 0.75),
      shadowColor: tint.withValues(alpha: 0.3),
      child: Text(
        text,
        style: PixelTypography.style(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          height: 1,
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
    this.labelColor,
  });

  final Widget icon;
  final String label;
  final Color color;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      tone: _pixelToneForTint(color),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      cut: 8,
      borderWidth: 2,
      shadowDepth: 2,
      faceColor: color.withValues(alpha: 0.12),
      edgeColor: color.withValues(alpha: 0.8),
      shadowColor: color.withValues(alpha: 0.2),
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
              style: PixelTypography.style(
                color: labelColor ?? AppColors.inkBrown,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                height: 1,
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
        color: const Color(0xFFF1E3C5),
        border: Border.all(color: const Color(0xFF7A5A3B), width: 1),
      ),
      child: Text(
        glyph,
        style: PixelTypography.style(
          color: AppColors.inkBrown,
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
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      cut: 10,
      borderWidth: 2,
      shadowDepth: 2,
      child: Column(
        children: [
          Text(
            title,
            style: PixelTypography.style(
              fontWeight: FontWeight.w800,
              color: AppColors.navyBlue,
              fontSize: 12,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: PixelTypography.style(
              fontWeight: FontWeight.w900,
              color: AppColors.inkBrown,
              fontSize: 20,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
