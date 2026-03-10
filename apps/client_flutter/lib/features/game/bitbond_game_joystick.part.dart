part of 'bitbond_game.dart';

class _FloatingJoystickOverlay extends PositionComponent {
  _FloatingJoystickOverlay({required this.baseRadius, required this.knobRadius})
    : super(position: Vector2.zero(), anchor: Anchor.topLeft, priority: 9000);

  final double baseRadius;
  final double knobRadius;

  bool _active = false;
  double _alpha = 0.92;
  double _targetAlpha = 0.92;
  final Vector2 _center = Vector2.zero();
  final Vector2 _knob = Vector2.zero();
  final Vector2 _delta = Vector2.zero();

  bool get isActive => _active;

  void resizeTo(Vector2 canvasSize) {
    size = canvasSize;
    final compactHeight = canvasSize.y < 560;
    final center = Vector2(
      baseRadius + 18,
      canvasSize.y - baseRadius - (compactHeight ? 42 : 78),
    );
    _center.setFrom(_clampToCanvas(center));
    if (!_active) {
      _knob.setFrom(_center);
      _delta.setZero();
    }
  }

  bool containsTouch(Vector2 rawPosition) {
    if (size.x <= 0 || size.y <= 0) {
      return false;
    }
    final probe = rawPosition - _center;
    final hitRadius = baseRadius + 28;
    return probe.length2 <= hitRadius * hitRadius;
  }

  void activate() {
    _active = true;
    _targetAlpha = 1.0;
    _knob.setFrom(_center);
    _delta.setZero();
  }

  void updateTouch(Vector2 rawPosition, Vector2 outInput) {
    if (!_active) {
      outInput.setZero();
      return;
    }

    _delta
      ..setFrom(rawPosition)
      ..sub(_center);

    final limit = baseRadius;
    final limit2 = limit * limit;
    if (_delta.length2 > limit2) {
      _delta.scaleTo(limit);
    }

    _knob
      ..setFrom(_center)
      ..add(_delta);

    outInput
      ..setFrom(_delta)
      ..scale(1 / limit);
  }

  void deactivate() {
    _active = false;
    _targetAlpha = 0.92;
    _knob.setFrom(_center);
    _delta.setZero();
  }

  @override
  void update(double dt) {
    super.update(dt);
    const fadeDurationSeconds = 0.12;
    final step = (dt / fadeDurationSeconds).clamp(0.0, 1.0);
    _alpha += (_targetAlpha - _alpha) * step;
  }

  Vector2 _clampToCanvas(Vector2 rawPosition) {
    final x = _clampAxis(rawPosition.x, size.x);
    final y = _clampAxis(rawPosition.y, size.y);
    return Vector2(x, y);
  }

  double _clampAxis(double value, double extent) {
    if (extent <= 0) {
      return value;
    }
    final min = baseRadius + 8;
    final max = extent - baseRadius - 8;
    if (max <= min) {
      return extent / 2;
    }
    return value.clamp(min, max).toDouble();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_alpha <= 0.01) {
      return;
    }

    final center = Offset(_center.x, _center.y);
    final knobCenter = Offset(_knob.x, _knob.y);
    final outerShadow = Paint()
      ..color = const Color(0x55301E16).withValues(alpha: 0.64 * _alpha);
    final baseEdge = Paint()
      ..color = const Color(0xFF2F1D16).withValues(alpha: 0.97 * _alpha);
    final baseFill = Paint()
      ..color = const Color(0xFF6D4D3A).withValues(alpha: 0.96 * _alpha);
    final innerFill = Paint()
      ..color = const Color(0xFFC7A37A).withValues(alpha: 0.95 * _alpha);
    final innerShade = Paint()
      ..color = const Color(0x55372218).withValues(alpha: 0.84 * _alpha);
    final glyphPaint = Paint()
      ..color = const Color(0xFFF3DFC0).withValues(alpha: 0.88 * _alpha);
    final knobShadow = Paint()
      ..color = const Color(0x6630231B).withValues(alpha: 0.76 * _alpha);
    final knobEdge = Paint()
      ..color = const Color(0xFF2B1A12).withValues(alpha: 0.98 * _alpha);
    final knobFill = Paint()
      ..color = const Color(0xFF8A6548).withValues(alpha: 0.98 * _alpha);
    final knobHighlight = Paint()
      ..color = const Color(0x66E7C39E).withValues(alpha: 0.9 * _alpha);
    final idleDot = Paint()
      ..color = const Color(0xAAEFD7B3).withValues(alpha: _alpha);

    final baseShadowPath = _pixelPadPath(
      center.translate(0, 4),
      baseRadius + 5,
      cut: 14,
    );
    final baseEdgePath = _pixelPadPath(center, baseRadius + 2.5, cut: 14);
    final baseFillPath = _pixelPadPath(center, baseRadius - 1.5, cut: 12);
    final innerPadPath = _pixelPadPath(center, baseRadius - 9, cut: 10);

    canvas.drawPath(baseShadowPath, outerShadow);
    canvas.drawPath(baseEdgePath, baseEdge);
    canvas.drawPath(baseFillPath, baseFill);
    canvas.drawPath(innerPadPath, innerFill);

    final dPadHalf = baseRadius * 0.26;
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: dPadHalf * 0.72,
        height: dPadHalf * 2,
      ),
      innerShade,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: dPadHalf * 2,
        height: dPadHalf * 0.72,
      ),
      innerShade,
    );

    for (final offset in const [
      Offset(0, -1),
      Offset(1, 0),
      Offset(0, 1),
      Offset(-1, 0),
    ]) {
      final markerCenter =
          center +
          Offset(
            offset.dx * (baseRadius * 0.48),
            offset.dy * (baseRadius * 0.48),
          );
      canvas.drawRect(
        Rect.fromCenter(center: markerCenter, width: 5, height: 5),
        glyphPaint,
      );
    }

    final knobShadowPath = _pixelPadPath(
      knobCenter.translate(1, 2),
      knobRadius + 3,
      cut: 10,
    );
    final knobEdgePath = _pixelPadPath(knobCenter, knobRadius + 2, cut: 10);
    final knobFillPath = _pixelPadPath(knobCenter, knobRadius - 0.5, cut: 8);
    canvas.drawPath(knobShadowPath, knobShadow);
    canvas.drawPath(knobEdgePath, knobEdge);
    canvas.drawPath(knobFillPath, knobFill);
    canvas.drawRect(
      Rect.fromCenter(
        center: knobCenter.translate(-2, -2),
        width: knobRadius * 0.9,
        height: knobRadius * 0.55,
      ),
      knobHighlight,
    );

    if (!_active) {
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 5, height: 5),
        idleDot,
      );
    }
  }

  Path _pixelPadPath(Offset center, double radius, {required double cut}) {
    final left = center.dx - radius;
    final top = center.dy - radius;
    final right = center.dx + radius;
    final bottom = center.dy + radius;
    final clippedCut = math.min(cut, radius * 0.7);
    final step = math.max(2.0, (clippedCut / 3).floorToDouble());
    final depth = step * 3;
    return Path()
      ..moveTo(left + depth, top)
      ..lineTo(right - depth, top)
      ..lineTo(right - depth, top + step)
      ..lineTo(right - (step * 2), top + step)
      ..lineTo(right - (step * 2), top + (step * 2))
      ..lineTo(right - step, top + (step * 2))
      ..lineTo(right - step, top + depth)
      ..lineTo(right, top + depth)
      ..lineTo(right, bottom - depth)
      ..lineTo(right - step, bottom - depth)
      ..lineTo(right - step, bottom - (step * 2))
      ..lineTo(right - (step * 2), bottom - (step * 2))
      ..lineTo(right - (step * 2), bottom - step)
      ..lineTo(right - depth, bottom - step)
      ..lineTo(right - depth, bottom)
      ..lineTo(left + depth, bottom)
      ..lineTo(left + depth, bottom - step)
      ..lineTo(left + (step * 2), bottom - step)
      ..lineTo(left + (step * 2), bottom - (step * 2))
      ..lineTo(left + step, bottom - (step * 2))
      ..lineTo(left + step, bottom - depth)
      ..lineTo(left, bottom - depth)
      ..lineTo(left, top + depth)
      ..lineTo(left + step, top + depth)
      ..lineTo(left + step, top + (step * 2))
      ..lineTo(left + (step * 2), top + (step * 2))
      ..lineTo(left + (step * 2), top + step)
      ..lineTo(left + depth, top + step)
      ..close();
  }
}
