import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../quests/models.dart';

part 'chen_game_environment.part.dart';
part 'chen_game_furniture.part.dart';
part 'chen_game_character.part.dart';
part 'chen_game_joystick.part.dart';

enum TavernFurnitureType {
  noticeBoard,
  masterDesk,
  guildChest,
  campfireBar,
  guildMerchant,
}

enum TavernVisualTheme { cozyWood, technoMinimal, hotbloodAdventure }

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

class ChenLevelingGame extends FlameGame with PanDetector, KeyboardEvents {
  ChenLevelingGame({this.onFurnitureInteracted});

  static const String _heroSpriteSheetPath =
      'sprites/hero/Free Pixel Character Base Pack/character.png';
  static const double _heroSpeed = 210;
  static const double _joystickDeadZone = 0.08;
  static const double _joystickBaseRadius = 88;
  static const double _joystickKnobRadius = 38;
  static const int _remoteActorTtlMs = 15000;
  static const double _topWallHeight = 118;
  static const double _playHorizontalPadding = 14;
  static const double _playBottomPadding = 14;
  static const double _furnitureInteractDistance = 10;

  RectangleComponent? _background;
  SpriteSheet? _heroSpriteSheet;
  _FloatingJoystickOverlay? _floatingJoystick;
  _TavernEnvironmentLayer? _environmentLayer;
  final Map<TavernFurnitureType, InteractiveFurniture> _furnitures = {};
  final Vector2 _joystickInput = Vector2.zero();
  final Map<String, _HeroCharacterComponent> _hunterSprites = {};
  final Set<String> _initializedHunterPositions = <String>{};
  final Map<String, int> _lastServerPoseTsByHunter = {};
  final Map<String, int> _lastPoseSeenAtMsByHunter = {};
  final Set<String> _realtimeOnlyHunterIds = <String>{};
  final List<Rect> _obstacleRects = <Rect>[];
  List<String> _hunterOrder = const [];
  String? _controlledHunterId;
  String? _pendingControlledHunterId;
  int _lastRealtimeGcMs = 0;
  TavernVisualTheme _theme = TavernVisualTheme.cozyWood;
  String? _lastInteractionHint;
  bool _campfireConnected = false;
  bool _campfireHasActiveSpeaker = false;
  double _campfirePulseTick = 0;

  final List<QuestInstance> _quests = [];
  final ValueNotifier<String?> interactionHintListenable =
      ValueNotifier<String?>(null);
  final ValueNotifier<Set<String>> activeHunterIdsListenable =
      ValueNotifier<Set<String>>(<String>{});
  final ValueNotifier<TavernFurnitureType?> nearbyFurnitureListenable =
      ValueNotifier<TavernFurnitureType?>(null);

  int get actorCount => _hunterSprites.length;
  int get realtimeActorCount => _realtimeOnlyHunterIds.length;
  TavernVisualTheme get theme => _theme;
  final void Function(TavernFurnitureType furniture)? onFurnitureInteracted;

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/';

    final background = RectangleComponent(
      position: Vector2.zero(),
      size: Vector2(1280, 800),
      paint: Paint()..color = const Color(0xFF4A2E24),
    );
    _background = background;
    add(background);
    final environmentLayer = _TavernEnvironmentLayer(theme: _theme);
    _environmentLayer = environmentLayer;
    add(environmentLayer);

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

    _spawnFurniture();
    _applyThemePalette();
    _layoutFurniture();
    _applyRoster();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _background?.size = size;
    _floatingJoystick?.resizeTo(size);
    _environmentLayer?.markDirty();
    _layoutFurniture();
    _layoutHunters();
  }

  void setVisualTheme(TavernVisualTheme theme) {
    if (_theme == theme) {
      return;
    }
    _theme = theme;
    _applyThemePalette();
    _environmentLayer?.setTheme(theme);
    _environmentLayer?.markDirty();
  }

  void setCampfireVoiceActivity({
    required bool connected,
    required bool hasActiveSpeaker,
  }) {
    _campfireConnected = connected;
    _campfireHasActiveSpeaker = hasActiveSpeaker;
  }

  void _applyThemePalette() {
    final backgroundColor = switch (_theme) {
      TavernVisualTheme.cozyWood => const Color(0xFF4A2E24),
      TavernVisualTheme.technoMinimal => const Color(0xFF0F1B2D),
      TavernVisualTheme.hotbloodAdventure => const Color(0xFF402014),
    };
    _background?.paint.color = backgroundColor;
    _applyFurniturePalette();
  }

  void _applyFurniturePalette() {
    final palette = switch (_theme) {
      TavernVisualTheme.cozyWood => const {
        TavernFurnitureType.noticeBoard: (Color(0xFF8D6E63), Color(0xFFD4AF37)),
        TavernFurnitureType.masterDesk: (Color(0xFF6D4C41), Color(0xFF9E7D5A)),
        TavernFurnitureType.guildChest: (Color(0xFF5D4037), Color(0xFFC9A227)),
        TavernFurnitureType.campfireBar: (Color(0xFF4E342E), Color(0xFFFFB74D)),
        TavernFurnitureType.guildMerchant: (
          Color(0xFF5E3F2A),
          Color(0xFFCF9E2D),
        ),
      },
      TavernVisualTheme.technoMinimal => const {
        TavernFurnitureType.noticeBoard: (Color(0xFF263238), Color(0xFF26C6DA)),
        TavernFurnitureType.masterDesk: (Color(0xFF37474F), Color(0xFF4FC3F7)),
        TavernFurnitureType.guildChest: (Color(0xFF1E2A36), Color(0xFF80DEEA)),
        TavernFurnitureType.campfireBar: (Color(0xFF102027), Color(0xFF00B8D4)),
        TavernFurnitureType.guildMerchant: (
          Color(0xFF1D3557),
          Color(0xFF00B4D8),
        ),
      },
      TavernVisualTheme.hotbloodAdventure => const {
        TavernFurnitureType.noticeBoard: (Color(0xFF6D2C22), Color(0xFFFFB74D)),
        TavernFurnitureType.masterDesk: (Color(0xFF5D1F18), Color(0xFFE57373)),
        TavernFurnitureType.guildChest: (Color(0xFF7B3F00), Color(0xFFFFD54F)),
        TavernFurnitureType.campfireBar: (Color(0xFF6A1B1A), Color(0xFFFF8A65)),
        TavernFurnitureType.guildMerchant: (
          Color(0xFF8D3F1E),
          Color(0xFFFFCA28),
        ),
      },
    };
    for (final entry in palette.entries) {
      final furniture = _furnitures[entry.key];
      if (furniture == null) {
        continue;
      }
      final (tint, accent) = entry.value;
      furniture.applyPalette(tint: tint, accent: accent);
    }
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

  void _spawnFurniture() {
    if (_furnitures.isNotEmpty) {
      return;
    }

    final noticeBoard = InteractiveFurniture(
      type: TavernFurnitureType.noticeBoard,
      label: '任務佈告欄',
      size: Vector2(186, 94),
      tint: const Color(0xFF8D6E63),
      accent: const Color(0xFFD4AF37),
    );
    final masterDesk = InteractiveFurniture(
      type: TavernFurnitureType.masterDesk,
      label: '公會長書桌',
      size: Vector2(160, 86),
      tint: const Color(0xFF6D4C41),
      accent: const Color(0xFF9E7D5A),
    );
    final guildChest = InteractiveFurniture(
      type: TavernFurnitureType.guildChest,
      label: '公會儲物箱',
      size: Vector2(118, 82),
      tint: const Color(0xFF5D4037),
      accent: const Color(0xFFC9A227),
    );
    final campfireBar = InteractiveFurniture(
      type: TavernFurnitureType.campfireBar,
      label: '營火語音吧台',
      size: Vector2(126, 90),
      tint: const Color(0xFF4E342E),
      accent: const Color(0xFFFFB74D),
    );
    final guildMerchant = InteractiveFurniture(
      type: TavernFurnitureType.guildMerchant,
      label: '公會商人',
      size: Vector2(128, 86),
      tint: const Color(0xFF5E3F2A),
      accent: const Color(0xFFCF9E2D),
    );

    _furnitures[TavernFurnitureType.noticeBoard] = noticeBoard;
    _furnitures[TavernFurnitureType.masterDesk] = masterDesk;
    _furnitures[TavernFurnitureType.guildChest] = guildChest;
    _furnitures[TavernFurnitureType.campfireBar] = campfireBar;
    _furnitures[TavernFurnitureType.guildMerchant] = guildMerchant;

    add(noticeBoard);
    add(masterDesk);
    add(guildChest);
    add(campfireBar);
    add(guildMerchant);
  }

  void _layoutFurniture() {
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    final noticeBoard = _furnitures[TavernFurnitureType.noticeBoard];
    final masterDesk = _furnitures[TavernFurnitureType.masterDesk];
    final guildChest = _furnitures[TavernFurnitureType.guildChest];
    final campfireBar = _furnitures[TavernFurnitureType.campfireBar];
    final guildMerchant = _furnitures[TavernFurnitureType.guildMerchant];
    if (noticeBoard == null ||
        masterDesk == null ||
        guildChest == null ||
        campfireBar == null ||
        guildMerchant == null) {
      return;
    }

    noticeBoard.position = Vector2(30, _topWallHeight + 12);
    masterDesk.position = Vector2(
      size.x - masterDesk.size.x - 28,
      _topWallHeight + 28,
    );
    guildChest.position = Vector2(26, size.y - guildChest.size.y - 28);
    campfireBar.position = Vector2(
      size.x - campfireBar.size.x - 190,
      size.y - campfireBar.size.y - 26,
    );
    guildMerchant.position = Vector2(
      size.x - guildMerchant.size.x - 24,
      size.y - guildMerchant.size.y - 28,
    );
    _rebuildObstacleRects();
  }

  void _rebuildObstacleRects() {
    _obstacleRects.clear();
    for (final furniture in _furnitures.values) {
      _obstacleRects.add(furniture.collisionRect);
    }

    final table = _centerTableRect();
    _obstacleRects.add(table);
    _obstacleRects.add(
      Rect.fromLTWH(table.left - 46, table.center.dy - 22, 36, 44),
    );
    _obstacleRects.add(
      Rect.fromLTWH(table.right + 10, table.center.dy - 22, 36, 44),
    );
    _obstacleRects.add(Rect.fromLTWH(size.x - 106, _topWallHeight + 8, 70, 78));
  }

  Rect _centerTableRect() {
    final width = math.max(160, size.x * 0.18).toDouble();
    final height = 74.0;
    return Rect.fromCenter(
      center: Offset(size.x / 2, (size.y / 2) + 52),
      width: width,
      height: height,
    );
  }

  bool _tryInteractFurniture(Vector2 touchPoint) {
    if (onFurnitureInteracted == null) {
      return false;
    }
    final player = _controlledHunter;
    if (player == null) {
      return false;
    }

    for (final furniture in _furnitures.values) {
      if (!furniture.hit(touchPoint)) {
        continue;
      }
      final distance = furniture.distanceToInteractionZone(player.position);
      if (distance > _furnitureInteractDistance) {
        return false;
      }
      onFurnitureInteracted?.call(furniture.type);
      return true;
    }
    return false;
  }

  bool _tryInteractClosestFurniture() {
    if (onFurnitureInteracted == null) {
      return false;
    }
    final candidate = _closestFurnitureForInteraction();
    if (candidate == null) {
      return false;
    }
    onFurnitureInteracted?.call(candidate.type);
    return true;
  }

  InteractiveFurniture? _closestFurnitureForInteraction() {
    final player = _controlledHunter;
    if (player == null) {
      return null;
    }
    InteractiveFurniture? nearest;
    var minDistance = double.infinity;
    for (final furniture in _furnitures.values) {
      final distance = furniture.distanceToInteractionZone(player.position);
      if (distance > _furnitureInteractDistance) {
        continue;
      }
      if (distance < minDistance) {
        minDistance = distance;
        nearest = furniture;
      }
    }
    return nearest;
  }

  void _updateInteractionHint() {
    final nearest = _closestFurnitureForInteraction();
    if (nearbyFurnitureListenable.value != nearest?.type) {
      nearbyFurnitureListenable.value = nearest?.type;
    }
    final hint = switch (nearest?.type) {
      TavernFurnitureType.noticeBoard => '已接近任務佈告欄，點右下互動鍵',
      TavernFurnitureType.masterDesk => '已接近公會長書桌，點右下互動鍵',
      TavernFurnitureType.guildChest => '已接近公會儲物箱，點右下互動鍵',
      TavernFurnitureType.campfireBar => '已接近營火語音吧台，點右下互動鍵',
      TavernFurnitureType.guildMerchant => '已接近公會商人，點右下互動鍵',
      null => '拖曳任意位置，叫出搖桿移動',
    };
    if (hint == _lastInteractionHint) {
      return;
    }
    _lastInteractionHint = hint;
    interactionHintListenable.value = hint;
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

  Offset? hunterHeadScreenAnchor(String hunterId, {double verticalLift = 34}) {
    if (size.x <= 0 || size.y <= 0) {
      return null;
    }
    final hunter = _hunterSprites[hunterId];
    if (hunter == null) {
      return null;
    }
    final x = hunter.position.x;
    final y = hunter.position.y - (hunter.size.y * 0.58) - verticalLift;
    final clampedX = x.clamp(18, size.x - 18).toDouble();
    final clampedY = y.clamp(_topWallHeight + 10, size.y - 18).toDouble();
    return Offset(clampedX, clampedY);
  }

  Offset? controlledHunterHeadScreenAnchor({double verticalLift = 34}) {
    final controlledId = _controlledHunterId;
    if (controlledId == null) {
      return null;
    }
    return hunterHeadScreenAnchor(controlledId, verticalLift: verticalLift);
  }

  void applyRemotePose(HunterRealtimePose pose) {
    if (pose.hunterId == _controlledHunterId) {
      return;
    }
    final sprite = _ensureHunterSprite(pose.hunterId, realtimeOnly: true);
    if (sprite == null) {
      return;
    }

    final lastTs = _lastServerPoseTsByHunter[pose.hunterId];
    if (lastTs != null && pose.updatedAtMs <= lastTs) {
      return;
    }
    _lastServerPoseTsByHunter[pose.hunterId] = pose.updatedAtMs;
    _lastPoseSeenAtMsByHunter[pose.hunterId] =
        DateTime.now().millisecondsSinceEpoch;

    final isFirstPose = !_initializedHunterPositions.contains(pose.hunterId);
    sprite.applyNetworkPose(pose, snapToTarget: isFirstPose, canvasSize: size);
    _initializedHunterPositions.add(pose.hunterId);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _evictStaleRealtimeActors();
    _updateInteractionHint();
    _campfirePulseTick += dt;
    final campfire = _furnitures[TavernFurnitureType.campfireBar];
    campfire?.setCampfireVisualState(
      connected: _campfireConnected,
      speaking: _campfireHasActiveSpeaker,
      pulse: ((math.sin(_campfirePulseTick * 8) + 1) * 0.5),
    );

    final player = _controlledHunter;
    if (player == null) {
      return;
    }

    if (_joystickInput.length < _joystickDeadZone) {
      player.setMotion(Vector2.zero(), moving: false);
      return;
    }

    final previous = player.position.clone();
    final velocity = _joystickInput.normalized() * _heroSpeed;
    player.position += velocity * dt;
    _clampPlayerToCanvas(player);
    _resolvePlayerObstacleCollision(player, previous);
    player.setMotion(velocity, moving: true);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyE) {
      if (_tryInteractClosestFurniture()) {
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void handlePanStart(DragStartDetails details) {
    super.handlePanStart(details);
    if (_controlledHunter == null) {
      return;
    }
    final touchPoint = Vector2(
      details.localPosition.dx,
      details.localPosition.dy,
    );
    if (_tryInteractFurniture(touchPoint)) {
      _joystickInput.setZero();
      _floatingJoystick?.deactivate();
      return;
    }
    final floatingJoystick = _floatingJoystick;
    if (floatingJoystick == null) {
      return;
    }
    floatingJoystick.activate(touchPoint);
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
      _lastServerPoseTsByHunter.remove(id);
      _lastPoseSeenAtMsByHunter.remove(id);
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
    _publishActiveHunterIds();
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
        final preferred = Vector2(size.x / 2, (_topWallHeight + size.y) / 2);
        controlled.position = _findNearestWalkablePosition(
          preferred,
          controlled.radius,
        );
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

    final center = Vector2(size.x / 2, (_topWallHeight + size.y) / 2);
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
      final preferred =
          center +
          Vector2(
            math.cos(angle).toDouble() * radius,
            math.sin(angle) * radius,
          );
      sprite.position = _findNearestWalkablePosition(preferred, sprite.radius);
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
    _publishActiveHunterIds();
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
          (id) =>
              nowMs - (_lastPoseSeenAtMsByHunter[id] ?? 0) > _remoteActorTtlMs,
        )
        .toList(growable: false);
    for (final id in staleIds) {
      _realtimeOnlyHunterIds.remove(id);
      _lastServerPoseTsByHunter.remove(id);
      _lastPoseSeenAtMsByHunter.remove(id);
      _initializedHunterPositions.remove(id);
      final sprite = _hunterSprites.remove(id);
      sprite?.removeFromParent();
    }
    if (staleIds.isNotEmpty) {
      _publishActiveHunterIds();
    }
  }

  void _clampPlayerToCanvas(_HeroCharacterComponent player) {
    final minX = _playHorizontalPadding + player.radius;
    final maxX = math.max(
      minX,
      size.x - _playHorizontalPadding - player.radius,
    );
    final minY = _topWallHeight + player.radius + 6;
    final maxY = math.max(minY, size.y - _playBottomPadding - player.radius);

    player.position
      ..x = player.position.x.clamp(minX, maxX)
      ..y = player.position.y.clamp(minY, maxY);
  }

  void _resolvePlayerObstacleCollision(
    _HeroCharacterComponent player,
    Vector2 previous,
  ) {
    if (_obstacleRects.isEmpty) {
      return;
    }
    if (!_collidesAt(player.position, player.radius)) {
      return;
    }

    final candidateX = Vector2(previous.x, player.position.y);
    final candidateY = Vector2(player.position.x, previous.y);
    final canUseX = !_collidesAt(candidateX, player.radius);
    final canUseY = !_collidesAt(candidateY, player.radius);
    if (canUseX && !canUseY) {
      player.position.x = previous.x;
      return;
    }
    if (canUseY && !canUseX) {
      player.position.y = previous.y;
      return;
    }
    if (canUseX) {
      player.position.x = previous.x;
      return;
    }
    if (canUseY) {
      player.position.y = previous.y;
      return;
    }
    if (_collidesAt(previous, player.radius)) {
      player.position = _findNearestWalkablePosition(
        player.position,
        player.radius,
      );
      return;
    }
    player.position.setFrom(previous);
  }

  bool _collidesAt(Vector2 center, double radius) {
    final bounds = Rect.fromCircle(
      center: Offset(center.x, center.y),
      radius: math.max(8, radius - 4),
    );
    for (final obstacle in _obstacleRects) {
      if (obstacle.overlaps(bounds)) {
        return true;
      }
    }
    return false;
  }

  bool interactWithNearbyFurniture() {
    return _tryInteractClosestFurniture();
  }

  Vector2 _findNearestWalkablePosition(Vector2 preferred, double radius) {
    final probe = preferred.clone();
    _clampProbeToCanvas(probe, radius);
    if (!_collidesAt(probe, radius)) {
      return probe;
    }

    const ringCount = 8;
    const samplesPerRing = 16;
    for (var ring = 1; ring <= ringCount; ring++) {
      final distance = ring * 28.0;
      for (var i = 0; i < samplesPerRing; i++) {
        final angle = (2 * math.pi * i) / samplesPerRing;
        final candidate = Vector2(
          preferred.x + (math.cos(angle) * distance),
          preferred.y + (math.sin(angle) * distance),
        );
        _clampProbeToCanvas(candidate, radius);
        if (!_collidesAt(candidate, radius)) {
          return candidate;
        }
      }
    }

    return Vector2(size.x / 2, size.y - 120);
  }

  void _clampProbeToCanvas(Vector2 probe, double radius) {
    final minX = _playHorizontalPadding + radius;
    final maxX = math.max(minX, size.x - _playHorizontalPadding - radius);
    final minY = _topWallHeight + radius + 6;
    final maxY = math.max(minY, size.y - _playBottomPadding - radius);
    probe
      ..x = probe.x.clamp(minX, maxX).toDouble()
      ..y = probe.y.clamp(minY, maxY).toDouble();
  }

  void _publishActiveHunterIds() {
    final next = Set<String>.from(_hunterSprites.keys);
    final current = activeHunterIdsListenable.value;
    if (next.length == current.length && next.containsAll(current)) {
      return;
    }
    activeHunterIdsListenable.value = next;
  }

  @override
  void onRemove() {
    interactionHintListenable.dispose();
    activeHunterIdsListenable.dispose();
    nearbyFurnitureListenable.dispose();
    super.onRemove();
  }
}
