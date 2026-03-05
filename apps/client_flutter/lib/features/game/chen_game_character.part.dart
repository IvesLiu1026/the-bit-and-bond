part of 'chen_game.dart';

class _HeroCharacterComponent
    extends SpriteAnimationGroupComponent<_HeroAnimState> {
  _HeroCharacterComponent({
    required super.position,
    required Map<_HeroAnimState, SpriteAnimation> animations,
  }) : super(
         size: Vector2.all(72),
         anchor: Anchor.center,
         animations: animations,
         current: _HeroAnimState.idleDown,
       ) {
    paint.filterQuality = FilterQuality.none;
  }

  static const double _frameStep = 0.1;
  static const int _downRow = 13;
  static const int _rightRow = 14;
  static const int _leftRow = 15;
  static const int _upRow = 16;

  final double radius = 22;
  _HeroFacing _facing = _HeroFacing.down;
  bool _controlled = false;
  bool _walking = false;
  bool _hasRemoteTarget = false;
  final Vector2 _remoteTarget = Vector2.zero();
  static const double _remoteLerpSpeed = 14.0;

  static Map<_HeroAnimState, SpriteAnimation> buildAnimations(
    SpriteSheet spriteSheet,
  ) {
    return {
      _HeroAnimState.idleDown: _buildAnimation(
        spriteSheet: spriteSheet,
        row: _downRow,
        columns: const [0],
      ),
      _HeroAnimState.walkDown: _buildAnimation(
        spriteSheet: spriteSheet,
        row: _downRow,
        columns: const [1, 2, 3, 4],
      ),
      _HeroAnimState.idleUp: _buildAnimation(
        spriteSheet: spriteSheet,
        row: _upRow,
        columns: const [0],
      ),
      _HeroAnimState.walkUp: _buildAnimation(
        spriteSheet: spriteSheet,
        row: _upRow,
        columns: const [1, 2, 3, 4],
      ),
      _HeroAnimState.idleLeft: _buildAnimation(
        spriteSheet: spriteSheet,
        row: _leftRow,
        columns: const [0],
      ),
      _HeroAnimState.walkLeft: _buildAnimation(
        spriteSheet: spriteSheet,
        row: _leftRow,
        columns: const [1, 2, 3, 4],
      ),
      _HeroAnimState.idleRight: _buildAnimation(
        spriteSheet: spriteSheet,
        row: _rightRow,
        columns: const [0],
      ),
      _HeroAnimState.walkRight: _buildAnimation(
        spriteSheet: spriteSheet,
        row: _rightRow,
        columns: const [1, 2, 3, 4],
      ),
    };
  }

  static SpriteAnimation _buildAnimation({
    required SpriteSheet spriteSheet,
    required int row,
    required List<int> columns,
  }) {
    final frameData = columns
        .map(
          (column) =>
              spriteSheet.createFrameData(row, column, stepTime: _frameStep),
        )
        .toList();

    return SpriteAnimation.fromFrameData(
      spriteSheet.image,
      SpriteAnimationData(frameData),
    );
  }

  void setMotion(Vector2 velocity, {required bool moving}) {
    if (!velocity.isZero()) {
      _updateFacing(velocity);
    }
    _walking = moving;
    _applyAnimation();
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
  }) {
    _facing = _fromWireFacing(pose.facing);
    _walking = pose.moving;
    final minX = radius;
    final maxX = math.max(minX, worldSize.x - radius);
    final minY = ChenLevelingGame._topWallHeight + radius + 6;
    final maxY = math.max(minY, worldSize.y - radius);

    _remoteTarget.setValues(
      pose.x.clamp(minX, maxX).toDouble(),
      pose.y.clamp(minY, maxY).toDouble(),
    );
    _hasRemoteTarget = true;
    if (snapToTarget) {
      position.setFrom(_remoteTarget);
    }
    _applyAnimation();
  }

  @override
  void update(double dt) {
    super.update(dt);
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

  void _applyAnimation() {
    current = switch ((_facing, _walking)) {
      (_HeroFacing.down, true) => _HeroAnimState.walkDown,
      (_HeroFacing.down, false) => _HeroAnimState.idleDown,
      (_HeroFacing.up, true) => _HeroAnimState.walkUp,
      (_HeroFacing.up, false) => _HeroAnimState.idleUp,
      (_HeroFacing.left, true) => _HeroAnimState.walkLeft,
      (_HeroFacing.left, false) => _HeroAnimState.idleLeft,
      (_HeroFacing.right, true) => _HeroAnimState.walkRight,
      (_HeroFacing.right, false) => _HeroAnimState.idleRight,
    };
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
