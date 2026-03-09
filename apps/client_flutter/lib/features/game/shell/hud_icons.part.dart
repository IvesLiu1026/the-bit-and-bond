part of '../game_shell_page.dart';

enum _PixelHudIcon { map, menu, quest, desk, shop, bag, fire, theme, logout }

class _TopIconButton extends StatefulWidget {
  const _TopIconButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
    this.selected = false,
  });

  final _PixelHudIcon icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool compact;
  final bool selected;

  @override
  State<_TopIconButton> createState() => _TopIconButtonState();
}

class _TopIconButtonState extends State<_TopIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final extent = widget.compact ? 60.0 : 60.0;
    final iconSize = widget.compact ? 20.0 : 22.0;
    final highlightColor = _hudIconTone(widget.icon);

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 70),
          offset: _pressed ? const Offset(0, 0.06) : Offset.zero,
          child: SizedBox(
            width: extent,
            height: extent,
            child: PixelPanel(
              tone: widget.selected ? PixelTone.blue : PixelTone.parchment,
              cut: 12,
              shadowDepth: _pressed ? 1.5 : 4,
              faceColor: widget.selected
                  ? highlightColor.withValues(alpha: _pressed ? 0.24 : 0.14)
                  : (_pressed
                        ? const Color(0xFFE8DAC1)
                        : AppColors.parchment.withValues(alpha: 0.98)),
              edgeColor: widget.selected ? highlightColor : AppColors.woodFrame,
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CustomPaint(
                      painter: _PixelHudIconPainter(
                        icon: widget.icon,
                        tone: highlightColor,
                        selected: widget.selected,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: AppColors.inkBrown,
                      fontSize: widget.compact ? 9.5 : 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _hudIconTone(_PixelHudIcon icon) {
  return switch (icon) {
    _PixelHudIcon.map => const Color(0xFF6ABFD6),
    _PixelHudIcon.menu => const Color(0xFF8A6FD1),
    _PixelHudIcon.quest => const Color(0xFFD9A441),
    _PixelHudIcon.desk => const Color(0xFF9A7354),
    _PixelHudIcon.shop => AppColors.submitGreen,
    _PixelHudIcon.bag => const Color(0xFFB28A58),
    _PixelHudIcon.fire => const Color(0xFFED8C34),
    _PixelHudIcon.theme => const Color(0xFF6F8CCF),
    _PixelHudIcon.logout => AppColors.hpRuby,
  };
}

class _PixelHudIconPainter extends CustomPainter {
  const _PixelHudIconPainter({
    required this.icon,
    required this.tone,
    required this.selected,
  });

  final _PixelHudIcon icon;
  final Color tone;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 16;
    final outline = Paint()..color = const Color(0xFF201510);
    final fill = Paint()..color = tone;
    final gold = Paint()..color = const Color(0xFFFFC64B);
    final coin = Paint()..color = const Color(0xFFFFD45A);
    final ember = Paint()..color = const Color(0xFFFFE082);
    final shade = Paint()
      ..color = Color.lerp(tone, const Color(0xFF2C1B12), 0.34) ?? tone;
    final light = Paint()
      ..color = Color.lerp(tone, Colors.white, selected ? 0.5 : 0.28) ?? tone;

    void px(num x, num y, num w, num h, Paint paint) {
      canvas.drawRect(
        Rect.fromLTWH(
          x.toDouble() * scale,
          y.toDouble() * scale,
          w.toDouble() * scale,
          h.toDouble() * scale,
        ),
        paint,
      );
    }

    switch (icon) {
      case _PixelHudIcon.map:
        px(1, 2, 5, 5, outline);
        px(2, 3, 3, 3, fill);
        px(10, 9, 5, 5, outline);
        px(11, 10, 3, 3, fill);
        px(5, 6, 6, 2, outline);
        px(6, 6, 4, 1, shade);
        px(8, 2, 2, 2, light);
        px(8, 11, 2, 2, light);
        break;
      case _PixelHudIcon.menu:
        px(3, 4, 10, 2, outline);
        px(4, 5, 8, 1, fill);
        px(3, 7, 10, 2, outline);
        px(4, 8, 8, 1, fill);
        px(3, 10, 10, 2, outline);
        px(4, 11, 8, 1, fill);
        break;
      case _PixelHudIcon.quest:
        px(2, 3, 12, 9, outline);
        px(3, 4, 10, 7, fill);
        px(4, 5, 8, 1, light);
        px(4, 8, 6, 1, shade);
        px(1, 4, 1, 5, outline);
        px(14, 4, 1, 5, outline);
        px(1, 2, 2, 2, gold);
        px(13, 2, 2, 2, gold);
        break;
      case _PixelHudIcon.desk:
        px(2, 6, 12, 4, outline);
        px(3, 7, 10, 2, fill);
        px(3, 10, 2, 4, outline);
        px(11, 10, 2, 4, outline);
        px(5, 4, 4, 2, light);
        px(10, 4, 2, 2, shade);
        break;
      case _PixelHudIcon.shop:
        px(2, 4, 12, 3, outline);
        px(3, 5, 10, 1, fill);
        px(3, 7, 10, 6, outline);
        px(4, 8, 8, 4, fill);
        px(5, 9, 2, 2, coin);
        px(10, 9, 1, 2, light);
        break;
      case _PixelHudIcon.bag:
        px(4, 3, 8, 3, outline);
        px(5, 4, 6, 1, fill);
        px(3, 6, 10, 8, outline);
        px(4, 7, 8, 6, fill);
        px(6, 8, 4, 1, light);
        px(7, 10, 2, 2, shade);
        break;
      case _PixelHudIcon.fire:
        px(7, 2, 2, 2, light);
        px(5, 4, 6, 8, outline);
        px(6, 5, 4, 6, fill);
        px(7, 7, 2, 3, ember);
        px(5, 12, 6, 2, shade);
        break;
      case _PixelHudIcon.theme:
        px(6, 2, 4, 4, outline);
        px(7, 3, 2, 2, fill);
        px(2, 6, 12, 2, outline);
        px(3, 7, 10, 1, light);
        px(4, 10, 8, 3, fill);
        px(5, 11, 6, 1, shade);
        break;
      case _PixelHudIcon.logout:
        px(2, 3, 5, 10, outline);
        px(3, 4, 3, 8, fill);
        px(8, 7, 6, 2, outline);
        px(10, 5, 4, 6, outline);
        px(11, 6, 3, 4, fill);
        px(13, 7, 2, 2, light);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PixelHudIconPainter oldDelegate) {
    return oldDelegate.icon != icon ||
        oldDelegate.tone != tone ||
        oldDelegate.selected != selected;
  }
}
