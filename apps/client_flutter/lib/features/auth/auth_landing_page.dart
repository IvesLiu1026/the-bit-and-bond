import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AuthLandingPage extends StatelessWidget {
  const AuthLandingPage({
    super.key,
    required this.onMasterTap,
    required this.onHunterTap,
  });

  final VoidCallback onMasterTap;
  final VoidCallback onHunterTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AuthBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _WoodSignButton(
                      title: '我是公會長\nMaster',
                      subtitle: '建立公會、派發任務、審核獎勵',
                      icon: Icons.workspace_premium,
                      tiltDegrees: -2,
                      onTap: onMasterTap,
                    ),
                    _WoodSignButton(
                      title: '我是獵人\nHunter',
                      subtitle: '輸入邀請碼與 PIN 進入冒險',
                      icon: Icons.shield,
                      tiltDegrees: 2,
                      onTap: onHunterTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.grassBase,
      child: CustomPaint(painter: _NoiseGridPainter()),
    );
  }
}

class _NoiseGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tile = 48.0;
    final line = Paint()
      ..color = const Color(0x1A2E5D27)
      ..strokeWidth = 1;
    final speck = Paint()..color = const Color(0x1A355D24);
    for (double x = 0; x <= size.width; x += tile) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += tile) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    for (double y = tile / 2; y < size.height; y += tile) {
      for (double x = tile / 2; x < size.width; x += tile) {
        canvas.drawCircle(Offset(x, y), 1.4, speck);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WoodSignButton extends StatefulWidget {
  const _WoodSignButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tiltDegrees,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double tiltDegrees;
  final VoidCallback onTap;

  @override
  State<_WoodSignButton> createState() => _WoodSignButtonState();
}

class _WoodSignButtonState extends State<_WoodSignButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final lift = _hovered ? -2.0 : 0.0;
    final y = _pressed ? 4.0 : lift;
    final scale = _pressed ? 0.98 : 1.0;
    final tiltRadians = widget.tiltDegrees * math.pi / 180;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Transform.translate(
          offset: Offset(0, y),
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: tiltRadians,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: 320,
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8D6E63), Color(0xFF6D4C41)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF4E342E), width: 4),
                  boxShadow: _pressed
                      ? const []
                      : [
                          const BoxShadow(
                            color: AppColors.shadowHard,
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                          if (_hovered)
                            const BoxShadow(
                              color: Color(0x5539A657),
                              offset: Offset(0, 0),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 38, color: const Color(0xFFF7E8CF)),
                    const SizedBox(height: 10),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFDF3E2),
                        fontSize: 30,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE8D7B6),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
