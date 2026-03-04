import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/quests/models.dart';
import '../features/quests/quest_repository.dart';
import 'hunter_directory_controller.dart';
import 'providers.dart';

class ProgressionBundle {
  const ProgressionBundle({required this.progression, required this.ledger});

  final Progression progression;
  final List<LedgerEntry> ledger;
}

final progressionControllerProvider =
    StateNotifierProvider<ProgressionController, AsyncValue<ProgressionBundle>>(
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
    extends StateNotifier<AsyncValue<ProgressionBundle>> {
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

  Future<ProgressionBundle> _loadBundle() async {
    final progression = await _repo.fetchProgression(
      hunterId: _selectedHunterId,
    );
    final ledger = await _repo.fetchLedger(progression.childMemberId);
    return ProgressionBundle(progression: progression, ledger: ledger);
  }
}
