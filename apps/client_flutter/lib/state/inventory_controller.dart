import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/quests/models.dart';
import '../features/quests/quest_repository.dart';
import 'providers.dart';

final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, AsyncValue<List<InventoryItem>>>(
      (ref) {
        final repo = ref.watch(questRepositoryProvider);
        return InventoryController(repo: repo)..load();
      },
    );

class InventoryController
    extends StateNotifier<AsyncValue<List<InventoryItem>>> {
  InventoryController({required QuestRepository repo})
    : _repo = repo,
      super(const AsyncValue.loading());

  final QuestRepository _repo;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchInventoryItems);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.fetchInventoryItems);
  }

  Future<InventoryUseResult> useItem({required String itemId}) {
    return _repo.useInventoryItem(itemId: itemId);
  }
}
