import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_session.dart';
import '../features/quests/models.dart';
import '../features/quests/quest_repository.dart';
import 'providers.dart';

final guardianReviewControllerProvider =
    StateNotifierProvider<
      GuardianReviewController,
      AsyncValue<List<PendingSubmission>>
    >((ref) {
      final repo = ref.watch(questRepositoryProvider);
      final authSession = ref.watch(authSessionProvider);
      return GuardianReviewController(repo: repo, authSession: authSession)
        ..load();
    });

class GuardianReviewController
    extends StateNotifier<AsyncValue<List<PendingSubmission>>> {
  GuardianReviewController({
    required QuestRepository repo,
    required AuthSession? authSession,
  }) : _repo = repo,
       _authSession = authSession,
       super(const AsyncValue.loading());

  final QuestRepository _repo;
  final AuthSession? _authSession;

  Future<void> load() async {
    if (_authSession == null || !_authSession.isGuildMaster) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadPending);
  }

  Future<void> refresh() async {
    if (_authSession == null || !_authSession.isGuildMaster) {
      state = const AsyncValue.data([]);
      return;
    }
    state = await AsyncValue.guard(_loadPending);
  }

  Future<void> approve(
    String submissionId, {
    required String hunterId,
    String? reviewNote,
  }) async {
    await _repo.reviewSubmission(
      submissionId: submissionId,
      approve: true,
      hunterId: hunterId,
      reviewNote: reviewNote,
    );
    await refresh();
  }

  Future<void> reject(String submissionId, {String? reviewNote}) async {
    await _repo.reviewSubmission(
      submissionId: submissionId,
      approve: false,
      reviewNote: reviewNote,
    );
    await refresh();
  }

  Future<List<PendingSubmission>> _loadPending() {
    return _repo.fetchGuardianPending(limit: 30);
  }
}
