import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_session.dart';
import '../features/quests/models.dart';
import '../features/quests/quest_repository.dart';
import 'providers.dart';

final hunterDirectoryControllerProvider =
    StateNotifierProvider<
      HunterDirectoryController,
      AsyncValue<List<HunterProfile>>
    >((ref) {
      final repo = ref.watch(questRepositoryProvider);
      final authSession = ref.watch(authSessionProvider);
      return HunterDirectoryController(repo: repo, authSession: authSession)
        ..load();
    });

final selectedHunterIdProvider = StateProvider<String?>((ref) => null);

final activeHunterIdProvider = Provider<String?>((ref) {
  final authSession = ref.watch(authSessionProvider);
  if (authSession?.isHunter == true) {
    return authSession?.hunterId;
  }

  final manual = ref.watch(selectedHunterIdProvider);
  final huntersState = ref.watch(hunterDirectoryControllerProvider);

  return huntersState.maybeWhen(
    data: (hunters) {
      if (hunters.isEmpty) {
        return manual;
      }
      if (manual != null &&
          manual.isNotEmpty &&
          hunters.any((hunter) => hunter.id == manual)) {
        return manual;
      }
      return hunters.first.id;
    },
    orElse: () => manual,
  );
});

class HunterDirectoryController
    extends StateNotifier<AsyncValue<List<HunterProfile>>> {
  HunterDirectoryController({
    required QuestRepository repo,
    required AuthSession? authSession,
  }) : _repo = repo,
       _authSession = authSession,
       super(const AsyncValue.loading());

  final QuestRepository _repo;
  final AuthSession? _authSession;

  Future<void> load() async {
    final session = _authSession;
    if (session == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final hunters = await _repo.fetchGuildHunters();
      if (session.isHunter &&
          session.hunterId != null &&
          session.hunterId!.isNotEmpty) {
        final meId = session.hunterId!;
        final hasMe = hunters.any((hunter) => hunter.id == meId);
        if (!hasMe) {
          return [
            ...hunters,
            HunterProfile(
              id: meId,
              guildId: session.guildId,
              name: 'Current Hunter',
              avatarType: 'default',
              level: 1,
              xp: 0,
              coins: 0,
            ),
          ];
        }
      }
      return hunters;
    });
  }

  Future<void> refresh() async {
    await load();
  }

  Future<HunterProfile> createHunter({
    required String name,
    required String avatarType,
    required String pinCode,
  }) async {
    final created = await _repo.createHunter(
      name: name,
      avatarType: avatarType,
      pinCode: pinCode,
    );
    await refresh();
    return created;
  }

  Future<HunterProfile> resetHunterPin({
    required String hunterId,
    required String pinCode,
  }) async {
    final updated = await _repo.resetHunterPin(
      hunterId: hunterId,
      pinCode: pinCode,
    );
    await refresh();
    return updated;
  }
}
