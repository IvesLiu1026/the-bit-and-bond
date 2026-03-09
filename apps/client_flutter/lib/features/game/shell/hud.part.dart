part of '../game_shell_page.dart';

class _TitleBadge extends StatefulWidget {
  const _TitleBadge({required this.lowFxMode, required this.compact});

  final bool lowFxMode;
  final bool compact;

  @override
  State<_TitleBadge> createState() => _TitleBadgeState();
}

class _TitleBadgeState extends State<_TitleBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final math.Random _flickerRandom;
  late double _leftFrom;
  late double _leftTo;
  late double _rightFrom;
  late double _rightTo;

  @override
  void initState() {
    super.initState();
    _flickerRandom = math.Random();
    _leftFrom = _nextFlickerValue();
    _rightFrom = _nextFlickerValue();
    _leftTo = _nextFlickerValue();
    _rightTo = _nextFlickerValue();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && !widget.lowFxMode) {
            _leftFrom = _leftTo;
            _rightFrom = _rightTo;
            _leftTo = _nextFlickerValue();
            _rightTo = _nextFlickerValue();
            _controller.forward(from: 0);
          }
        });
    if (!widget.lowFxMode) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TitleBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lowFxMode == widget.lowFxMode) {
      return;
    }
    if (widget.lowFxMode) {
      _controller.stop();
      return;
    }
    _leftFrom = _nextFlickerValue();
    _rightFrom = _nextFlickerValue();
    _leftTo = _nextFlickerValue();
    _rightTo = _nextFlickerValue();
    _controller.forward(from: 0);
  }

  double _nextFlickerValue() {
    return 0.6 + (_flickerRandom.nextDouble() * 0.4);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lowFxMode) {
      return _buildBadge(0.82, 0.82, lowFxMode: true);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.bounceIn.transform(_controller.value);
        final leftFlicker = _leftFrom + ((_leftTo - _leftFrom) * t);
        final rightFlicker = _rightFrom + ((_rightTo - _rightFrom) * t);
        return _buildBadge(leftFlicker, rightFlicker, lowFxMode: false);
      },
    );
  }

  Widget _buildBadge(
    double leftFlicker,
    double rightFlicker, {
    required bool lowFxMode,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 10 : 16,
        vertical: widget.compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2E6C8), Color(0xFFE6D4AE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF745238), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF402B1E),
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PixelTorch(flicker: leftFlicker, lowFxMode: lowFxMode),
          SizedBox(width: widget.compact ? 6 : 10),
          const _PixelLabelGlyph(glyph: 'BRD'),
          SizedBox(width: widget.compact ? 5 : 8),
          Text(
            '生活任務板',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: widget.compact ? 16 : 24,
              color: AppColors.inkBrown,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(width: widget.compact ? 6 : 10),
          _PixelTorch(flicker: rightFlicker, lowFxMode: lowFxMode),
        ],
      ),
    );
  }
}

class _PixelTorch extends StatelessWidget {
  const _PixelTorch({required this.flicker, required this.lowFxMode});

  final double flicker;
  final bool lowFxMode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 32,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 7,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF6D4C41),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: const Color(0xFF3E2723), width: 1.2),
            ),
          ),
          Positioned(
            top: 0,
            child: Opacity(
              opacity: lowFxMode ? 0.8 : flicker.clamp(0.0, 1.0),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFF59D), Color(0xFFFFA000)],
                  ),
                  boxShadow: lowFxMode
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x55FFB300),
                            blurRadius: 8,
                            spreadRadius: 2,
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

class _OverlayPanel extends StatelessWidget {
  const _OverlayPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: const EdgeInsets.all(12),
      cut: 14,
      shadowDepth: 4,
      child: child,
    );
  }
}

class _TopHudBanner extends StatelessWidget {
  const _TopHudBanner({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      cut: compact ? 12 : 14,
      shadowDepth: 4,
      child: Row(
        children: [
          SizedBox(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            child: PixelPanel(
              tone: PixelTone.blue,
              cut: 10,
              shadowDepth: 0,
              showShadow: false,
              faceColor: accentColor.withValues(alpha: 0.16),
              edgeColor: AppColors.woodFrame,
              padding: const EdgeInsets.all(6),
              child: CustomPaint(
                painter: _PixelHudIconPainter(
                  icon: _PixelHudIcon.map,
                  tone: accentColor,
                  selected: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkBrown,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 14 : 16,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkBrown.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 10.5 : 11.5,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
