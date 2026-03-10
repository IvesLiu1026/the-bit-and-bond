part of '../game_shell_page.dart';

class _CampfireStatusBanner extends StatelessWidget {
  const _CampfireStatusBanner({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      tone: PixelTone.wood,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      cut: 8,
      borderWidth: 2,
      shadowDepth: 2,
      child: Text(
        subtitle,
        style: PixelTypography.style(
          color: AppColors.inkBrown,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          height: 1.05,
        ),
      ),
    );
  }
}

class _PixelMicStoneIcon extends StatelessWidget {
  const _PixelMicStoneIcon({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _PixelMicStonePainter(enabled: enabled)),
    );
  }
}

class _PixelMicStonePainter extends CustomPainter {
  const _PixelMicStonePainter({required this.enabled});

  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = enabled ? const Color(0xFF1976D2) : const Color(0xFF8B8B8B);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFF2A1F18);
    final gloss = Paint()
      ..color = enabled ? const Color(0xAA90CAF9) : const Color(0x66E0E0E0);

    final orb = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawRect(orb, bg);
    canvas.drawRect(orb, edge);
    canvas.drawRect(
      Rect.fromLTWH(
        3,
        3,
        math.max(2, size.width * 0.35),
        math.max(2, size.height * 0.35),
      ),
      gloss,
    );

    final mic = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..color = enabled ? const Color(0xFFEAF6FF) : const Color(0xFF3E2723);
    final centerX = size.width / 2;
    canvas.drawLine(Offset(centerX, 5), Offset(centerX, size.height - 6), mic);
    canvas.drawLine(
      Offset(centerX - 4, size.height - 6),
      Offset(centerX + 4, size.height - 6),
      mic,
    );
    if (!enabled) {
      final crack = Paint()
        ..strokeWidth = 1.8
        ..color = const Color(0xFF3E2723);
      canvas.drawLine(const Offset(4, 16), const Offset(16, 4), crack);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelMicStonePainter oldDelegate) {
    return oldDelegate.enabled != enabled;
  }
}
