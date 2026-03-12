part of '../game_shell_page.dart';

class _HunterRadarPanel extends StatefulWidget {
  const _HunterRadarPanel({required this.statsState, required this.stats});

  final AsyncValue<HunterStatsSummary?> statsState;
  final HunterStatsSummary? stats;

  @override
  State<_HunterRadarPanel> createState() => _HunterRadarPanelState();
}

class _HunterRadarPanelState extends State<_HunterRadarPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _strTween;
  late Animation<double> _intTween;
  late Animation<double> _agiTween;
  late Animation<double> _chaTween;
  late Animation<double> _vitTween;
  List<double> _display = const [0, 0, 0, 0, 0];
  List<double> _target = const [0, 0, 0, 0, 0];
  int _maxScale = 100;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addListener(() {
          if (!mounted) {
            return;
          }
          setState(() {
            _display = [
              _strTween.value,
              _intTween.value,
              _agiTween.value,
              _chaTween.value,
              _vitTween.value,
            ];
          });
        });
    _resetTweens(animate: false);
  }

  @override
  void didUpdateWidget(covariant _HunterRadarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _toValues(widget.stats);
    final changed = next.asMap().entries.any(
      (entry) => entry.value != _target[entry.key],
    );
    if (changed) {
      _resetTweens(animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<double> _toValues(HunterStatsSummary? stats) {
    final raw = stats?.radarValues ?? const [0, 0, 0, 0, 0];
    return raw.map((value) => value.toDouble()).toList(growable: false);
  }

  void _resetTweens({required bool animate}) {
    _target = _toValues(widget.stats);
    _maxScale = math.max<int>(
      100,
      _target.fold<int>(0, (acc, value) => math.max(acc, value.round())),
    );
    final begin = List<double>.from(_display);
    if (!animate) {
      _display = List<double>.from(_target);
    }
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _strTween = Tween<double>(begin: begin[0], end: _target[0]).animate(curve);
    _intTween = Tween<double>(begin: begin[1], end: _target[1]).animate(curve);
    _agiTween = Tween<double>(begin: begin[2], end: _target[2]).animate(curve);
    _chaTween = Tween<double>(begin: begin[3], end: _target[3]).animate(curve);
    _vitTween = Tween<double>(begin: begin[4], end: _target[4]).animate(curve);
    if (animate) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F2A),
        border: Border.all(color: const Color(0xFF8B6F54), width: 2.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0xB3261811),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.tr(zh: '能力分析', en: 'Stat Radar'),
            style: const TextStyle(
              color: Color(0xFFF8EBD2),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.statsState.isLoading)
            const SizedBox(
              height: 180,
              child: Center(child: _PixelLoadingBar()),
            )
          else
            SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _HunterRadarPainter(
                  animatedValues: _display,
                  maxScale: _maxScale,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatGemChip(
                icon: const _PixelStatIcon(
                  category: QuestStatCategory.strength,
                  size: 14,
                  withFrame: false,
                ),
                label: 'STR ${widget.stats?.strXp ?? 0}',
                color: _statCategoryColor(QuestStatCategory.strength),
              ),
              _StatGemChip(
                icon: const _PixelStatIcon(
                  category: QuestStatCategory.intelligence,
                  size: 14,
                  withFrame: false,
                ),
                label: 'INT ${widget.stats?.intXp ?? 0}',
                color: _statCategoryColor(QuestStatCategory.intelligence),
              ),
              _StatGemChip(
                icon: const _PixelStatIcon(
                  category: QuestStatCategory.agility,
                  size: 14,
                  withFrame: false,
                ),
                label: 'AGI ${widget.stats?.agiXp ?? 0}',
                color: _statCategoryColor(QuestStatCategory.agility),
              ),
              _StatGemChip(
                icon: const _PixelStatIcon(
                  category: QuestStatCategory.charisma,
                  size: 14,
                  withFrame: false,
                ),
                label: 'CHA ${widget.stats?.chaXp ?? 0}',
                color: _statCategoryColor(QuestStatCategory.charisma),
              ),
              _StatGemChip(
                icon: const _PixelStatIcon(
                  category: QuestStatCategory.vitality,
                  size: 14,
                  withFrame: false,
                ),
                label: 'VIT ${widget.stats?.vitXp ?? 0}',
                color: _statCategoryColor(QuestStatCategory.vitality),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HunterRadarPainter extends CustomPainter {
  const _HunterRadarPainter({
    required this.animatedValues,
    required this.maxScale,
  });

  final List<double> animatedValues;
  final int maxScale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final maxValue = math.max(100, maxScale).toDouble();

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFF5B4A6A);
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xFF78658D);

    List<Offset> points(double factor) {
      return List<Offset>.generate(5, (index) {
        final angle = (-math.pi / 2) + (index * (math.pi * 2 / 5));
        return Offset(
          center.dx + (math.cos(angle) * radius * factor),
          center.dy + (math.sin(angle) * radius * factor),
        );
      });
    }

    for (var level = 1; level <= 4; level++) {
      final factor = level / 4;
      final ring = points(factor);
      final path = Path()..addPolygon(ring, true);
      canvas.drawPath(path, gridPaint);
      final scale = ((maxValue * factor).round()).toString();
      final scaleTp = TextPainter(
        text: TextSpan(
          text: scale,
          style: const TextStyle(
            color: Color(0xFFE7D7B8),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final scaleDx = (center.dx - radius - scaleTp.width - 8).clamp(
        2.0,
        size.width - scaleTp.width - 2.0,
      );
      final scaleDy = (center.dy + 2 - (radius * factor)).clamp(
        2.0,
        size.height - scaleTp.height - 2.0,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          scaleDx - 2,
          scaleDy - 1,
          scaleTp.width + 4,
          scaleTp.height + 2,
        ),
        Paint()..color = const Color(0xA8241923),
      );
      scaleTp.paint(canvas, Offset(scaleDx, scaleDy));
    }

    final outer = points(1);
    for (final point in outer) {
      canvas.drawLine(center, point, axisPaint);
    }

    final dataPoints = List<Offset>.generate(5, (index) {
      final value = index < animatedValues.length ? animatedValues[index] : 0.0;
      final ratio = (value / maxValue).clamp(0.0, 1.0);
      final angle = (-math.pi / 2) + (index * (math.pi * 2 / 5));
      return Offset(
        center.dx + (math.cos(angle) * radius * ratio),
        center.dy + (math.sin(angle) * radius * ratio),
      );
    });
    final dataPath = Path()..addPolygon(dataPoints, true);
    canvas.drawPath(dataPath, Paint()..color = const Color(0xAA64B5F6));
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFF90CAF9),
    );

    const labels = ['STR', 'INT', 'AGI', 'CHA', 'VIT'];
    for (var index = 0; index < labels.length; index++) {
      final anchor = outer[index];
      final tp = TextPainter(
        text: TextSpan(
          text: labels[index],
          style: const TextStyle(
            color: Color(0xFFF4ECE1),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (anchor.dx - (tp.width / 2)).clamp(
        2.0,
        size.width - tp.width - 2.0,
      );
      final dy = (anchor.dy - (tp.height / 2)).clamp(
        2.0,
        size.height - tp.height - 2.0,
      );
      canvas.drawRect(
        Rect.fromLTWH(dx - 3, dy - 1, tp.width + 6, tp.height + 2),
        Paint()..color = const Color(0x8A241923),
      );
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _HunterRadarPainter oldDelegate) {
    if (oldDelegate.maxScale != maxScale) {
      return true;
    }
    if (oldDelegate.animatedValues.length != animatedValues.length) {
      return true;
    }
    for (var i = 0; i < animatedValues.length; i++) {
      if (oldDelegate.animatedValues[i] != animatedValues[i]) {
        return true;
      }
    }
    return false;
  }
}
