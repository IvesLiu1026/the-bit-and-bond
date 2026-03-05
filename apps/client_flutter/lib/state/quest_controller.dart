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

  Future<void> submitQuest(String questInstanceId) async {
    await _repo.submitQuest(questInstanceId: questInstanceId);
    await refresh();
  }

  Future<void> createQuest({
    required String title,
    String? description,
    required int rewardXp,
    required int rewardCoins,
    required QuestStatCategory statCategory,
  }) async {
    await _repo.createQuest(
      title: title,
      description: description,
      rewardXp: rewardXp,
      rewardCoins: rewardCoins,
      statCategory: statCategory,
    );
    await refresh();
  }

  Future<QuestReviewResult> reviewQuest({
    required String questId,
    required bool approve,
    String? hunterId,
    String? reviewNote,
  }) async {
    final result = await _repo.reviewSubmission(
      submissionId: questId,
      approve: approve,
      hunterId: hunterId,
      reviewNote: reviewNote,
    );
    await refresh();
    return result;
  }
}
