part of 'chen_game.dart';

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
      baseRadius + 24,
      canvasSize.y - baseRadius - (compactHeight ? 54 : 92),
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
      ..color = const Color(0x66301E16).withValues(alpha: 0.75 * _alpha);
    final outerFill = Paint()
      ..color = const Color(0xFF5C4436).withValues(alpha: 0.95 * _alpha);
    final bezelFill = Paint()
      ..color = const Color(0xFF3B2A22).withValues(alpha: 0.96 * _alpha);
    final faceFill = Paint()
      ..color = const Color(0xFF8D7460).withValues(alpha: 0.94 * _alpha);
    final grooveFill = Paint()
      ..color = const Color(0x4D201711).withValues(alpha: _alpha);
    final highlightFill = Paint()
      ..color = const Color(0x66FFF5E6).withValues(alpha: 0.85 * _alpha);
    final knobShadow = Paint()
      ..color = const Color(0x6630231B).withValues(alpha: 0.85 * _alpha);
    final knobFill = Paint()
      ..color = AppColors.joystickGem.withValues(alpha: 0.96 * _alpha);
    final knobLight = Paint()
      ..color = AppColors.joystickGemLight.withValues(alpha: 0.96 * _alpha);
    final knobCore = Paint()
      ..color = const Color(0xFF0D4F92).withValues(alpha: _alpha);
    final idleDot = Paint()
      ..color = const Color(0x55FFF5E6).withValues(alpha: _alpha);

    final outerRect = Rect.fromCenter(
      center: center.translate(0, 4),
      width: baseRadius * 2.08,
      height: baseRadius * 2.08,
    );
    final bezelRect = Rect.fromCenter(
      center: center,
      width: baseRadius * 2,
      height: baseRadius * 2,
    );
    final faceRect = Rect.fromCenter(
      center: center,
      width: baseRadius * 1.66,
      height: baseRadius * 1.66,
    );
    final grooveThickness = math.max(10.0, baseRadius * 0.24);
    final horizontalGroove = Rect.fromCenter(
      center: center,
      width: faceRect.width - 24,
      height: grooveThickness,
    );
    final verticalGroove = Rect.fromCenter(
      center: center,
      width: grooveThickness,
      height: faceRect.height - 24,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(24)),
      outerShadow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bezelRect, const Radius.circular(22)),
      outerFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bezelRect.deflate(8), const Radius.circular(18)),
      bezelFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(faceRect, const Radius.circular(16)),
      faceFill,
    );
    canvas.drawRect(horizontalGroove, grooveFill);
    canvas.drawRect(verticalGroove, grooveFill);
    canvas.drawRect(
      Rect.fromLTWH(
        faceRect.left + 10,
        faceRect.top + 8,
        faceRect.width - 20,
        5,
      ),
      highlightFill,
    );

    final knobRect = Rect.fromCenter(
      center: knobCenter.translate(2, 3),
      width: knobRadius * 1.7,
      height: knobRadius * 1.7,
    );
    final knobFaceRect = Rect.fromCenter(
      center: knobCenter,
      width: knobRadius * 1.65,
      height: knobRadius * 1.65,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(knobRect, const Radius.circular(12)),
      knobShadow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(knobFaceRect, const Radius.circular(12)),
      knobFill,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        knobFaceRect.left + 6,
        knobFaceRect.top + 5,
        knobFaceRect.width - 12,
        5,
      ),
      knobLight,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        knobFaceRect.left + 8,
        knobFaceRect.top + knobFaceRect.height * 0.55,
        knobFaceRect.width - 16,
        knobFaceRect.height * 0.18,
      ),
      knobCore,
    );

    if (!_active) {
      canvas.drawCircle(center, 4.5, idleDot);
    }
  }
}
