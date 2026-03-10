part of 'bitbond_game.dart';

class _HeroCharacterComponent extends PositionComponent {
  _HeroCharacterComponent({
    required super.position,
    required AvatarAppearance appearance,
    required void Function(Vector2 position, AvatarFacing facing, bool leftFoot)
    onFootprintSpawn,
  }) : _appearance = appearance,
       _onFootprintSpawn = onFootprintSpawn,
       super(size: Vector2.all(96), anchor: Anchor.center, priority: 200);

  static const double _frameStep = 0.1;
  static const List<int> _walkColumns = <int>[1, 2, 3, 4];

  final double radius = 26;
  AvatarAppearance _appearance;
  final void Function(Vector2 position, AvatarFacing facing, bool leftFoot)
  _onFootprintSpawn;
  _HeroFacing _facing = _HeroFacing.down;
  bool _controlled = false;
  bool _walking = false;
  bool _hasRemoteTarget = false;
  double _connectionStrength = 0;
  bool _energizeLeftSocket = false;
  bool _energizeRightPlug = false;
  _HeroFacing? _forcedVisualFacing;
  final Vector2 _remoteTarget = Vector2.zero();
  static const double _remoteLerpSpeed = 14.0;
  double _animationTick = 0;
  int _walkFrameIndex = 0;
  bool _nextFootLeft = true;

  @override
  void render(Canvas canvas) {
    if (_connectionStrength > 0) {
      final aura = Paint()
        ..color = const Color(
          0xFF8BE8FF,
        ).withValues(alpha: 0.14 + (_connectionStrength * 0.18));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x * 0.5, size.y * 0.52),
          width: size.x * (0.52 + (_connectionStrength * 0.12)),
          height: size.y * (0.58 + (_connectionStrength * 0.12)),
        ),
        aura,
      );
    }

    final shadow = Paint()..color = const Color(0x5520100A);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * 0.5, size.y * 0.83),
        width: size.x * 0.42,
        height: size.y * 0.16,
      ),
      shadow,
    );

    canvas.save();
    final pixelSize = size.x / (AvatarPixelRenderer.logicalSize + 2);
    final renderExtent = AvatarPixelRenderer.logicalSize * pixelSize;
    canvas.translate((size.x - renderExtent) * 0.5, size.y * 0.02);
    AvatarPixelRenderer.paint(
      canvas,
      appearance: _appearance,
      facing: _avatarFacing,
      walkFrame: _walking ? _walkFrameIndex : 0,
      pixelSize: pixelSize,
      connectionStrength: _connectionStrength,
      energizeLeftSocket: _energizeLeftSocket,
      energizeRightPlug: _energizeRightPlug,
    );
    canvas.restore();
  }

  void setAppearance(AvatarAppearance appearance) {
    _appearance = appearance;
  }

  void setMotion(Vector2 velocity, {required bool moving}) {
    if (!velocity.isZero()) {
      _updateFacing(velocity);
    }
    if (_walking != moving && !moving) {
      _animationTick = 0;
      _walkFrameIndex = 0;
      _nextFootLeft = true;
    }
    _walking = moving;
  }

  bool get isWalking => _walking;

  void setConnectionVisual({
    required double strength,
    required bool energizeLeftSocket,
    required bool energizeRightPlug,
    _HeroFacing? forcedFacing,
  }) {
    _connectionStrength = strength.clamp(0.0, 1.0).toDouble();
    _energizeLeftSocket = energizeLeftSocket;
    _energizeRightPlug = energizeRightPlug;
    _forcedVisualFacing = forcedFacing;
  }

  void clearConnectionVisual() {
    _connectionStrength = 0;
    _energizeLeftSocket = false;
    _energizeRightPlug = false;
    _forcedVisualFacing = null;
  }

  String get facingWire {
    return switch (_facing) {
      _HeroFacing.down => 'down',
      _HeroFacing.up => 'up',
      _HeroFacing.left => 'left',
      _HeroFacing.right => 'right',
    };
  }

  void applyNetworkPose(
    HunterRealtimePose pose, {
    required bool snapToTarget,
    required Vector2 worldSize,
    required double minYBound,
  }) {
    _facing = _fromWireFacing(pose.facing);
    if (_walking != pose.moving && !pose.moving) {
      _animationTick = 0;
      _walkFrameIndex = 0;
      _nextFootLeft = true;
    }
    _walking = pose.moving;
    final minX = radius;
    final maxX = math.max(minX, worldSize.x - radius);
    final minY = minYBound + radius + 6;
    final maxY = math.max(minY, worldSize.y - radius);

    _remoteTarget.setValues(
      pose.x.clamp(minX, maxX).toDouble(),
      pose.y.clamp(minY, maxY).toDouble(),
    );
    _hasRemoteTarget = true;
    if (snapToTarget) {
      position.setFrom(_remoteTarget);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _advanceAnimation(dt);

    if (_controlled || !_hasRemoteTarget) {
      return;
    }

    final blend = (dt * _remoteLerpSpeed).clamp(0.0, 1.0);
    position.x += (_remoteTarget.x - position.x) * blend;
    position.y += (_remoteTarget.y - position.y) * blend;

    final dx = (_remoteTarget.x - position.x).abs();
    final dy = (_remoteTarget.y - position.y).abs();
    if (dx < 0.2 && dy < 0.2) {
      position.setFrom(_remoteTarget);
    }
  }

  void setControlled(bool value) {
    if (_controlled == value) {
      return;
    }
    _controlled = value;
    if (value) {
      _hasRemoteTarget = false;
    }
    scale = value ? Vector2.all(1.0) : Vector2.all(0.92);
  }

  void _advanceAnimation(double dt) {
    if (!_walking) {
      _animationTick = 0;
      _walkFrameIndex = 0;
      _nextFootLeft = true;
      return;
    }

    _animationTick += dt;
    while (_animationTick >= _frameStep) {
      _animationTick -= _frameStep;
      _walkFrameIndex = (_walkFrameIndex + 1) % _walkColumns.length;
      if (_walkFrameIndex.isEven) {
        _emitFootprint();
      }
    }
  }

  void _emitFootprint() {
    final leftFoot = _nextFootLeft;
    _nextFootLeft = !_nextFootLeft;
    final offset = switch (_avatarFacing) {
      AvatarFacing.down => Vector2(leftFoot ? -10 : 10, radius + 7),
      AvatarFacing.up => Vector2(leftFoot ? -10 : 10, radius + 6),
      AvatarFacing.left => Vector2(4, leftFoot ? (radius + 2) : (radius + 8)),
      AvatarFacing.right => Vector2(-4, leftFoot ? (radius + 2) : (radius + 8)),
    };
    _onFootprintSpawn(position + offset, _avatarFacing, leftFoot);
  }

  void _updateFacing(Vector2 velocity) {
    if (velocity.y.abs() >= velocity.x.abs()) {
      _facing = velocity.y < 0 ? _HeroFacing.up : _HeroFacing.down;
      return;
    }
    _facing = velocity.x < 0 ? _HeroFacing.left : _HeroFacing.right;
  }

  _HeroFacing _fromWireFacing(String facing) {
    return switch (facing) {
      'up' => _HeroFacing.up,
      'left' => _HeroFacing.left,
      'right' => _HeroFacing.right,
      _ => _HeroFacing.down,
    };
  }

  AvatarFacing get _avatarFacing {
    final facing = _forcedVisualFacing ?? _facing;
    return switch (facing) {
      _HeroFacing.down => AvatarFacing.down,
      _HeroFacing.up => AvatarFacing.up,
      _HeroFacing.left => AvatarFacing.left,
      _HeroFacing.right => AvatarFacing.right,
    };
  }
}

class _BibonFootprintComponent extends PositionComponent {
  _BibonFootprintComponent({
    required super.position,
    required this.facing,
    required this.leftFoot,
  }) : super(size: Vector2.all(22), anchor: Anchor.center, priority: 120);

  static const double _lifetime = 1.45;

  final AvatarFacing facing;
  final bool leftFoot;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final progress = (_elapsed / _lifetime).clamp(0.0, 1.0);
    final alpha = (1.0 - progress) * 0.42;
    final paint = Paint()
      ..color = const Color(0xFF78D9FF).withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    final glow = Paint()
      ..color = const Color(0xFFB8F4FF).withValues(alpha: alpha * 0.7)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(size.x * 0.5, size.y * 0.5);
    canvas.rotate(_rotationForFacing());
    final shrink = 1 - (progress * 0.18);
    canvas.scale(shrink);

    final sole = Rect.fromCenter(
      center: const Offset(0, 2),
      width: 8,
      height: 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sole, const Radius.circular(3)),
      paint,
    );

    final toeYOffset = leftFoot ? -4.5 : -3.5;
    for (final x in const <double>[-3.2, 0, 3.2]) {
      canvas.drawCircle(Offset(x, toeYOffset), 1.6, glow);
    }
    canvas.restore();
  }

  double _rotationForFacing() {
    return switch (facing) {
      AvatarFacing.down => leftFoot ? -0.12 : 0.12,
      AvatarFacing.up => leftFoot ? 0.12 : -0.12,
      AvatarFacing.left => -math.pi / 2,
      AvatarFacing.right => math.pi / 2,
    };
  }
}

enum _HeroFacing { down, up, left, right }
