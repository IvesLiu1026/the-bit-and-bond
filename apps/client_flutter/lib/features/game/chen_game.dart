import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../quests/models.dart';

class HunterRealtimePose {
  HunterRealtimePose({
    required this.hunterId,
    required this.x,
    required this.y,
    required this.facing,
    required this.moving,
    required this.updatedAtMs,
  });

  final String hunterId;
  final double x;
  final double y;
  final String facing;
  final bool moving;
  final int updatedAtMs;

  Map<String, dynamic> toClientMessage() {
    return {
      'type': 'pose',
      'hunter_id': hunterId,
      'x': x,
      'y': y,
      'facing': facing,
      'moving': moving,
    };
  }

  static HunterRealtimePose? fromServerJson(Map<String, dynamic> json) {
    final hunterId = json['hunter_id'] as String?;
    final xRaw = json['x'];
    final yRaw = json['y'];
    final facing = (json['facing'] as String?)?.trim();
    final moving = json['moving'] as bool?;
    final updatedAtMs = json['updated_at_ms'];

    if (hunterId == null ||
        xRaw is! num ||
        yRaw is! num ||
        facing == null ||
        moving == null ||
        updatedAtMs is! int) {
      return null;
    }
    return HunterRealtimePose(
      hunterId: hunterId,
      x: xRaw.toDouble(),
      y: yRaw.toDouble(),
      facing: facing,
      moving: moving,
      updatedAtMs: updatedAtMs,
    );
  }
}

class ChenLevelingGame extends FlameGame with PanDetector {
  ChenLevelingGame();

  static const String _heroSpriteSheetPath =
      'sprites/hero/Free Pixel Character Base Pack/character.png';
  static const double _heroSpeed = 210;
  static const double _joystickDeadZone = 0.08;
  static const double _joystickBaseRadius = 88;
  static const double _joystickKnobRadius = 38;
  static const int _remoteActorTtlMs = 45000;

  RectangleComponent? _background;
  SpriteSheet? _heroSpriteSheet;
  _FloatingJoystickOverlay? _floatingJoystick;
  final Vector2 _joystickInput = Vector2.zero();
  final Map<String, _HeroCharacterComponent> _hunterSprites = {};
  final Set<String> _initializedHunterPositions = <String>{};
  final Map<String, int> _lastPoseTsByHunter = {};
  final Set<String> _realtimeOnlyHunterIds = <String>{};
  List<String> _hunterOrder = const [];
  String? _controlledHunterId;
  String? _pendingControlledHunterId;
  int _lastRealtimeGcMs = 0;

  final List<QuestInstance> _quests = [];

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/';

    final background = RectangleComponent(
      position: Vector2.zero(),
      size: Vector2(1280, 800),
      paint: Paint()..color = AppColors.grassBase,
    );
    _background = background;
    add(background);
    add(_GroundTextureLayer());

    final spriteImage = await images.load(_heroSpriteSheetPath);
    final spriteSheet = SpriteSheet(
      image: spriteImage,
      srcSize: Vector2.all(32),
    );
    _heroSpriteSheet = spriteSheet;

    final floatingJoystick = _FloatingJoystickOverlay(
      baseRadius: _joystickBaseRadius,
      knobRadius: _joystickKnobRadius,
    );
    floatingJoystick.resizeTo(size);
    _floatingJoystick = floatingJoystick;
    camera.viewport.add(floatingJoystick);

    _applyRoster();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _background?.size = size;
    _floatingJoystick?.resizeTo(size);
    _layoutHunters();
  }

  void syncQuests(List<QuestInstance> quests) {
    _quests
      ..clear()
      ..addAll(quests);
  }

  void syncHunters(
    List<HunterProfile> _, {
    required String? controlledHunterId,
  }) {
    _pendingControlledHunterId = controlledHunterId;
    _applyRoster();
  }

  HunterRealtimePose? controlledPoseForSync() {
    final controlledId = _controlledHunterId;
    final controlled = _controlledHunter;
    if (controlledId == null || controlled == null) {
      return null;
    }
    return HunterRealtimePose(
      hunterId: controlledId,
      x: controlled.position.x,
      y: controlled.position.y,
      facing: controlled.facingWire,
      moving: controlled.isWalking,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void applyRemotePose(HunterRealtimePose pose) {
    if (pose.hunterId == _controlledHunterId) {
      return;
    }
    final sprite = _ensureHunterSprite(pose.hunterId, realtimeOnly: true);
    if (sprite == null) {
      return;
    }

    final lastTs = _lastPoseTsByHunter[pose.hunterId];
    if (lastTs != null && pose.updatedAtMs <= lastTs) {
      return;
    }
    _lastPoseTsByHunter[pose.hunterId] = pose.updatedAtMs;

    sprite.position.setValues(pose.x, pose.y);
    _clampPlayerToCanvas(sprite);
    sprite.applyNetworkPose(pose);
    _initializedHunterPositions.add(pose.hunterId);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _evictStaleRealtimeActors();

    final player = _controlledHunter;
    if (player == null) {
      return;
    }

    if (_joystickInput.length < _joystickDeadZone) {
      player.setMotion(Vector2.zero(), moving: false);
      return;
    }

    final velocity = _joystickInput.normalized() * _heroSpeed;
    player.position += velocity * dt;
    _clampPlayerToCanvas(player);
    player.setMotion(velocity, moving: true);
  }

  @override
  void handlePanStart(DragStartDetails details) {
    super.handlePanStart(details);
    if (_controlledHunter == null) {
      return;
    }
    final floatingJoystick = _floatingJoystick;
    if (floatingJoystick == null) {
      return;
    }
    floatingJoystick.activate(
      Vector2(details.localPosition.dx, details.localPosition.dy),
    );
    _joystickInput.setZero();
  }

  @override
  void handlePanUpdate(DragUpdateDetails details) {
    super.handlePanUpdate(details);
    if (_controlledHunter == null) {
      _joystickInput.setZero();
      return;
    }
    final floatingJoystick = _floatingJoystick;
    if (floatingJoystick == null) {
      return;
    }
    floatingJoystick.updateTouch(
      Vector2(details.localPosition.dx, details.localPosition.dy),
      _joystickInput,
    );
  }

  @override
  void handlePanEnd(DragEndDetails details) {
    super.handlePanEnd(details);
    _joystickInput.setZero();
    _floatingJoystick?.deactivate();
  }

  @override
  void onPanCancel() {
    _joystickInput.setZero();
    _floatingJoystick?.deactivate();
  }

  _HeroCharacterComponent? get _controlledHunter {
    final id = _controlledHunterId;
    if (id == null) {
      return null;
    }
    return _hunterSprites[id];
  }

  void _applyRoster() {
    if (_heroSpriteSheet == null) {
      return;
    }

    final controlledCandidate = _pendingControlledHunterId?.trim();
    final targetIds = <String>{..._realtimeOnlyHunterIds};
    if (controlledCandidate != null && controlledCandidate.isNotEmpty) {
      targetIds.add(controlledCandidate);
    }

    final removedIds = _hunterSprites.keys
        .where((id) => !targetIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      final sprite = _hunterSprites.remove(id);
      sprite?.removeFromParent();
      _initializedHunterPositions.remove(id);
      _lastPoseTsByHunter.remove(id);
      _realtimeOnlyHunterIds.remove(id);
    }

    for (final id in targetIds) {
      final isControlled =
          controlledCandidate != null && id == controlledCandidate;
      _ensureHunterSprite(id, realtimeOnly: !isControlled);
    }

    _hunterOrder = targetIds.toList(growable: false)..sort();
    _resolveControlledHunter();
    _layoutHunters();
  }

  void _resolveControlledHunter() {
    if (_hunterOrder.isEmpty) {
      _controlledHunterId = null;
      return;
    }

    final preferred = _pendingControlledHunterId;
    if (preferred == null || preferred.trim().isEmpty) {
      _controlledHunterId = null;
    } else if (_hunterSprites.containsKey(preferred)) {
      _controlledHunterId = preferred;
    } else {
      _controlledHunterId = null;
    }

    for (final entry in _hunterSprites.entries) {
      entry.value.setControlled(entry.key == _controlledHunterId);
    }
  }

  void _layoutHunters() {
    if (size.x <= 0 || size.y <= 0 || _hunterOrder.isEmpty) {
      return;
    }

    final controlledId = _controlledHunterId;
    if (controlledId != null) {
      final controlled = _hunterSprites[controlledId];
      if (controlled != null &&
          !_initializedHunterPositions.contains(controlledId)) {
        controlled.position = size / 2;
        _initializedHunterPositions.add(controlledId);
      }
      if (controlled != null) {
        _clampPlayerToCanvas(controlled);
      }
    }

    final others = _hunterOrder
        .where((id) => id != controlledId)
        .toList(growable: false);
    if (others.isEmpty) {
      return;
    }

    final center = size / 2;
    final radius = math.max(56, math.min(size.x, size.y) * 0.28);
    final total = others.length;
    for (var index = 0; index < total; index++) {
      final id = others[index];
      final sprite = _hunterSprites[id];
      if (sprite == null) {
        continue;
      }
      if (_initializedHunterPositions.contains(id)) {
        continue;
      }
      final angle = ((2 * math.pi) * index / total) - (math.pi / 2);
      sprite.position =
          center +
          Vector2(
            math.cos(angle).toDouble() * radius,
            math.sin(angle) * radius,
          );
      _clampPlayerToCanvas(sprite);
      _initializedHunterPositions.add(id);
      sprite.setMotion(Vector2.zero(), moving: false);
    }
  }

  _HeroCharacterComponent? _ensureHunterSprite(
    String hunterId, {
    required bool realtimeOnly,
  }) {
    final existing = _hunterSprites[hunterId];
    if (existing != null) {
      if (realtimeOnly) {
        _realtimeOnlyHunterIds.add(hunterId);
      } else {
        _realtimeOnlyHunterIds.remove(hunterId);
      }
      return existing;
    }

    final spriteSheet = _heroSpriteSheet;
    if (spriteSheet == null) {
      return null;
    }

    final sprite = _HeroCharacterComponent(
      position: Vector2.zero(),
      animations: _HeroCharacterComponent.buildAnimations(spriteSheet),
    );
    _hunterSprites[hunterId] = sprite;
    if (realtimeOnly) {
      _realtimeOnlyHunterIds.add(hunterId);
    } else {
      _realtimeOnlyHunterIds.remove(hunterId);
    }
    add(sprite);
    return sprite;
  }

  void _evictStaleRealtimeActors() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastRealtimeGcMs < 2000) {
      return;
    }
    _lastRealtimeGcMs = nowMs;

    final staleIds = _realtimeOnlyHunterIds
        .where(
          (id) => nowMs - (_lastPoseTsByHunter[id] ?? 0) > _remoteActorTtlMs,
        )
        .toList(growable: false);
    for (final id in staleIds) {
      _realtimeOnlyHunterIds.remove(id);
      _lastPoseTsByHunter.remove(id);
      _initializedHunterPositions.remove(id);
      final sprite = _hunterSprites.remove(id);
      sprite?.removeFromParent();
    }
  }

  void _clampPlayerToCanvas(_HeroCharacterComponent player) {
    final minX = player.radius;
    final maxX = math.max(minX, size.x - player.radius);
    final minY = player.radius;
    final maxY = math.max(minY, size.y - player.radius);

    player.position
      ..x = player.position.x.clamp(minX, maxX)
      ..y = player.position.y.clamp(minY, maxY);
  }
}

class _GroundTextureLayer extends Component
    with HasGameReference<ChenLevelingGame> {
  static const double _tile = 56;
  ui.Picture? _cachedGround;
  Size _cachedSize = Size.zero;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final width = game.size.x.floorToDouble();
    final height = game.size.y.floorToDouble();
    if (width <= 0 || height <= 0) {
      return;
    }

    final targetSize = Size(width, height);
    final picture = _ensureGroundPicture(targetSize);
    if (picture != null) {
      canvas.drawPicture(picture);
    }
  }

  ui.Picture? _ensureGroundPicture(Size size) {
    if (_cachedGround != null && _cachedSize == size) {
      return _cachedGround;
    }

    final recorder = ui.PictureRecorder();
    final cachedCanvas = Canvas(recorder);
    _paintGround(cachedCanvas, width: size.width, height: size.height);
    _cachedGround = recorder.endRecording();
    _cachedSize = size;
    return _cachedGround;
  }

  void _paintGround(
    Canvas canvas, {
    required double width,
    required double height,
  }) {
    final paintA = Paint()..color = const Color(0x224E8B3D);
    final paintB = Paint()..color = const Color(0x1B5E9E4A);
    final gridLine = Paint()
      ..color = const Color(0x2B2E5D27)
      ..strokeWidth = 1;
    final speckA = Paint()..color = const Color(0x2B355D24);
    final speckB = Paint()..color = const Color(0x225D8D44);
    final rows = (height / _tile).ceil();
    final cols = (width / _tile).ceil();

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final paint = (row + col).isEven ? paintA : paintB;
        final rect = Rect.fromLTWH(col * _tile, row * _tile, _tile, _tile);
        canvas.drawRect(rect, paint);
        final speckX = rect.left + ((row * 17 + col * 29) % 35);
        final speckY = rect.top + ((row * 13 + col * 11) % 35);
        canvas.drawCircle(
          Offset(speckX.toDouble(), speckY.toDouble()),
          1.2,
          speckA,
        );
        canvas.drawCircle(
          Offset((speckX + 13).toDouble(), (speckY + 9).toDouble()),
          0.9,
          speckB,
        );
      }
    }

    for (var x = 0.0; x <= width; x += _tile) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridLine);
    }
    for (var y = 0.0; y <= height; y += _tile) {
      canvas.drawLine(Offset(0, y), Offset(width, y), gridLine);
    }
  }

  @override
  void onRemove() {
    _cachedGround = null;
    _cachedSize = Size.zero;
    super.onRemove();
  }
}

enum _HeroFacing { down, up, left, right }

enum _HeroAnimState {
  idleDown,
  walkDown,
  idleUp,
  walkUp,
  idleLeft,
  walkLeft,
  idleRight,
  walkRight,
}

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

  void applyNetworkPose(HunterRealtimePose pose) {
    _facing = _fromWireFacing(pose.facing);
    _walking = pose.moving;
    _applyAnimation();
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

class _FloatingJoystickOverlay extends PositionComponent {
  _FloatingJoystickOverlay({required this.baseRadius, required this.knobRadius})
    : super(position: Vector2.zero(), anchor: Anchor.topLeft, priority: 9000);

  final double baseRadius;
  final double knobRadius;

  bool _active = false;
  final Vector2 _center = Vector2.zero();
  final Vector2 _knob = Vector2.zero();
  final Vector2 _delta = Vector2.zero();

  void resizeTo(Vector2 canvasSize) {
    size = canvasSize;
  }

  void activate(Vector2 rawPosition) {
    _active = true;
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
    _center.setZero();
    _knob.setZero();
    _delta.setZero();
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
    if (!_active) {
      return;
    }

    final center = Offset(_center.x, _center.y);
    final knobCenter = Offset(_knob.x, _knob.y);
    final dropShadow = Paint()..color = const Color(0x5A1A100C);
    final outer = Paint()
      ..color = AppColors.joystickBase.withValues(alpha: 0.72);
    final cavity = Paint()..color = const Color(0xA62A1A14);
    final innerShadow = Paint()
      ..shader = ui.Gradient.radial(center, baseRadius - 6, const [
        Color(0x00000000),
        Color(0x55000000),
      ]);
    final baseRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0x996D4C41);

    final knobShadow = Paint()..color = const Color(0x880D315A);
    final knobGem = Paint()
      ..shader =
          ui.Gradient.radial(knobCenter.translate(-5, -6), knobRadius - 1.5, [
            AppColors.joystickGemLight.withValues(alpha: 0.96),
            AppColors.joystickGem.withValues(alpha: 0.92),
          ]);
    final knobRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xAAEAF4FF);
    final knobHighlight = Paint()..color = const Color(0xCCFFFFFF);

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
