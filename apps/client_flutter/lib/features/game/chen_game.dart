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

part 'chen_game_models.part.dart';
part 'chen_game_environment.part.dart';
part 'chen_game_furniture.part.dart';
part 'chen_game_character.part.dart';
part 'chen_game_joystick.part.dart';
part 'chen_game_interaction.part.dart';
part 'chen_game_hunters.part.dart';
part 'chen_game_sandbox.part.dart';

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

  void _updateWorldForViewport(Vector2 viewportSize) {
    if (viewportSize.x <= 0 || viewportSize.y <= 0) {
      return;
    }
    if (_sandboxRoomMode) {
      final squareSize = math.max(
        980,
        math.max(viewportSize.x, viewportSize.y) * 1.14,
      );
      _worldSize = Vector2.all(squareSize.floorToDouble());
      return;
    }
    if (_theme == TavernVisualTheme.cozyWood) {
      final compactPhone = viewportSize.x <= 520;
      final minHeight = viewportSize.y * (compactPhone ? 1.28 : 1.12);
      var targetWidth = math.max(
        _baseWorldWidth,
        viewportSize.x * (compactPhone ? 1.6 : 1.45),
      );
      var targetHeight = targetWidth / _cozyBackdropAspectRatio;
      if (targetHeight < minHeight) {
        targetHeight = minHeight;
        targetWidth = targetHeight * _cozyBackdropAspectRatio;
      }
      _worldSize = Vector2(
        targetWidth.floorToDouble(),
        targetHeight.floorToDouble(),
      );
      return;
    }

    final targetWidth = math.max(_baseWorldWidth, viewportSize.x * 1.7);
    final targetHeight = math.max(_baseWorldHeight, viewportSize.y * 1.7);
    _worldSize = Vector2(
      targetWidth.floorToDouble(),
      targetHeight.floorToDouble(),
    );
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
    if (_sandboxRoomMode) {
      _background?.paint.color = _currentSandboxPalette.backgroundColor;
      return;
    }
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
        TavernFurnitureType.wallBookshelf: (
          Color(0xFF6D4C41),
          Color(0xFFD7B56D),
        ),
        TavernFurnitureType.honorBanner: (Color(0xFF5D4037), Color(0xFF2E7D32)),
        TavernFurnitureType.trainingDummy: (
          Color(0xFF795548),
          Color(0xFFE6B04A),
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
        TavernFurnitureType.wallBookshelf: (
          Color(0xFF2C3E50),
          Color(0xFF7FDBFF),
        ),
        TavernFurnitureType.honorBanner: (Color(0xFF203040), Color(0xFF00BCD4)),
        TavernFurnitureType.trainingDummy: (
          Color(0xFF455A64),
          Color(0xFF00ACC1),
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
        TavernFurnitureType.wallBookshelf: (
          Color(0xFF6D2C22),
          Color(0xFFFFB74D),
        ),
        TavernFurnitureType.honorBanner: (Color(0xFF5D1F18), Color(0xFFD32F2F)),
        TavernFurnitureType.trainingDummy: (
          Color(0xFF7A3F23),
          Color(0xFFFFA726),
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

  void _spawnFurniture() {
    if (_sandboxRoomMode) {
      return;
    }
    if (_furnitures.isNotEmpty) {
      return;
    }

    final noticeBoard = InteractiveFurniture(
      type: TavernFurnitureType.noticeBoard,
      label: '任務佈告欄',
      size: Vector2(186, 94),
      tint: const Color(0xFF8D6E63),
      accent: const Color(0xFFD4AF37),
      collidable: false,
      renderMode: FurnitureRenderMode.hotspot,
    );
    final masterDesk = InteractiveFurniture(
      type: TavernFurnitureType.masterDesk,
      label: '家庭中心',
      size: Vector2(160, 86),
      tint: const Color(0xFF6D4C41),
      accent: const Color(0xFF9E7D5A),
      renderMode: FurnitureRenderMode.hotspot,
    );
    final guildChest = InteractiveFurniture(
      type: TavernFurnitureType.guildChest,
      label: '共享收藏櫃',
      size: Vector2(118, 82),
      tint: const Color(0xFF5D4037),
      accent: const Color(0xFFC9A227),
    );
    final campfireBar = InteractiveFurniture(
      type: TavernFurnitureType.campfireBar,
      label: '語音房',
      size: Vector2(126, 90),
      tint: const Color(0xFF4E342E),
      accent: const Color(0xFFFFB74D),
      renderMode: FurnitureRenderMode.flameOverlay,
    );
    final guildMerchant = InteractiveFurniture(
      type: TavernFurnitureType.guildMerchant,
      label: '獎勵兌換站',
      size: Vector2(128, 86),
      tint: const Color(0xFF5E3F2A),
      accent: const Color(0xFFCF9E2D),
      renderMode: FurnitureRenderMode.hotspot,
    );
    final wallBookshelf = InteractiveFurniture(
      type: TavernFurnitureType.wallBookshelf,
      label: '藏書書架',
      size: Vector2(90, 82),
      tint: const Color(0xFF6D4C41),
      accent: const Color(0xFFD7B56D),
      interactive: false,
      collidable: false,
      renderMode: FurnitureRenderMode.hotspot,
      showLabel: false,
    );
    final honorBanner = InteractiveFurniture(
      type: TavernFurnitureType.honorBanner,
      label: '公會旗幟',
      size: Vector2(76, 112),
      tint: const Color(0xFF5D4037),
      accent: const Color(0xFF2E7D32),
      interactive: false,
      collidable: false,
      renderMode: FurnitureRenderMode.hotspot,
      showLabel: false,
    );
    final trainingDummy = InteractiveFurniture(
      type: TavernFurnitureType.trainingDummy,
      label: '訓練木樁',
      size: Vector2(82, 110),
      tint: const Color(0xFF795548),
      accent: const Color(0xFFE6B04A),
      interactive: false,
      collidable: false,
      renderMode: FurnitureRenderMode.hotspot,
      showLabel: false,
    );

    _furnitures[TavernFurnitureType.noticeBoard] = noticeBoard;
    _furnitures[TavernFurnitureType.masterDesk] = masterDesk;
    _furnitures[TavernFurnitureType.guildChest] = guildChest;
    _furnitures[TavernFurnitureType.campfireBar] = campfireBar;
    _furnitures[TavernFurnitureType.guildMerchant] = guildMerchant;
    _furnitures[TavernFurnitureType.wallBookshelf] = wallBookshelf;
    _furnitures[TavernFurnitureType.honorBanner] = honorBanner;
    _furnitures[TavernFurnitureType.trainingDummy] = trainingDummy;

    world.add(noticeBoard);
    world.add(masterDesk);
    world.add(guildChest);
    world.add(campfireBar);
    world.add(guildMerchant);
    world.add(wallBookshelf);
    world.add(honorBanner);
    world.add(trainingDummy);
  }

  void _layoutFurniture() {
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    if (_sandboxRoomMode) {
      _rebuildObstacleRects();
      return;
    }
    final noticeBoard = _furnitures[TavernFurnitureType.noticeBoard];
    final masterDesk = _furnitures[TavernFurnitureType.masterDesk];
    final guildChest = _furnitures[TavernFurnitureType.guildChest];
    final campfireBar = _furnitures[TavernFurnitureType.campfireBar];
    final guildMerchant = _furnitures[TavernFurnitureType.guildMerchant];
    final wallBookshelf = _furnitures[TavernFurnitureType.wallBookshelf];
    final honorBanner = _furnitures[TavernFurnitureType.honorBanner];
    final trainingDummy = _furnitures[TavernFurnitureType.trainingDummy];
    if (noticeBoard == null ||
        masterDesk == null ||
        guildChest == null ||
        campfireBar == null ||
        guildMerchant == null ||
        wallBookshelf == null ||
        honorBanner == null ||
        trainingDummy == null) {
      return;
    }

    if (_theme == TavernVisualTheme.cozyWood) {
      final noticeBoardRect = _cozyWorldRect(0.29, 0.16, 0.18, 0.18);
      final masterDeskRect = _cozyWorldRect(0.53, 0.29, 0.19, 0.13);
      final guildChestRect = _cozyWorldRect(0.05, 0.82, 0.1, 0.1);
      final campfireRect = _cozyWorldRect(0.44, 0.56, 0.13, 0.11);
      final merchantRect = _cozyWorldRect(0.82, 0.19, 0.12, 0.18);
      final bookshelfRect = _cozyWorldRect(0.77, 0.13, 0.17, 0.17);
      final bannerRect = _cozyWorldRect(0.58, 0.09, 0.11, 0.15);
      final loungePropRect = _cozyWorldRect(0.08, 0.7, 0.12, 0.12);

      noticeBoard
        ..position = Vector2(noticeBoardRect.left, noticeBoardRect.top)
        ..size = Vector2(noticeBoardRect.width, noticeBoardRect.height);
      masterDesk
        ..position = Vector2(masterDeskRect.left, masterDeskRect.top)
        ..size = Vector2(masterDeskRect.width, masterDeskRect.height);
      guildChest
        ..position = Vector2(guildChestRect.left, guildChestRect.top)
        ..size = Vector2(guildChestRect.width, guildChestRect.height);
      campfireBar
        ..position = Vector2(campfireRect.left, campfireRect.top)
        ..size = Vector2(campfireRect.width, campfireRect.height);
      guildMerchant
        ..position = Vector2(merchantRect.left, merchantRect.top)
        ..size = Vector2(merchantRect.width, merchantRect.height);
      wallBookshelf
        ..position = Vector2(bookshelfRect.left, bookshelfRect.top)
        ..size = Vector2(bookshelfRect.width, bookshelfRect.height);
      honorBanner
        ..position = Vector2(bannerRect.left, bannerRect.top)
        ..size = Vector2(bannerRect.width, bannerRect.height);
      trainingDummy
        ..position = Vector2(loungePropRect.left, loungePropRect.top)
        ..size = Vector2(loungePropRect.width, loungePropRect.height);

      _rebuildObstacleRects();
      return;
    }

    noticeBoard.position = Vector2(34, _baseTopWallHeight + 14);
    masterDesk.position = Vector2(
      _worldSize.x - masterDesk.size.x - 34,
      _baseTopWallHeight + 24,
    );
    guildChest.position = Vector2(34, _worldSize.y - guildChest.size.y - 36);
    campfireBar.position = Vector2(
      _worldSize.x - campfireBar.size.x - 250,
      _worldSize.y - campfireBar.size.y - 38,
    );
    guildMerchant.position = Vector2(
      _worldSize.x - guildMerchant.size.x - 36,
      _worldSize.y - guildMerchant.size.y - 34,
    );
    wallBookshelf.position = Vector2(
      _worldSize.x - wallBookshelf.size.x - 38,
      _baseTopWallHeight + 8,
    );
    honorBanner.position = Vector2(10, _baseTopWallHeight + 4);
    trainingDummy.position = Vector2(
      _worldSize.x * 0.38,
      _worldSize.y - trainingDummy.size.y - 40,
    );
    _rebuildObstacleRects();
  }

  void _rebuildObstacleRects() {
    _obstacleRects.clear();
    if (_sandboxRoomMode) {
      return;
    }
    for (final furniture in _furnitures.values) {
      if (!furniture.collidable) {
        continue;
      }
      _obstacleRects.add(furniture.collisionRect);
    }

    if (_theme == TavernVisualTheme.cozyWood) {
      _obstacleRects.addAll(<Rect>[
        _cozyWorldRect(0.0, 0.28, 0.17, 0.12),
        _cozyWorldRect(0.08, 0.43, 0.23, 0.12),
        _cozyWorldRect(0.48, 0.55, 0.18, 0.16),
        _cozyWorldRect(0.82, 0.49, 0.16, 0.15),
        _cozyWorldRect(0.84, 0.77, 0.14, 0.12),
      ]);
      return;
    }

    final table = _centerTableRect().deflate(8);
    _obstacleRects.add(table);
    _obstacleRects.add(
      Rect.fromLTWH(table.left - 42, table.center.dy - 18, 30, 36),
    );
    _obstacleRects.add(
      Rect.fromLTWH(table.right + 12, table.center.dy - 18, 30, 36),
    );
  }

  Rect _centerTableRect() {
    final width = math.max(180, _worldSize.x * 0.16).toDouble();
    final height = 74.0;
    return Rect.fromCenter(
      center: Offset(_worldSize.x / 2, (_worldSize.y / 2) + 52),
      width: width,
      height: height,
    );
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

  void _clampPlayerToCanvas(_HeroCharacterComponent player) {
    final minX = _playHorizontalPadding + player.radius;
    final maxX = math.max(
      minX,
      _worldSize.x - _playHorizontalPadding - player.radius,
    );
    final minY = _playAreaTopInset + player.radius + 6;
    final maxY = math.max(
      minY,
      _worldSize.y - _playBottomPadding - player.radius,
    );

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

    return Vector2(_worldSize.x / 2, _worldSize.y - 120);
  }

  void _clampProbeToCanvas(Vector2 probe, double radius) {
    final minX = _playHorizontalPadding + radius;
    final maxX = math.max(minX, _worldSize.x - _playHorizontalPadding - radius);
    final minY = _playAreaTopInset + radius + 6;
    final maxY = math.max(minY, _worldSize.y - _playBottomPadding - radius);
    probe
      ..x = probe.x.clamp(minX, maxX).toDouble()
      ..y = probe.y.clamp(minY, maxY).toDouble();
  }

  Rect _cozyWorldRect(double left, double top, double width, double height) {
    return Rect.fromLTWH(
      _worldSize.x * left,
      _worldSize.y * top,
      _worldSize.x * width,
      _worldSize.y * height,
    );
  }

  Vector2 _preferredControlledSpawnPoint() {
    final playableHeight = math.max(0.0, _worldSize.y - _playAreaTopInset);
    if (_sandboxRoomMode) {
      return Vector2(_worldSize.x * 0.3, _worldSize.y * 0.64);
    }
    final verticalFactor = _isCompactPhoneViewport ? 0.34 : 0.5;
    return Vector2(
      _worldSize.x / 2,
      _playAreaTopInset + (playableHeight * verticalFactor),
    );
  }

  void _syncCameraBounds() {
    if (!hasLayout || size.x <= 0 || size.y <= 0) {
      return;
    }
    camera.setBounds(
      Rectangle.fromLTWH(0, 0, _worldSize.x, _worldSize.y),
      considerViewport: true,
    );
  }

  void _syncCameraFollow({bool snap = false}) {
    if (!hasLayout || size.x <= 0 || size.y <= 0) {
      return;
    }
    final controlled = _controlledHunter;
    final controlledId = _controlledHunterId;
    if (controlled == null || controlledId == null) {
      _cameraTrackingHunterId = null;
      camera.stop();
      camera.viewfinder.position.setValues(_worldSize.x / 2, _worldSize.y / 2);
      return;
    }
    if (_cameraTrackingHunterId == controlledId && !snap) {
      return;
    }
    _cameraTrackingHunterId = controlledId;
    camera.follow(controlled, snap: snap);
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
