import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/quests/models.dart';
import '../features/quests/quest_repository.dart';
import 'providers.dart';

final shopControllerProvider =
    StateNotifierProvider<ShopController, AsyncValue<List<GuildShopItem>>>((
      ref,
    ) {
      final repo = ref.watch(questRepositoryProvider);
      return ShopController(repo: repo)..load();
    });

class ShopController extends StateNotifier<AsyncValue<List<GuildShopItem>>> {
  ShopController({required QuestRepository repo})
    : _repo = repo,
      super(const AsyncValue.loading());

  final QuestRepository _repo;
  bool _includeInactive = false;

  Future<void> load({bool includeInactive = false}) async {
    _includeInactive = includeInactive;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.fetchShopItems(includeInactive: includeInactive),
    );
  }

  Future<void> refresh({bool? includeInactive}) async {
    if (includeInactive != null) {
      _includeInactive = includeInactive;
    }
    state = await AsyncValue.guard(
      () => _repo.fetchShopItems(includeInactive: _includeInactive),
    );
  }

  Future<ShopPurchaseResult> buy({
    required String itemId,
    required String idempotencyKey,
  }) {
    return _repo.buyShopItem(itemId: itemId, idempotencyKey: idempotencyKey);
  }

  Future<GuildShopItem> createItem({
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  }) {
    return _repo.createShopItem(
      name: name,
      description: description,
      costCoins: costCoins,
      iconTag: iconTag,
    );
  }

  Future<GuildShopItem> updateItem({
    required String itemId,
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  }) {
    return _repo.updateShopItem(
      itemId: itemId,
      name: name,
      description: description,
      costCoins: costCoins,
      iconTag: iconTag,
    );
  }

  Future<GuildShopItem> deactivateItem({required String itemId}) {
    return _repo.deactivateShopItem(itemId: itemId);
  }
}
