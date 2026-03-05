part of 'chen_game.dart';

class _FloatingJoystickOverlay extends PositionComponent {
  _FloatingJoystickOverlay({required this.baseRadius, required this.knobRadius})
    : super(position: Vector2.zero(), anchor: Anchor.topLeft, priority: 9000);

  final double baseRadius;
  final double knobRadius;

  bool _active = false;
  double _alpha = 0;
  double _targetAlpha = 0;
  final Vector2 _center = Vector2.zero();
  final Vector2 _knob = Vector2.zero();
  final Vector2 _delta = Vector2.zero();

  void resizeTo(Vector2 canvasSize) {
    size = canvasSize;
  }

  void activate(Vector2 rawPosition) {
    _active = true;
    _targetAlpha = 1;
    final clamped = _clampToCanvas(rawPosition);
    _center.setFrom(clamped);
    _knob.setFrom(clamped);
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
    _targetAlpha = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    const fadeDurationSeconds = 0.12;
    final step = (dt / fadeDurationSeconds).clamp(0.0, 1.0);
    _alpha += (_targetAlpha - _alpha) * step;
    if (!_active && _alpha < 0.01) {
      _alpha = 0;
      _center.setZero();
      _knob.setZero();
      _delta.setZero();
    }
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
    final dropShadow = Paint()
      ..color = const Color(0x5A1A100C).withValues(alpha: 0.35 * _alpha);
    final outer = Paint()
      ..color = AppColors.joystickBase.withValues(alpha: 0.72 * _alpha);
    final cavity = Paint()
      ..color = const Color(0xA62A1A14).withValues(alpha: 0.65 * _alpha);
    final innerShadow = Paint()
      ..shader = ui.Gradient.radial(center, baseRadius - 6, const [
        Color(0x00000000),
        Color(0x55000000),
      ]);
    final baseRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0x996D4C41).withValues(alpha: 0.8 * _alpha);

    final knobShadow = Paint()
      ..color = const Color(0x880D315A).withValues(alpha: 0.8 * _alpha);
    final knobGem = Paint()
      ..shader =
          ui.Gradient.radial(knobCenter.translate(-5, -6), knobRadius - 1.5, [
            AppColors.joystickGemLight.withValues(alpha: 0.96 * _alpha),
            AppColors.joystickGem.withValues(alpha: 0.92 * _alpha),
          ]);
    final knobRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xAAEAF4FF).withValues(alpha: _alpha);
    final knobHighlight = Paint()
      ..color = const Color(0xCCFFFFFF).withValues(alpha: _alpha);

    canvas.drawCircle(center.translate(0, 5), baseRadius - 1, dropShadow);
    canvas.drawCircle(center, baseRadius, outer);
    canvas.drawCircle(center, baseRadius - 6, cavity);
    canvas.drawCircle(center, baseRadius - 6, innerShadow);
    canvas.drawCircle(center, baseRadius - 9, baseRing);

    canvas.drawCircle(
      knobCenter.translate(2.5, 2.5),
      knobRadius - 1,
      knobShadow,
    );
    canvas.drawCircle(knobCenter, knobRadius, knobGem);
    canvas.drawCircle(knobCenter, knobRadius - 2.3, knobRing);
    canvas.drawCircle(knobCenter.translate(-6.5, -7), 4.3, knobHighlight);
  }
}
