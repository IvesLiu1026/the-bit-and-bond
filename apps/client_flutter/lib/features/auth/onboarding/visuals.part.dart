part of '../immersive_onboarding_page.dart';

class _PixelWoodBackdrop extends StatelessWidget {
  const _PixelWoodBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PixelWoodBackdropPainter());
  }
}

class _PixelWoodBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFF2D180F);
    canvas.drawRect(Offset.zero & size, base);

    const plankHeight = 72.0;
    final plankColors = <Color>[
      const Color(0xFF513224),
      const Color(0xFF623A27),
      const Color(0xFF4A2C20),
      const Color(0xFF6A422C),
    ];

    for (var y = 0.0; y < size.height + plankHeight; y += plankHeight) {
      final color = plankColors[(y ~/ plankHeight) % plankColors.length];
      final rect = Rect.fromLTWH(0, y, size.width, plankHeight - 2);
      canvas.drawRect(rect, Paint()..color = color);

      for (var x = 0.0; x < size.width + 48; x += 48) {
        final grainPaint = Paint()
          ..color = const Color(0x33F3D7A0)
          ..strokeWidth = 2;
        canvas.drawLine(
          Offset(x, y + plankHeight * 0.28),
          Offset(x + 16, y + plankHeight * 0.28),
          grainPaint,
        );
        canvas.drawLine(
          Offset(x + 10, y + plankHeight * 0.65),
          Offset(x + 28, y + plankHeight * 0.65),
          grainPaint,
        );
      }
    }

    final seamPaint = Paint()..color = const Color(0xFF25130D);
    for (var y = plankHeight; y < size.height; y += plankHeight) {
      canvas.drawRect(Rect.fromLTWH(0, y - 2, size.width, 4), seamPaint);
    }

    final warmGlow = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x44F6C462), Color(0x00F6C462)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.75, size.height * 0.24),
              radius: 240,
            ),
          );
    canvas.drawRect(Offset.zero & size, warmGlow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PixelLogoPlaque extends StatelessWidget {
  const _PixelLogoPlaque();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 244,
      child: PixelPanel(
        padding: const EdgeInsets.all(12),
        tone: PixelTone.parchment,
        cut: 16,
        shadowDepth: 8,
        child: SizedBox(
          width: 220,
          height: 220,
          child: PixelPanel(
            tone: PixelTone.wood,
            padding: const EdgeInsets.all(6),
            cut: 12,
            shadowDepth: 0,
            showShadow: false,
            faceColor: const Color(0xFFF6ECCF),
            child: Image.asset(
              'assets/branding/the_bit_and_bond_icon_master.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Text(
                    'B&B',
                    style: TextStyle(
                      color: Color(0xFF5A3725),
                      fontWeight: FontWeight.w900,
                      fontSize: 44,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingPrompt extends StatelessWidget {
  const _BlinkingPrompt();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return PixelPanel(
      tone: PixelTone.gold,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      cut: 12,
      shadowDepth: 6,
      faceColor: const Color(0xFF3A2319),
      edgeColor: const Color(0xFFD6A85B),
      child: Text(
        strings.tr(zh: '[ 點擊畫面進入空間 ]', en: '[ Tap to Enter Space ]'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFCE7BE),
          fontWeight: FontWeight.w900,
          fontSize: 17,
          height: 1,
        ),
      ),
    );
  }
}

class _NarrationPanel extends StatelessWidget {
  const _NarrationPanel({
    required this.badge,
    required this.title,
    required this.body,
    this.dense = false,
  });

  final String badge;
  final String title;
  final String body;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: EdgeInsets.all(dense ? 14 : 18),
      cut: dense ? 10 : 14,
      shadowDepth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelTag(label: badge, tone: PixelTone.wood, compact: dense),
          SizedBox(height: dense ? 10 : 12),
          Text(
            title,
            style: TextStyle(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w900,
              fontSize: dense ? 22 : 28,
              height: 1.05,
            ),
          ),
          SizedBox(height: dense ? 8 : 10),
          Text(
            body,
            style: TextStyle(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 13.5 : 15.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
