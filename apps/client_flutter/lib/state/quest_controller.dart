import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/quests/models.dart';
import '../features/quests/quest_repository.dart';
import 'providers.dart';

final questControllerProvider =
    StateNotifierProvider<QuestController, AsyncValue<List<QuestInstance>>>((
      ref,
    ) {
      final repo = ref.watch(questRepositoryProvider);
      return QuestController(repo: repo)..load();
    });

class QuestController extends StateNotifier<AsyncValue<List<QuestInstance>>> {
  QuestController({required QuestRepository repo})
    : _repo = repo,
      super(const AsyncValue.loading());

  final QuestRepository _repo;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchQuests);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.fetchQuests);
  }

  Future<void> submitQuest(String questInstanceId, {String? note}) async {
    await _repo.submitQuest(questInstanceId: questInstanceId, note: note);
    await refresh();
  }
}
