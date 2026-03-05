import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/quests/models.dart';
import '../features/quests/quest_repository.dart';
import 'hunter_directory_controller.dart';
import 'providers.dart';

final progressionControllerProvider =
    StateNotifierProvider<ProgressionController, AsyncValue<Progression>>(
      (ref) {
        final repo = ref.watch(questRepositoryProvider);
        final selectedHunterId = ref.watch(activeHunterIdProvider);
        return ProgressionController(
          repo: repo,
          selectedHunterId: selectedHunterId,
        )..load();
      },
    );

class ProgressionController
    extends StateNotifier<AsyncValue<Progression>> {
  ProgressionController({
    required QuestRepository repo,
    required String? selectedHunterId,
  }) : _repo = repo,
       _selectedHunterId = selectedHunterId,
       super(const AsyncValue.loading());

  final QuestRepository _repo;
  final String? _selectedHunterId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadBundle);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_loadBundle);
  }

  Future<Progression> _loadBundle() async {
    return _repo.fetchProgression(hunterId: _selectedHunterId);
  }
}
