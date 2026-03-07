part of 'chen_game.dart';

class _HeroCharacterComponent extends PositionComponent {
  _HeroCharacterComponent({
    required super.position,
    required SpriteSheet spriteSheet,
  }) : _spriteSheet = spriteSheet,
       super(size: Vector2.all(72), anchor: Anchor.center, priority: 200);

  static const double _frameStep = 0.1;
  static const int _frameSize = 32;
  static const int _downRow = 13;
  static const int _rightRow = 14;
  static const int _leftRow = 15;
  static const int _upRow = 16;
  static const List<int> _walkColumns = <int>[1, 2, 3, 4];

  final SpriteSheet _spriteSheet;
  final Paint _spritePaint = Paint()..filterQuality = FilterQuality.none;
  final double radius = 22;
  _HeroFacing _facing = _HeroFacing.down;
  bool _controlled = false;
  bool _walking = false;
  bool _hasRemoteTarget = false;
  final Vector2 _remoteTarget = Vector2.zero();
  static const double _remoteLerpSpeed = 14.0;
  double _animationTick = 0;
  int _walkFrameIndex = 0;

  @override
  void render(Canvas canvas) {
    final shadow = Paint()..color = const Color(0x5520100A);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * 0.5, size.y * 0.83),
        width: size.x * 0.42,
        height: size.y * 0.16,
      ),
      shadow,
    );

    final sourceRect = Rect.fromLTWH(
      (_currentColumn * _frameSize).toDouble(),
      (_currentRow * _frameSize).toDouble(),
      _frameSize.toDouble(),
      _frameSize.toDouble(),
    );
    final destinationRect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawImageRect(
      _spriteSheet.image,
      sourceRect,
      destinationRect,
      _spritePaint,
    );
  }

  void setMotion(Vector2 velocity, {required bool moving}) {
    if (!velocity.isZero()) {
      _updateFacing(velocity);
    }
    if (_walking != moving && !moving) {
      _animationTick = 0;
      _walkFrameIndex = 0;
    }
    _walking = moving;
  }

  bool get isWalking => _walking;

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

  int get _currentRow {
    return switch (_facing) {
      _HeroFacing.down => _downRow,
      _HeroFacing.up => _upRow,
      _HeroFacing.left => _leftRow,
      _HeroFacing.right => _rightRow,
    };
  }

  int get _currentColumn {
    if (!_walking) {
      return 0;
    }
    return _walkColumns[_walkFrameIndex];
  }

  void _advanceAnimation(double dt) {
    if (!_walking) {
      _animationTick = 0;
      _walkFrameIndex = 0;
      return;
    }

    _animationTick += dt;
    while (_animationTick >= _frameStep) {
      _animationTick -= _frameStep;
      _walkFrameIndex = (_walkFrameIndex + 1) % _walkColumns.length;
    }
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
}

enum _HeroFacing { down, up, left, right }
