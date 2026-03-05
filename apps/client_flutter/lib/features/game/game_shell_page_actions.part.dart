part of 'game_shell_page.dart';

extension _GameShellActions on _GameShellPageState {
  void _showScrollNotice(String message) {
    if (!mounted) {
      return;
    }
    _scrollNoticeTimer?.cancel();
    _applyState(() {
      _scrollNoticeText = message;
    });
    _scrollNoticeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      _applyState(() {
        _scrollNoticeText = null;
      });
    });
  }

  void _handleGuildInviteScroll(SocialSnapshot snapshot) {
    final pendingIds = snapshot.pendingInvites
        .map((invite) => invite.id)
        .toSet();
    if (!_socialSnapshotBootstrapped) {
      _knownPendingInviteIds
        ..clear()
        ..addAll(pendingIds);
      _socialSnapshotBootstrapped = true;
      if (_activeGuildInvite == null && snapshot.pendingInvites.isNotEmpty) {
        _showSummonScroll(snapshot.pendingInvites.first);
      }
    } else {
      final newcomers = snapshot.pendingInvites
          .where((invite) => !_knownPendingInviteIds.contains(invite.id))
          .toList(growable: false);
      if (newcomers.isNotEmpty) {
        _showSummonScroll(newcomers.first);
      }
      _knownPendingInviteIds
        ..clear()
        ..addAll(pendingIds);
    }

    final active = _activeGuildInvite;
    if (active != null && !pendingIds.contains(active.id)) {
      _applyState(() {
        _activeGuildInvite = null;
      });
    }
  }

  void _showSummonScroll(GuildInviteInfo invite) {
    if (!mounted) {
      return;
    }
    _applyState(() {
      _activeGuildInvite = invite;
    });
  }

  Future<ShopPurchaseResult> _buyShopItem({required GuildShopItem item}) async {
    final key = _uuid.v4();
    final result = await ref
        .read(shopControllerProvider.notifier)
        .buy(itemId: item.id, idempotencyKey: key);

    await ref.read(shopControllerProvider.notifier).refresh();
    await ref.read(progressionControllerProvider.notifier).refresh();
    await ref.read(hunterStatsControllerProvider.notifier).refresh();
    await ref.read(hunterDirectoryControllerProvider.notifier).refresh();

    if (result.spentCoins > 0) {
      _pushFloatingReward(
        text: '-${result.spentCoins} 金幣',
        tone: const Color(0xFFF57C00),
        lane: 2,
        hunterId: result.hunterId,
      );
    }
    if (!result.replayed) {
      unawaited(SfxPlayer.instance.playCoin());
    }
    return result;
  }

  Future<InventoryUseResult> _useInventoryItem({
    required InventoryItem item,
  }) async {
    final result = await ref
        .read(inventoryControllerProvider.notifier)
        .useItem(itemId: item.itemId);

    await ref.read(inventoryControllerProvider.notifier).refresh();
    await ref.read(progressionControllerProvider.notifier).refresh();
    await ref.read(hunterStatsControllerProvider.notifier).refresh();
    await ref.read(hunterDirectoryControllerProvider.notifier).refresh();
    await ref.read(voiceChatControllerProvider.notifier).refreshChatHistory();
    unawaited(SfxPlayer.instance.playUseSuccess());

    return result;
  }

  Future<void> _setShopManageMode({required bool enabled}) async {
    await ref
        .read(shopControllerProvider.notifier)
        .refresh(includeInactive: enabled);
  }

  Future<GuildShopItem> _createShopItem({
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  }) async {
    final item = await ref
        .read(shopControllerProvider.notifier)
        .createItem(
          name: name,
          description: description,
          costCoins: costCoins,
          iconTag: iconTag,
        );
    await ref
        .read(shopControllerProvider.notifier)
        .refresh(includeInactive: true);
    return item;
  }

  Future<GuildShopItem> _updateShopItem({
    required String itemId,
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  }) async {
    final item = await ref
        .read(shopControllerProvider.notifier)
        .updateItem(
          itemId: itemId,
          name: name,
          description: description,
          costCoins: costCoins,
          iconTag: iconTag,
        );
    await ref
        .read(shopControllerProvider.notifier)
        .refresh(includeInactive: true);
    return item;
  }

  Future<void> _deactivateShopItem({required String itemId}) async {
    await ref
        .read(shopControllerProvider.notifier)
        .deactivateItem(itemId: itemId);
    await ref
        .read(shopControllerProvider.notifier)
        .refresh(includeInactive: true);
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    String? successMessage,
  }) async {
    try {
      await action();
      if (!mounted || successMessage == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('操作失敗：$error'),
          backgroundColor: AppColors.hpRuby,
        ),
      );
    }
  }

  Future<void> _refreshChildData() async {
    await _runAction(
      action: () async {
        await ref.read(questControllerProvider.notifier).refresh();
        await ref.read(progressionControllerProvider.notifier).refresh();
        await ref.read(hunterDirectoryControllerProvider.notifier).refresh();
      },
    );
  }

  Future<void> _submitQuest(String questId) async {
    await _runAction(
      action: () async {
        await ref.read(questControllerProvider.notifier).submitQuest(questId);
        await ref.read(progressionControllerProvider.notifier).refresh();
      },
      successMessage: '任務已送審',
    );
  }

  Future<void> _createQuest({
    required String title,
    String? description,
    required int rewardXp,
    required int rewardCoins,
    required QuestStatCategory statCategory,
  }) async {
    await _runAction(
      action: () async {
        await ref
            .read(questControllerProvider.notifier)
            .createQuest(
              title: title,
              description: description,
              rewardXp: rewardXp,
              rewardCoins: rewardCoins,
              statCategory: statCategory,
            );
      },
      successMessage: '已建立任務',
    );
  }

  Future<void> _reviewQuest({
    required String questId,
    required bool approve,
  }) async {
    try {
      final result = await ref
          .read(questControllerProvider.notifier)
          .reviewQuest(
            questId: questId,
            approve: approve,
            reviewNote: approve ? '核准' : '退回',
          );
      await ref.read(progressionControllerProvider.notifier).refresh();
      await ref.read(hunterStatsControllerProvider.notifier).refresh();
      if (approve && result.reward != null) {
        _triggerReviewReward(result.reward!);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? '已核准任務' : '已退回任務'),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('操作失敗：$error'),
          backgroundColor: AppColors.hpRuby,
        ),
      );
    }
  }

  Future<void> _addFriendByPlayerId(String playerId) async {
    await _runAction(
      action: () async {
        await ref
            .read(socialControllerProvider.notifier)
            .requestFriend(playerId);
      },
      successMessage: '已送出好友請求',
    );
  }

  Future<void> _inviteFriendByPlayerId(String playerId) async {
    await _runAction(
      action: () async {
        await ref
            .read(socialControllerProvider.notifier)
            .inviteToGuild(playerId);
      },
      successMessage: '已發送公會邀請',
    );
  }

  Future<void> _respondGuildInvite({
    required String inviteId,
    required bool accept,
  }) async {
    await _runAction(
      action: () async {
        await ref
            .read(socialControllerProvider.notifier)
            .respondInvite(inviteId: inviteId, accept: accept);
        await ref.read(hunterDirectoryControllerProvider.notifier).refresh();
        await ref.read(progressionControllerProvider.notifier).refresh();
      },
      successMessage: accept ? '已加入公會' : '已拒絕邀請',
    );
    if (_activeGuildInvite?.id == inviteId && mounted) {
      _applyState(() {
        _activeGuildInvite = null;
      });
    }
  }

  Future<void> _respondFriendRequest({
    required String requestId,
    required bool accept,
  }) async {
    await _runAction(
      action: () async {
        await ref
            .read(socialControllerProvider.notifier)
            .respondFriendRequest(requestId: requestId, accept: accept);
      },
      successMessage: accept ? '已接受好友請求' : '已拒絕好友請求',
    );
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _savePlayerMotto(String motto) async {
    await _runAction(
      action: () async {
        await ref.read(socialControllerProvider.notifier).updateMotto(motto);
      },
      successMessage: '已更新個人格言',
    );
  }

  void _cycleVisualTheme() {
    final next = switch (_visualTheme) {
      TavernVisualTheme.cozyWood => TavernVisualTheme.technoMinimal,
      TavernVisualTheme.technoMinimal => TavernVisualTheme.hotbloodAdventure,
      TavernVisualTheme.hotbloodAdventure => TavernVisualTheme.cozyWood,
    };
    _applyState(() {
      _visualTheme = next;
    });
    _game.setVisualTheme(next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('主題已切換：$_visualThemeLabel'),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
  }

  String get _visualThemeLabel {
    return switch (_visualTheme) {
      TavernVisualTheme.cozyWood => '溫馨木質',
      TavernVisualTheme.technoMinimal => '科技簡約',
      TavernVisualTheme.hotbloodAdventure => '熱血冒險',
    };
  }

  String get _interactButtonLabel {
    return switch (_nearbyFurniture) {
      TavernFurnitureType.noticeBoard => '查看懸賞',
      TavernFurnitureType.masterDesk => '書桌操作',
      TavernFurnitureType.guildChest => '打開儲物箱',
      TavernFurnitureType.campfireBar => '營火連線',
      TavernFurnitureType.guildMerchant => '打開商店',
      null => '互動',
    };
  }

  void _interactNearbyFurniture() {
    final done = _game.interactWithNearbyFurniture();
    if (!done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先靠近家具再互動'),
          duration: Duration(milliseconds: 900),
        ),
      );
    }
  }
}
