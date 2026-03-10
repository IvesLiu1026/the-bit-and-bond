import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/experimental.dart' show Rectangle;
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/app_colors.dart';
import '../avatar/avatar_appearance.dart';
import '../quests/models.dart';

part 'bitbond_game_models.part.dart';
part 'bitbond_game_environment.part.dart';
part 'bitbond_game_furniture.part.dart';
part 'bitbond_game_character.part.dart';
part 'bitbond_game_joystick.part.dart';
part 'bitbond_game_interaction.part.dart';
part 'bitbond_game_hunters.part.dart';
part 'bitbond_game_sandbox.part.dart';
part 'bitbond_game_world.part.dart';

class TheBitAndBondGame extends FlameGame with PanDetector, KeyboardEvents {
  TheBitAndBondGame({this.onFurnitureInteracted});

  static const bool _sandboxRoomMode = true;
  static const String _testingDummyHunterId = '__bibon_test_dummy__';
  static const double _heroSpeed = 210;
  static const double _joystickDeadZone = 0.08;
  static const double _joystickBaseRadius = 68;
  static const double _joystickKnobRadius = 27;
  static const int _remoteActorTtlMs = 15000;
  static const double _baseTopWallHeight = 118;
  static const double _baseWorldWidth = 1920;
  static const double _baseWorldHeight = 1200;
  static const double _cozyBackdropAspectRatio = 623 / 294;
  static const double _playHorizontalPadding = 14;
  static const double _playBottomPadding = 14;
  static const double _furnitureInteractDistance = 10;
  static const double _sandboxWallRatio = 0.24;
  static const double _dummyLinkMagnetRange = 126;
  static const double _dummyLinkSpacing = 70;
  static const double _dummyLinkBreakHoldSeconds = 0.58;
  static const double _dummyRelinkCooldownSeconds = 0.82;
  static const double _portalCooldownSeconds = 0.9;
  static const List<_SandboxRoomDefinition> _sandboxRooms =
      <_SandboxRoomDefinition>[
        _SandboxRoomDefinition(
          id: 'main_bay',
          label: '主接點室',
          hasDummy: true,
          rightPortalTargetIndex: 1,
          palette: _SandboxRoomPalette(
            backgroundColor: Color(0xFF1A130F),
            wallColor: Color(0xFF32261D),
            wallShadeColor: Color(0xFF241B14),
            sideWallColor: Color(0xFF271D16),
            floorBaseColor: Color(0xFF18110D),
            floorTileA: Color(0xFF2B2018),
            floorTileB: Color(0xFF221913),
            gridLineColor: Color(0xAA5A4637),
            borderColor: Color(0xFF0C0806),
            glowColor: Color(0x1FB9E0FF),
            portalCoreColor: Color(0x6642C6FF),
            portalRingColor: Color(0xFF9FE7FF),
            mapAccentColor: Color(0xFFD8A55F),
          ),
        ),
        _SandboxRoomDefinition(
          id: 'mint_room',
          label: '薄荷副室',
          leftPortalTargetIndex: 0,
          palette: _SandboxRoomPalette(
            backgroundColor: Color(0xFF131A19),
            wallColor: Color(0xFF213432),
            wallShadeColor: Color(0xFF182725),
            sideWallColor: Color(0xFF14211F),
            floorBaseColor: Color(0xFF0F1716),
            floorTileA: Color(0xFF1E3431),
            floorTileB: Color(0xFF192A28),
            gridLineColor: Color(0xAA7AD4C8),
            borderColor: Color(0xFF081111),
            glowColor: Color(0x1F8EF7D1),
            portalCoreColor: Color(0x664CE6C9),
            portalRingColor: Color(0xFFB9FFF1),
            mapAccentColor: Color(0xFF74D8C3),
          ),
        ),
      ];

  RectangleComponent? _background;
  _FloatingJoystickOverlay? _floatingJoystick;
  _TavernEnvironmentLayer? _environmentLayer;
  final Map<TavernFurnitureType, InteractiveFurniture> _furnitures = {};
  final Vector2 _joystickInput = Vector2.zero();
  final Map<String, _HeroCharacterComponent> _hunterSprites = {};
  final Map<String, AvatarAppearance> _hunterAppearances = {};
  final Set<String> _initializedHunterPositions = <String>{};
  final Map<String, int> _lastServerPoseTsByHunter = {};
  final Map<String, int> _lastPoseSeenAtMsByHunter = {};
  final Set<String> _realtimeOnlyHunterIds = <String>{};
  final Set<String> _rosterHunterIds = <String>{};
  final List<Rect> _obstacleRects = <Rect>[];
  String? _cameraTrackingHunterId;
  bool _joystickMovementEngaged = false;
  Vector2 _worldSize = Vector2(_baseWorldWidth, _baseWorldHeight);
  List<String> _hunterOrder = const [];
  String? _controlledHunterId;
  String? _pendingControlledHunterId;
  int _lastRealtimeGcMs = 0;
  TavernVisualTheme _theme = TavernVisualTheme.cozyWood;
  String? _lastInteractionHint;
  bool _campfireConnected = false;
  bool _campfireHasActiveSpeaker = false;
  double _campfirePulseTick = 0;
  int _currentSandboxRoomIndex = 0;
  bool _sandboxLinkEngaged = false;
  double _sandboxLinkBreakHold = 0;
  double _sandboxRelinkCooldown = 0;
  double _sandboxPortalCooldown = 0;
  AppLanguage _language = AppLanguage.traditionalChinese;

  final List<QuestInstance> _quests = [];
  final ValueNotifier<String?> interactionHintListenable =
      ValueNotifier<String?>(null);
  final ValueNotifier<Set<String>> activeHunterIdsListenable =
      ValueNotifier<Set<String>>(<String>{});
  final ValueNotifier<TavernFurnitureType?> nearbyFurnitureListenable =
      ValueNotifier<TavernFurnitureType?>(null);
  final ValueNotifier<int> sandboxRoomIndexListenable = ValueNotifier<int>(0);

  int get actorCount =>
      _hunterSprites.keys.where((id) => id != _testingDummyHunterId).length;
  int get realtimeActorCount =>
      _realtimeOnlyHunterIds.where((id) => id != _testingDummyHunterId).length;
  TavernVisualTheme get theme => _theme;
  Vector2 get worldSize => _worldSize;
  bool get isSandboxRoomMode => _sandboxRoomMode;
  int get currentSandboxRoomIndex => _currentSandboxRoomIndex;
  List<SandboxRoomSnapshot> get sandboxRooms =>
      List<SandboxRoomSnapshot>.generate(_sandboxRooms.length, (index) {
        final room = _sandboxRooms[index];
        final dummyMarker = room.hasDummy
            ? (index == _currentSandboxRoomIndex
                  ? _normalizedSandboxMarkerFor(_dummyHunter?.position)
                  : const Offset(0.7, 0.62))
            : null;
        return SandboxRoomSnapshot(
          id: room.id,
          label: _roomLabel(room),
          index: index,
          isCurrent: index == _currentSandboxRoomIndex,
          accentColor: room.palette.mapAccentColor,
          floorColor: room.palette.floorTileA,
          wallColor: room.palette.wallColor,
          hasLeftPortal: room.leftPortalTargetIndex != null,
          hasRightPortal: room.rightPortalTargetIndex != null,
          hasDummy: room.hasDummy,
          playerMarker: index == _currentSandboxRoomIndex
              ? _normalizedSandboxMarkerFor(_controlledHunter?.position)
              : null,
          dummyMarker: dummyMarker,
        );
      }, growable: false);

  void setLanguage(AppLanguage language) {
    if (_language == language) {
      return;
    }
    _language = language;
    _updateInteractionHint();
  }

  String _tr({required String zh, required String en}) {
    return _language == AppLanguage.english ? en : zh;
  }

  String _roomLabel(_SandboxRoomDefinition room) {
    return switch (room.id) {
      'main_bay' => _tr(zh: '主接點室', en: 'Main Link Room'),
      'mint_room' => _tr(zh: '薄荷副室', en: 'Mint Side Room'),
      _ => room.label,
    };
  }

  final void Function(TavernFurnitureType furniture)? onFurnitureInteracted;

  _SandboxRoomDefinition get _currentSandboxRoom =>
      _sandboxRooms[_currentSandboxRoomIndex];
  _SandboxRoomPalette get _currentSandboxPalette => _currentSandboxRoom.palette;

  bool get _isCompactPhoneViewport => hasLayout && size.x > 0 && size.x <= 520;

  double get _playAreaTopInset {
    if (_sandboxRoomMode) {
      return _worldSize.y * _sandboxWallRatio;
    }
    return switch (_theme) {
      TavernVisualTheme.cozyWood => _worldSize.y * 0.33,
      TavernVisualTheme.technoMinimal ||
      TavernVisualTheme.hotbloodAdventure => _baseTopWallHeight,
    };
  }

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/';
    _updateWorldForViewport(size);

    final background = RectangleComponent(
      position: Vector2.zero(),
      size: _worldSize,
      paint: Paint()..color = const Color(0xFF4A2E24),
      priority: -1000,
    );
    _background = background;
    world.add(background);
    camera.viewfinder.anchor = Anchor.center;
    _syncCameraBounds();
    camera.viewfinder.position = Vector2(_worldSize.x / 2, _worldSize.y / 2);

    final environmentLayer = _TavernEnvironmentLayer(theme: _theme)
      ..priority = -900;
    _environmentLayer = environmentLayer;
    world.add(environmentLayer);

    final floatingJoystick = _FloatingJoystickOverlay(
      baseRadius: _joystickBaseRadius,
      knobRadius: _joystickKnobRadius,
    );
    floatingJoystick.resizeTo(size);
    _floatingJoystick = floatingJoystick;
    camera.viewport.add(floatingJoystick);

    if (!_sandboxRoomMode) {
      _spawnFurniture();
    }
    _applyThemePalette();
    _layoutFurniture();
    _applyRoster();
    _syncCameraFollow(snap: true);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateWorldForViewport(size);
    _background?.size = _worldSize;
    _syncCameraBounds();
    _floatingJoystick?.resizeTo(size);
    _environmentLayer?.markDirty();
    _layoutFurniture();
    _layoutHunters();
    _syncCameraFollow(snap: true);
  }

  Offset? hunterHeadScreenAnchor(String hunterId, {double verticalLift = 34}) {
    if (!hasLayout || size.x <= 0 || size.y <= 0) {
      return null;
    }
    final hunter = _hunterSprites[hunterId];
    if (hunter == null) {
      return null;
    }
    final worldAnchor = Vector2(
      hunter.position.x,
      hunter.position.y - (hunter.size.y * 0.58) - verticalLift,
    );
    final screenAnchor = camera.localToGlobal(worldAnchor);
    final clampedX = screenAnchor.x.clamp(18, size.x - 18).toDouble();
    final clampedY = screenAnchor.y.clamp(18, size.y - 18).toDouble();
    return Offset(clampedX, clampedY);
  }

  Offset? controlledHunterHeadScreenAnchor({double verticalLift = 34}) {
    final controlledId = _controlledHunterId;
    if (controlledId == null) {
      return null;
    }
    return hunterHeadScreenAnchor(controlledId, verticalLift: verticalLift);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _stabilizeControlledHunter();
    _evictStaleRealtimeActors();
    if (_sandboxRoomMode) {
      _sandboxRelinkCooldown = math.max(0, _sandboxRelinkCooldown - dt);
      _sandboxPortalCooldown = math.max(0, _sandboxPortalCooldown - dt);
    }
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
      if (_sandboxRoomMode) {
        _updateSandboxPortal(player);
        _updateSandboxLink(player, dt);
      }
      _syncCameraFollow();
      return;
    }

    final previous = player.position.clone();
    final velocity = _joystickInput.normalized() * _heroSpeed;
    player.position += velocity * dt;
    _clampPlayerToCanvas(player);
    _resolvePlayerObstacleCollision(player, previous);
    player.setMotion(velocity, moving: true);
    if (_sandboxRoomMode) {
      _updateSandboxPortal(player);
      _updateSandboxLink(player, dt);
    }
    _syncCameraFollow();
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
    final worldTouchPoint = camera.globalToLocal(touchPoint.clone());
    if (_tryInteractFurniture(worldTouchPoint)) {
      _joystickInput.setZero();
      _floatingJoystick?.deactivate();
      _joystickMovementEngaged = false;
      return;
    }
    final floatingJoystick = _floatingJoystick;
    if (floatingJoystick == null) {
      return;
    }
    if (!floatingJoystick.containsTouch(touchPoint)) {
      _joystickInput.setZero();
      return;
    }
    floatingJoystick.activate();
    _joystickMovementEngaged = false;
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
    final engagedNow = _joystickInput.length >= _joystickDeadZone;
    if (engagedNow != _joystickMovementEngaged) {
      _joystickMovementEngaged = engagedNow;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void handlePanEnd(DragEndDetails details) {
    super.handlePanEnd(details);
    _joystickInput.setZero();
    if (_joystickMovementEngaged) {
      HapticFeedback.selectionClick();
    }
    _joystickMovementEngaged = false;
    _floatingJoystick?.deactivate();
  }

  @override
  void onPanCancel() {
    _joystickInput.setZero();
    if (_joystickMovementEngaged) {
      HapticFeedback.selectionClick();
    }
    _joystickMovementEngaged = false;
    _floatingJoystick?.deactivate();
  }

  bool interactWithNearbyFurniture() {
    return _tryInteractClosestFurniture();
  }

  @override
  void onRemove() {
    interactionHintListenable.dispose();
    activeHunterIdsListenable.dispose();
    nearbyFurnitureListenable.dispose();
    sandboxRoomIndexListenable.dispose();
    super.onRemove();
  }
}
