part of 'chen_game.dart';

extension ChenGameHunters on TheBitAndBondGame {
  void syncHunters(
    List<HunterProfile> hunters, {
    required String? controlledHunterId,
  }) {
    _rosterHunterIds
      ..clear()
      ..addAll(
        hunters
            .map((hunter) => hunter.id.trim())
            .where((hunterId) => hunterId.isNotEmpty),
      );
    for (final hunter in hunters) {
      final hunterId = hunter.id.trim();
      if (hunterId.isEmpty) {
        continue;
      }
      _hunterAppearances[hunterId] = AvatarAppearance.fromAvatarType(
        hunter.avatarType,
      );
    }
    final normalizedControlledId = _normalizeHunterId(controlledHunterId);
    if (normalizedControlledId != null) {
      _pendingControlledHunterId = normalizedControlledId;
    }
    _applyRoster();
  }

  void setControlledHunterId(String? hunterId) {
    final normalized = _normalizeHunterId(hunterId);
    if (normalized == null || _pendingControlledHunterId == normalized) {
      return;
    }
    _pendingControlledHunterId = normalized;
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
    if (TheBitAndBondGame._sandboxRoomMode) {
      return;
    }
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
    sprite.applyNetworkPose(
      pose,
      snapToTarget: isFirstPose,
      worldSize: _worldSize,
      minYBound: _playAreaTopInset,
    );
    _initializedHunterPositions.add(pose.hunterId);
  }

  _HeroCharacterComponent? get _controlledHunter {
    final id = _controlledHunterId;
    if (id == null) {
      return null;
    }
    return _hunterSprites[id];
  }

  _HeroCharacterComponent? get _dummyHunter {
    return _hunterSprites[TheBitAndBondGame._testingDummyHunterId];
  }

  AvatarAppearance get _testingDummyAppearance => const AvatarAppearance(
    hairStyle: AvatarHairStyle.windswept,
    clothTone: AvatarClothTone.sapphire,
  );

  void _applyRoster() {
    final controlledCandidate = _normalizeHunterId(_pendingControlledHunterId);
    final targetIds = <String>{};
    if (TheBitAndBondGame._sandboxRoomMode) {
      if (controlledCandidate != null && controlledCandidate.isNotEmpty) {
        targetIds.add(controlledCandidate);
      }
      targetIds.add(TheBitAndBondGame._testingDummyHunterId);
    } else {
      targetIds.addAll(<String>{
        ..._rosterHunterIds,
        ..._realtimeOnlyHunterIds,
      });
      if (controlledCandidate != null && controlledCandidate.isNotEmpty) {
        targetIds.add(controlledCandidate);
      }
    }

    final removedIds = _hunterSprites.keys
        .where((id) => !targetIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      final sprite = _hunterSprites.remove(id);
      sprite?.removeFromParent();
      _hunterAppearances.remove(id);
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
    _syncCameraFollow(snap: true);
    _publishActiveHunterIds();
  }

  void _resolveControlledHunter() {
    if (_hunterOrder.isEmpty) {
      _controlledHunterId = null;
      return;
    }

    final preferred = _normalizeHunterId(_pendingControlledHunterId);
    if (preferred == null) {
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
    if (!hasLayout || size.x <= 0 || size.y <= 0 || _hunterOrder.isEmpty) {
      return;
    }

    if (TheBitAndBondGame._sandboxRoomMode) {
      _layoutSandboxHunters();
      return;
    }

    final controlledId = _controlledHunterId;
    if (controlledId != null) {
      final controlled = _hunterSprites[controlledId];
      if (controlled != null &&
          !_initializedHunterPositions.contains(controlledId)) {
        final preferred = _preferredControlledSpawnPoint();
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

    final center = Vector2(
      _worldSize.x / 2,
      (_playAreaTopInset + _worldSize.y) / 2,
    );
    final radius = math.max(72, math.min(_worldSize.x, _worldSize.y) * 0.24);
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

  void _layoutSandboxHunters() {
    final controlledId = _controlledHunterId;
    if (controlledId != null) {
      final controlled = _hunterSprites[controlledId];
      if (controlled != null &&
          !_initializedHunterPositions.contains(controlledId)) {
        controlled.position = _findNearestWalkablePosition(
          Vector2(_worldSize.x * 0.3, _worldSize.y * 0.64),
          controlled.radius,
        );
        _initializedHunterPositions.add(controlledId);
      }
      if (controlled != null) {
        _clampPlayerToCanvas(controlled);
      }
    }

    final dummy = _dummyHunter;
    if (dummy != null) {
      if (_currentSandboxRoom.hasDummy) {
        dummy.position = Vector2(_worldSize.x * 0.68, _worldSize.y * 0.64);
        dummy.setMotion(Vector2(-1, 0), moving: false);
      } else {
        dummy.position = Vector2(_worldSize.x * 0.5, -220);
        dummy.setMotion(Vector2.zero(), moving: false);
      }
      dummy.clearConnectionVisual();
      _initializedHunterPositions.add(TheBitAndBondGame._testingDummyHunterId);
    }
  }

  _HeroCharacterComponent? _ensureHunterSprite(
    String hunterId, {
    required bool realtimeOnly,
  }) {
    final existing = _hunterSprites[hunterId];
    if (existing != null) {
      existing.setAppearance(
        hunterId == TheBitAndBondGame._testingDummyHunterId
            ? _testingDummyAppearance
            : _hunterAppearances[hunterId] ?? AvatarAppearance.novice,
      );
      if (realtimeOnly) {
        _realtimeOnlyHunterIds.add(hunterId);
      } else {
        _realtimeOnlyHunterIds.remove(hunterId);
      }
      return existing;
    }

    final sprite = _HeroCharacterComponent(
      position: Vector2.zero(),
      appearance: hunterId == TheBitAndBondGame._testingDummyHunterId
          ? _testingDummyAppearance
          : _hunterAppearances[hunterId] ?? AvatarAppearance.novice,
      onFootprintSpawn: _spawnFootprint,
    );
    _hunterSprites[hunterId] = sprite;
    if (realtimeOnly) {
      _realtimeOnlyHunterIds.add(hunterId);
    } else {
      _realtimeOnlyHunterIds.remove(hunterId);
    }
    world.add(sprite);
    _publishActiveHunterIds();
    return sprite;
  }

  void _spawnFootprint(Vector2 position, AvatarFacing facing, bool leftFoot) {
    world.add(
      _BibonFootprintComponent(
        position: position,
        facing: facing,
        leftFoot: leftFoot,
      ),
    );
  }

  void _stabilizeControlledHunter() {
    final preferred = _normalizeHunterId(_pendingControlledHunterId);
    if (preferred == null) {
      return;
    }

    final sprite = _ensureHunterSprite(preferred, realtimeOnly: false);
    if (sprite == null) {
      return;
    }

    if (!_hunterOrder.contains(preferred)) {
      _hunterOrder = <String>[..._hunterOrder, preferred];
    }
    if (_controlledHunterId != preferred) {
      _controlledHunterId = preferred;
      for (final entry in _hunterSprites.entries) {
        entry.value.setControlled(entry.key == preferred);
      }
    }
    if (!_initializedHunterPositions.contains(preferred)) {
      final preferredCenter = _preferredControlledSpawnPoint();
      sprite.position = _findNearestWalkablePosition(
        preferredCenter,
        sprite.radius,
      );
      _initializedHunterPositions.add(preferred);
      sprite.setMotion(Vector2.zero(), moving: false);
      _syncCameraFollow(snap: true);
    }
    _publishActiveHunterIds();
  }

  void _evictStaleRealtimeActors() {
    if (TheBitAndBondGame._sandboxRoomMode) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastRealtimeGcMs < 2000) {
      return;
    }
    _lastRealtimeGcMs = nowMs;

    final staleIds = _realtimeOnlyHunterIds
        .where(
          (id) =>
              nowMs - (_lastPoseSeenAtMsByHunter[id] ?? 0) >
              TheBitAndBondGame._remoteActorTtlMs,
        )
        .toList(growable: false);
    for (final id in staleIds) {
      _realtimeOnlyHunterIds.remove(id);
      _lastServerPoseTsByHunter.remove(id);
      _lastPoseSeenAtMsByHunter.remove(id);
      if (!_rosterHunterIds.contains(id) && id != _controlledHunterId) {
        _initializedHunterPositions.remove(id);
        final sprite = _hunterSprites.remove(id);
        sprite?.removeFromParent();
      }
    }
    if (staleIds.isNotEmpty) {
      _publishActiveHunterIds();
    }
  }

  void _publishActiveHunterIds() {
    final next = <String>{
      ..._realtimeOnlyHunterIds.where(
        (id) => id != TheBitAndBondGame._testingDummyHunterId,
      ),
    };
    if (_controlledHunterId != null && _controlledHunterId!.isNotEmpty) {
      next.add(_controlledHunterId!);
    }
    final current = activeHunterIdsListenable.value;
    if (next.length == current.length && next.containsAll(current)) {
      return;
    }
    activeHunterIdsListenable.value = next;
  }

  String? _normalizeHunterId(String? hunterId) {
    final normalized = hunterId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
