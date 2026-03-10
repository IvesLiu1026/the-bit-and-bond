part of '../game_shell_page.dart';

extension _GameShellActionsQuestsSocial on _GameShellPageState {
  Future<void> _submitQuest(
    String questId, {
    String? proofNote,
    QuestProofUpload? proofMedia,
    bool rethrowOnError = false,
  }) async {
    final strings = ref.read(appStringsProvider);
    await _runAction(
      action: () async {
        await ref
            .read(questControllerProvider.notifier)
            .submitQuest(questId, proofNote: proofNote, proofMedia: proofMedia);
        await ref.read(progressionControllerProvider.notifier).refresh();
      },
      successMessage: strings.tr(zh: '任務已送審', en: 'Task submitted for review'),
      rethrowOnError: rethrowOnError,
    );
  }

  Future<void> _submitHabitQuest(
    String questId, {
    String? proofNote,
    QuestProofUpload? proofMedia,
  }) {
    return _submitQuest(
      questId,
      proofNote: proofNote,
      proofMedia: proofMedia,
      rethrowOnError: true,
    );
  }

  Future<void> _createQuest({
    required String title,
    String? description,
    required int rewardXp,
    required int rewardCoins,
    required QuestStatCategory statCategory,
    QuestCategory category = QuestCategory.chore,
    String? assignedHunterId,
    HabitCadence cadence = HabitCadence.none,
  }) async {
    final strings = ref.read(appStringsProvider);
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
              category: category,
              assignedHunterId: assignedHunterId,
              cadence: cadence,
            );
      },
      successMessage: strings.tr(zh: '已建立任務', en: 'Task created'),
    );
  }

  Future<void> _reviewQuest({
    required String questId,
    required bool approve,
  }) async {
    final strings = ref.read(appStringsProvider);
    try {
      final result = await ref
          .read(questControllerProvider.notifier)
          .reviewQuest(
            questId: questId,
            approve: approve,
            reviewNote: approve
                ? strings.tr(zh: '核准', en: 'Approved')
                : strings.tr(zh: '退回', en: 'Returned'),
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
          content: Text(
            approve
                ? strings.tr(zh: '已核准任務', en: 'Task approved')
                : strings.tr(zh: '已退回任務', en: 'Task returned'),
          ),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (error) {
      await _handleSessionExpiryIfNeeded(ref, error);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyShellErrorMessage(
              strings: strings,
              error: error,
              prefix: strings.tr(zh: '操作失敗。', en: 'Action failed.'),
            ),
          ),
          backgroundColor: AppColors.hpRuby,
        ),
      );
    }
  }

  Future<void> _addFriendByPlayerId(String playerId) async {
    final strings = ref.read(appStringsProvider);
    await _runAction(
      action: () async {
        await ref
            .read(socialControllerProvider.notifier)
            .requestFriend(playerId);
      },
      successMessage: strings.tr(zh: '已送出好友請求', en: 'Friend request sent'),
    );
  }

  Future<void> _inviteFriendByPlayerId(String playerId) async {
    final strings = ref.read(appStringsProvider);
    await _runAction(
      action: () async {
        await ref
            .read(socialControllerProvider.notifier)
            .inviteToGuild(playerId);
      },
      successMessage: strings.tr(zh: '已發送公會邀請', en: 'Family invite sent'),
    );
  }

  Future<void> _respondGuildInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final strings = ref.read(appStringsProvider);
    await _runAction(
      action: () async {
        await ref
            .read(socialControllerProvider.notifier)
            .respondInvite(inviteId: inviteId, accept: accept);
        await ref.read(hunterDirectoryControllerProvider.notifier).refresh();
        await ref.read(progressionControllerProvider.notifier).refresh();
      },
      successMessage: accept
          ? strings.tr(zh: '已加入公會', en: 'Joined family')
          : strings.tr(zh: '已拒絕邀請', en: 'Invite declined'),
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
    final strings = ref.read(appStringsProvider);
    await _runAction(
      action: () async {
        await ref
            .read(socialControllerProvider.notifier)
            .respondFriendRequest(requestId: requestId, accept: accept);
      },
      successMessage: accept
          ? strings.tr(zh: '已接受好友請求', en: 'Friend request accepted')
          : strings.tr(zh: '已拒絕好友請求', en: 'Friend request declined'),
    );
  }
}
