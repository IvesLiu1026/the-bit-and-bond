part of 'game_shell_page.dart';

extension _GameShellRewards on _GameShellPageState {
  void _triggerReviewReward(QuestReviewReward reward) {
    if (!_consumedRewardEventIds.add(reward.rewardEventId)) {
      return;
    }
    if (reward.gainedXp > 0) {
      _pushFloatingReward(
        text: '+${reward.gainedXp} XP',
        tone: const Color(0xFF42A5F5),
        lane: 0,
        hunterId: reward.hunterId,
      );
    }
    if (reward.gainedCoins > 0) {
      _pushFloatingReward(
        text: '+${reward.gainedCoins} 金幣',
        tone: const Color(0xFFF9A825),
        lane: 1,
        hunterId: reward.hunterId,
      );
    }
    if (reward.leveledUp) {
      _showLevelUpDialog(reward.newLevel);
    }
  }

  void _pushFloatingReward({
    required String text,
    required Color tone,
    required int lane,
    required String hunterId,
  }) {
    if (!mounted) {
      return;
    }
    final event = _FloatingRewardEvent(
      id: 'reward_${_floatingRewardSeed++}',
      text: text,
      tone: tone,
      hunterId: hunterId,
      lane: lane,
    );
    _applyState(() {
      _floatingRewardEvents.add(event);
    });
  }

  Offset _resolveRewardAnchor({required String hunterId, required int lane}) {
    final screen = MediaQuery.sizeOf(context);
    const halfTextWidth = 130.0;
    final anchor =
        _game.hunterHeadScreenAnchor(hunterId) ??
        _game.controlledHunterHeadScreenAnchor();
    if (anchor != null) {
      final x = anchor.dx.clamp(halfTextWidth, screen.width - halfTextWidth);
      return Offset(x.toDouble(), anchor.dy + (lane * 20));
    }
    return Offset(screen.width * 0.5, (screen.height * 0.22) + (lane * 20));
  }

  void _removeFloatingReward(String id) {
    if (!mounted) {
      return;
    }
    _applyState(() {
      _floatingRewardEvents.removeWhere((event) => event.id == id);
    });
  }

  void _showLevelUpDialog(int newLevel) {
    if (!mounted || _showingLevelUpDialog) {
      return;
    }
    _showingLevelUpDialog = true;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _LevelUpDialog(newLevel: newLevel),
    ).whenComplete(() {
      _showingLevelUpDialog = false;
    });
  }
}
