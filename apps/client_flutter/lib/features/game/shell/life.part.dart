part of '../game_shell_page.dart';

extension _GameShellLifestylePanels on _GameShellPageState {
  Future<void> _openHabitsDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 720,
      preferredHeight: 660,
      builder: (context) {
        final questsState = ref.watch(questControllerProvider);
        final huntersState = ref.watch(hunterDirectoryControllerProvider);
        final session = ref.watch(authSessionProvider);
        final config = ref.watch(appConfigProvider);
        final activeHunterId = ref.watch(activeHunterIdProvider);
        return _HabitsPanel(
          questsState: questsState,
          huntersState: huntersState,
          activeHunterId: activeHunterId,
          isMaster: session?.isGuildMaster ?? false,
          apiBaseUrl: config.apiBaseUrl,
          authToken: session?.accessToken,
          onCreateHabit: _createQuest,
          onSubmitHabit: _submitQuest,
          onReviewHabit: _reviewQuest,
        );
      },
    );
  }

  Future<void> _openDirectMessagesDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 560,
      preferredHeight: 640,
      builder: (context) => const _DirectMessagesPanel(),
    );
  }

  Future<void> _openPhotoDumpDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 680,
      preferredHeight: 620,
      builder: (context) => const _PhotoDumpPanel(),
    );
  }
}
