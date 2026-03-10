part of '../game_shell_page.dart';

extension _GameShellActionsShop on _GameShellPageState {
  Future<ShopPurchaseResult> _buyShopItem({required GuildShopItem item}) async {
    final strings = ref.read(appStringsProvider);
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
        text: strings.tr(
          zh: '-${result.spentCoins} 金幣',
          en: '-${result.spentCoins} Coins',
        ),
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
}
