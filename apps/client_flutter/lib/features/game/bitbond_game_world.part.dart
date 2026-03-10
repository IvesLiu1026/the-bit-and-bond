part of 'bitbond_game.dart';

extension BitBondGameWorld on TheBitAndBondGame {
  void _updateWorldForViewport(Vector2 viewportSize) {
    if (viewportSize.x <= 0 || viewportSize.y <= 0) {
      return;
    }
    if (TheBitAndBondGame._sandboxRoomMode) {
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
        TheBitAndBondGame._baseWorldWidth,
        viewportSize.x * (compactPhone ? 1.6 : 1.45),
      );
      var targetHeight =
          targetWidth / TheBitAndBondGame._cozyBackdropAspectRatio;
      if (targetHeight < minHeight) {
        targetHeight = minHeight;
        targetWidth = targetHeight * TheBitAndBondGame._cozyBackdropAspectRatio;
      }
      _worldSize = Vector2(
        targetWidth.floorToDouble(),
        targetHeight.floorToDouble(),
      );
      return;
    }

    final targetWidth = math.max(
      TheBitAndBondGame._baseWorldWidth,
      viewportSize.x * 1.7,
    );
    final targetHeight = math.max(
      TheBitAndBondGame._baseWorldHeight,
      viewportSize.y * 1.7,
    );
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
    if (TheBitAndBondGame._sandboxRoomMode) {
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
    if (TheBitAndBondGame._sandboxRoomMode) {
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
    if (TheBitAndBondGame._sandboxRoomMode) {
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

    noticeBoard.position = Vector2(
      34,
      TheBitAndBondGame._baseTopWallHeight + 14,
    );
    masterDesk.position = Vector2(
      _worldSize.x - masterDesk.size.x - 34,
      TheBitAndBondGame._baseTopWallHeight + 24,
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
      TheBitAndBondGame._baseTopWallHeight + 8,
    );
    honorBanner.position = Vector2(
      10,
      TheBitAndBondGame._baseTopWallHeight + 4,
    );
    trainingDummy.position = Vector2(
      _worldSize.x * 0.38,
      _worldSize.y - trainingDummy.size.y - 40,
    );
    _rebuildObstacleRects();
  }

  void _rebuildObstacleRects() {
    _obstacleRects.clear();
    if (TheBitAndBondGame._sandboxRoomMode) {
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

  void _clampPlayerToCanvas(_HeroCharacterComponent player) {
    final minX = TheBitAndBondGame._playHorizontalPadding + player.radius;
    final maxX = math.max(
      minX,
      _worldSize.x - TheBitAndBondGame._playHorizontalPadding - player.radius,
    );
    final minY = _playAreaTopInset + player.radius + 6;
    final maxY = math.max(
      minY,
      _worldSize.y - TheBitAndBondGame._playBottomPadding - player.radius,
    );

    player.position
      ..x = player.position.x.clamp(minX, maxX).toDouble()
      ..y = player.position.y.clamp(minY, maxY).toDouble();
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
    final minX = TheBitAndBondGame._playHorizontalPadding + radius;
    final maxX = math.max(
      minX,
      _worldSize.x - TheBitAndBondGame._playHorizontalPadding - radius,
    );
    final minY = _playAreaTopInset + radius + 6;
    final maxY = math.max(
      minY,
      _worldSize.y - TheBitAndBondGame._playBottomPadding - radius,
    );
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
    if (TheBitAndBondGame._sandboxRoomMode) {
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
}
