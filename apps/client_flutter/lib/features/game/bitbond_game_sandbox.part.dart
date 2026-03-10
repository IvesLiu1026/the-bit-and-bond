part of 'bitbond_game.dart';

extension _BitBondGameSandbox on TheBitAndBondGame {
  void _updateSandboxLink(_HeroCharacterComponent player, double dt) {
    final dummy = _dummyHunter;
    if (dummy == null || !_currentSandboxRoom.hasDummy) {
      _sandboxLinkEngaged = false;
      _sandboxLinkBreakHold = 0;
      player.clearConnectionVisual();
      return;
    }

    final dx = dummy.position.x - player.position.x;
    final dy = dummy.position.y - player.position.y;
    final playerOnLeft = dx >= 0;
    final horizontalEnough =
        dx.abs() <= TheBitAndBondGame._dummyLinkMagnetRange;
    final verticalEnough = dy.abs() <= 54;
    if (!horizontalEnough || !verticalEnough) {
      _sandboxLinkEngaged = false;
      _sandboxLinkBreakHold = 0;
      player.clearConnectionVisual();
      dummy.clearConnectionVisual();
      dummy.setMotion(Vector2(-1, 0), moving: false);
      return;
    }

    final pullAwayAxis = (player.position - dummy.position)..normalize();
    final inputDirection =
        _joystickInput.length >= TheBitAndBondGame._joystickDeadZone
        ? _joystickInput.normalized()
        : Vector2.zero();
    final pullingAway =
        _sandboxLinkEngaged &&
        !inputDirection.isZero() &&
        inputDirection.dot(pullAwayAxis) > 0.72;

    if (_sandboxLinkEngaged && pullingAway) {
      _sandboxLinkBreakHold = math.min(
        TheBitAndBondGame._dummyLinkBreakHoldSeconds,
        _sandboxLinkBreakHold + dt,
      );
      if (_sandboxLinkBreakHold >=
          TheBitAndBondGame._dummyLinkBreakHoldSeconds) {
        _sandboxLinkEngaged = false;
        _sandboxLinkBreakHold = 0;
        _sandboxRelinkCooldown = TheBitAndBondGame._dummyRelinkCooldownSeconds;
        player.position += pullAwayAxis * 34;
        _clampPlayerToCanvas(player);
        player.clearConnectionVisual();
        dummy.clearConnectionVisual();
        dummy.setMotion(Vector2(-1, 0), moving: false);
        return;
      }
    } else if (_sandboxLinkEngaged) {
      _sandboxLinkBreakHold = math.max(0, _sandboxLinkBreakHold - (dt * 1.6));
    }

    if (!_sandboxLinkEngaged &&
        _sandboxRelinkCooldown > 0 &&
        dx.abs() <= (TheBitAndBondGame._dummyLinkSpacing + 24)) {
      player.clearConnectionVisual();
      dummy.clearConnectionVisual();
      dummy.setMotion(Vector2(-1, 0), moving: false);
      return;
    }

    final targetPlayerPosition = Vector2(
      dummy.position.x +
          (playerOnLeft
              ? -TheBitAndBondGame._dummyLinkSpacing
              : TheBitAndBondGame._dummyLinkSpacing),
      dummy.position.y,
    );
    final toTarget = targetPlayerPosition - player.position;
    final targetDistance = toTarget.length;
    final pull = (dt * (pullingAway ? 2.8 : 10)).clamp(0.0, 1.0);
    player.position.x += toTarget.x * pull;
    player.position.y += toTarget.y * pull;
    _clampPlayerToCanvas(player);

    final strength = (1 - (targetDistance / 42)).clamp(0.0, 1.0).toDouble();
    _sandboxLinkEngaged =
        strength > 0.32 && _sandboxRelinkCooldown <= 0 && targetDistance <= 32;
    final playerFacing = playerOnLeft ? _HeroFacing.right : _HeroFacing.left;
    final dummyFacing = playerOnLeft ? _HeroFacing.left : _HeroFacing.right;
    player.setConnectionVisual(
      strength: strength,
      energizeLeftSocket: !playerOnLeft,
      energizeRightPlug: playerOnLeft,
      forcedFacing: playerFacing,
    );
    dummy.setConnectionVisual(
      strength: strength,
      energizeLeftSocket: playerOnLeft,
      energizeRightPlug: !playerOnLeft,
      forcedFacing: dummyFacing,
    );

    if (strength > 0.35) {
      player.setMotion(Vector2(playerOnLeft ? 1 : -1, 0), moving: false);
      dummy.setMotion(Vector2(playerOnLeft ? -1 : 1, 0), moving: false);
    }
  }

  void _updateSandboxPortal(_HeroCharacterComponent player) {
    if (_sandboxPortalCooldown > 0) {
      return;
    }
    final point = Offset(player.position.x, player.position.y);
    final leftPortal = _leftPortalRect?.inflate(8);
    if (leftPortal != null &&
        leftPortal.contains(point) &&
        _currentSandboxRoom.leftPortalTargetIndex != null) {
      _transitionToSandboxRoom(
        _currentSandboxRoom.leftPortalTargetIndex!,
        arriveFromLeft: false,
      );
      return;
    }
    final rightPortal = _rightPortalRect?.inflate(8);
    if (rightPortal != null &&
        rightPortal.contains(point) &&
        _currentSandboxRoom.rightPortalTargetIndex != null) {
      _transitionToSandboxRoom(
        _currentSandboxRoom.rightPortalTargetIndex!,
        arriveFromLeft: true,
      );
    }
  }

  void _transitionToSandboxRoom(int roomIndex, {required bool arriveFromLeft}) {
    if (roomIndex < 0 ||
        roomIndex >= TheBitAndBondGame._sandboxRooms.length ||
        roomIndex == _currentSandboxRoomIndex) {
      return;
    }
    _currentSandboxRoomIndex = roomIndex;
    sandboxRoomIndexListenable.value = roomIndex;
    _sandboxPortalCooldown = TheBitAndBondGame._portalCooldownSeconds;
    _sandboxRelinkCooldown = 0;
    _sandboxLinkEngaged = false;
    _sandboxLinkBreakHold = 0;
    _applyThemePalette();
    _environmentLayer?.markDirty();

    final player = _controlledHunter;
    if (player != null) {
      player.clearConnectionVisual();
      final spawn = _findNearestWalkablePosition(
        Vector2(
          _worldSize.x * (arriveFromLeft ? 0.22 : 0.78),
          _worldSize.y * 0.64,
        ),
        player.radius,
      );
      player.position = spawn;
      player.setMotion(Vector2(arriveFromLeft ? 1 : -1, 0), moving: false);
    }
    final dummy = _dummyHunter;
    dummy?.clearConnectionVisual();
    _layoutSandboxHunters();
    _syncCameraFollow(snap: true);
  }

  String _sandboxConnectionHint(
    _HeroCharacterComponent player,
    _HeroCharacterComponent? dummy,
  ) {
    final playerPoint = Offset(player.position.x, player.position.y);
    final leftPortal = _leftPortalRect?.inflate(14);
    if (leftPortal != null &&
        leftPortal.contains(playerPoint) &&
        _currentSandboxRoom.leftPortalTargetIndex != null) {
      return _tr(
        zh: '左側 portal 會帶你回 ${_roomLabel(TheBitAndBondGame._sandboxRooms[_currentSandboxRoom.leftPortalTargetIndex!])}',
        en: 'The left portal returns you to ${_roomLabel(TheBitAndBondGame._sandboxRooms[_currentSandboxRoom.leftPortalTargetIndex!])}',
      );
    }
    final rightPortal = _rightPortalRect?.inflate(14);
    if (rightPortal != null &&
        rightPortal.contains(playerPoint) &&
        _currentSandboxRoom.rightPortalTargetIndex != null) {
      return _tr(
        zh: '右側 portal 會帶你去 ${_roomLabel(TheBitAndBondGame._sandboxRooms[_currentSandboxRoom.rightPortalTargetIndex!])}',
        en: 'The right portal takes you to ${_roomLabel(TheBitAndBondGame._sandboxRooms[_currentSandboxRoom.rightPortalTargetIndex!])}',
      );
    }
    if (dummy == null) {
      if (_currentSandboxRoom.leftPortalTargetIndex != null) {
        return _tr(
          zh: '這間副室目前是空的，往左進 portal 可回主接點室',
          en: 'This side room is empty for now. Use the left portal to go back.',
        );
      }
      if (_currentSandboxRoom.rightPortalTargetIndex != null) {
        return _tr(
          zh: '右側 portal 已打開，先去看看新的方形空間',
          en: 'The right portal is open. Step into the new square room.',
        );
      }
      return _tr(
        zh: '左下固定搖桿可 360 度移動，在房間裡自由走動',
        en: 'Use the bottom-left joystick to move freely through the room.',
      );
    }
    final distance = (player.position - dummy.position).length;
    if (_sandboxLinkEngaged &&
        distance <= TheBitAndBondGame._dummyLinkSpacing + 18) {
      return _tr(
        zh: '已接上 Bibon，往反方向拉住一下就能解開',
        en: 'Bibon linked. Pull the opposite way for a moment to unplug.',
      );
    }
    if (_sandboxRelinkCooldown > 0 &&
        distance <= TheBitAndBondGame._dummyLinkMagnetRange) {
      return _tr(
        zh: '剛解開連結，稍微退開一點再靠近就能重新接上',
        en: 'Just unplugged. Step back a bit, then move in to relink.',
      );
    }
    if (distance <= TheBitAndBondGame._dummyLinkMagnetRange) {
      return _tr(
        zh: '靠近右側測試 Bibon，讓凸凹插頭自動吸上去',
        en: 'Move near the test Bibon so the plug and socket snap together.',
      );
    }
    if (_currentSandboxRoom.rightPortalTargetIndex != null) {
      return _tr(
        zh: '左下固定搖桿可 360 度移動，右側 portal 可前往薄荷副室',
        en: 'Use the bottom-left joystick to move. The right portal leads onward.',
      );
    }
    return _tr(
      zh: '左下固定搖桿可 360 度移動，去撞一下右邊那隻 Bibon',
      en: 'Use the bottom-left joystick to move. Try bumping into the Bibon on the right.',
    );
  }

  Rect? get _leftPortalRect {
    if (_currentSandboxRoom.leftPortalTargetIndex == null) {
      return null;
    }
    final portalWidth = _worldSize.x * 0.085;
    final floorHeight = _worldSize.y - _playAreaTopInset;
    final portalHeight = floorHeight * 0.26;
    final top = _playAreaTopInset + (floorHeight * 0.3);
    return Rect.fromLTWH(0, top, portalWidth, portalHeight);
  }

  Rect? get _rightPortalRect {
    if (_currentSandboxRoom.rightPortalTargetIndex == null) {
      return null;
    }
    final portalWidth = _worldSize.x * 0.085;
    final floorHeight = _worldSize.y - _playAreaTopInset;
    final portalHeight = floorHeight * 0.26;
    final top = _playAreaTopInset + (floorHeight * 0.3);
    return Rect.fromLTWH(
      _worldSize.x - portalWidth,
      top,
      portalWidth,
      portalHeight,
    );
  }

  Offset? _normalizedSandboxMarkerFor(Vector2? worldPosition) {
    if (worldPosition == null) {
      return null;
    }
    final minX = TheBitAndBondGame._playHorizontalPadding + 24;
    final maxX = math.max(
      minX + 1,
      _worldSize.x - TheBitAndBondGame._playHorizontalPadding - 24,
    );
    final minY = _playAreaTopInset + 12;
    final maxY = math.max(
      minY + 1,
      _worldSize.y - TheBitAndBondGame._playBottomPadding - 18,
    );
    final normalizedX = ((worldPosition.x - minX) / (maxX - minX))
        .clamp(0.08, 0.92)
        .toDouble();
    final normalizedY = ((worldPosition.y - minY) / (maxY - minY))
        .clamp(0.08, 0.92)
        .toDouble();
    return Offset(normalizedX, normalizedY);
  }
}
