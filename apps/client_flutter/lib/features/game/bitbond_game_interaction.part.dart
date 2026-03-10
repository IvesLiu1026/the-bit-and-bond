part of 'bitbond_game.dart';

extension _BitBondGameInteraction on TheBitAndBondGame {
  bool _tryInteractFurniture(Vector2 touchPoint) {
    if (TheBitAndBondGame._sandboxRoomMode) {
      return false;
    }
    if (onFurnitureInteracted == null) {
      return false;
    }
    final player = _controlledHunter;
    if (player == null) {
      return false;
    }

    for (final furniture in _furnitures.values) {
      if (!furniture.interactive) {
        continue;
      }
      if (!furniture.hit(touchPoint)) {
        continue;
      }
      final distance = furniture.distanceToInteractionZone(player.position);
      if (distance > TheBitAndBondGame._furnitureInteractDistance) {
        return false;
      }
      onFurnitureInteracted?.call(furniture.type);
      return true;
    }
    return false;
  }

  bool _tryInteractClosestFurniture() {
    if (TheBitAndBondGame._sandboxRoomMode) {
      return false;
    }
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
    if (TheBitAndBondGame._sandboxRoomMode) {
      return null;
    }
    final player = _controlledHunter;
    if (player == null) {
      return null;
    }
    InteractiveFurniture? nearest;
    var minDistance = double.infinity;
    for (final furniture in _furnitures.values) {
      if (!furniture.interactive) {
        continue;
      }
      final distance = furniture.distanceToInteractionZone(player.position);
      if (distance > TheBitAndBondGame._furnitureInteractDistance) {
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
    if (TheBitAndBondGame._sandboxRoomMode) {
      final player = _controlledHunter;
      final dummy = _currentSandboxRoom.hasDummy ? _dummyHunter : null;
      final dummyHint = (player != null)
          ? _sandboxConnectionHint(player, dummy)
          : _tr(
              zh: '左下固定搖桿可 360 度移動',
              en: 'Use the bottom-left joystick to move in 360 degrees',
            );
      if (_lastInteractionHint == dummyHint) {
        return;
      }
      _lastInteractionHint = dummyHint;
      interactionHintListenable.value = dummyHint;
      nearbyFurnitureListenable.value = null;
      return;
    }
    final nearest = _closestFurnitureForInteraction();
    if (nearbyFurnitureListenable.value != nearest?.type) {
      nearbyFurnitureListenable.value = nearest?.type;
    }
    final hint = switch (nearest?.type) {
      TavernFurnitureType.noticeBoard => _tr(
        zh: '已接近任務佈告欄，點右下互動鍵',
        en: 'Near the task board. Tap the interact button.',
      ),
      TavernFurnitureType.masterDesk => _tr(
        zh: '已接近家庭中心，點右下互動鍵',
        en: 'Near the family center. Tap the interact button.',
      ),
      TavernFurnitureType.guildChest => _tr(
        zh: '已接近共享收藏櫃，點右下互動鍵',
        en: 'Near the shared collection. Tap the interact button.',
      ),
      TavernFurnitureType.campfireBar => _tr(
        zh: '已接近語音房，點右下互動鍵',
        en: 'Near the voice room. Tap the interact button.',
      ),
      TavernFurnitureType.guildMerchant => _tr(
        zh: '已接近獎勵兌換站，點右下互動鍵',
        en: 'Near rewards. Tap the interact button.',
      ),
      TavernFurnitureType.wallBookshelf ||
      TavernFurnitureType.honorBanner ||
      TavernFurnitureType.trainingDummy => _tr(
        zh: '左下固定搖桿可 360 度移動',
        en: 'Use the bottom-left joystick to move in 360 degrees',
      ),
      null => _tr(
        zh: '左下固定搖桿可 360 度移動',
        en: 'Use the bottom-left joystick to move in 360 degrees',
      ),
    };
    if (hint == _lastInteractionHint) {
      return;
    }
    _lastInteractionHint = hint;
    interactionHintListenable.value = hint;
  }
}
