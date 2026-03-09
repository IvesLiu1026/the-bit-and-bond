part of '../unified_auth_page.dart';

class _PixelAuthBackdrop extends StatelessWidget {
  const _PixelAuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PixelAuthBackdropPainter());
  }
}

class _PixelAuthBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..color = const Color(0xFF7DAF45);
    final skyAlt = Paint()..color = const Color(0xFF6D9C3C);
    final floorDark = Paint()..color = const Color(0xFF4E342E);
    final floorAlt = Paint()..color = const Color(0xFF5D4037);
    final wood = Paint()..color = const Color(0xFF6D4C41);
    final torch = Paint()..color = const Color(0xFFFFA726);
    final glow = Paint()..color = const Color(0x55FFD54F);

    canvas.drawRect(Offset.zero & size, sky);
    const tile = 48.0;
    for (var y = 0.0; y < size.height; y += tile) {
      for (var x = 0.0; x < size.width; x += tile) {
        final rect = Rect.fromLTWH(x, y, tile, tile);
        canvas.drawRect(
          rect,
          ((x ~/ tile) + (y ~/ tile)).isEven ? sky : skyAlt,
        );
      }
    }

    final wallHeight = size.height * 0.24;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, wallHeight), wood);
    for (var y = 0.0; y < wallHeight; y += 24) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0x553A221A)
          ..strokeWidth = 1.2,
      );
    }

    final floorTop = size.height * 0.72;
    for (var y = floorTop; y < size.height; y += 56) {
      for (var x = 0.0; x < size.width; x += 56) {
        final rect = Rect.fromLTWH(x, y, 56, 56);
        canvas.drawRect(
          rect,
          ((x ~/ 56) + (y ~/ 56)).isEven ? floorDark : floorAlt,
        );
      }
    }

    final bannerRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.66),
      width: size.width * 0.44,
      height: 96,
    );
    canvas.drawRect(
      bannerRect.inflate(8),
      Paint()..color = const Color(0xFFD4AF37),
    );
    canvas.drawRect(bannerRect, Paint()..color = const Color(0xFFC5372F));

    for (final dx in <double>[size.width * 0.18, size.width * 0.82]) {
      canvas.drawCircle(Offset(dx, wallHeight - 18), 22, glow);
      canvas.drawCircle(Offset(dx, wallHeight - 18), 11, torch);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(dx, wallHeight - 2),
          width: 7,
          height: 28,
        ),
        Paint()..color = const Color(0xFF4E342E),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PixelTavernCrest extends StatelessWidget {
  const _PixelTavernCrest();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF4E342E),
          border: Border.all(color: const Color(0xFF2F1E18), width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x663E2723),
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'BB',
            style: TextStyle(
              color: Color(0xFFFDF1D8),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelFlavorStrip extends StatelessWidget {
  const _PixelFlavorStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF5D4037),
        border: Border.all(color: const Color(0xFF2F1E18), width: 3),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFF9E5C4),
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _PixelFieldFrame extends StatelessWidget {
  const _PixelFieldFrame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4E342E),
                border: Border.all(color: const Color(0xFF2F1E18), width: 2),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFFDF1D8),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
