part of '../game_shell_page.dart';

extension _GameShellMenu on _GameShellPageState {
  Future<void> _closeDialogThen(
    BuildContext dialogContext,
    FutureOr<void> Function() action,
  ) async {
    Navigator.of(dialogContext).pop();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted) {
      return;
    }
    await action();
  }

  Future<void> _openMainMenuDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 760,
      preferredHeight: 620,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final strings = ref.watch(appStringsProvider);
            final isMaster = ref.watch(
              authSessionProvider.select(
                (session) => session?.isGuildMaster ?? false,
              ),
            );
            final unreadCount = ref.watch(
              directMessagesControllerProvider.select(
                (state) => state.totalUnreadCount,
              ),
            );
            final compact =
                MediaQuery.sizeOf(dialogContext).width < 540 ||
                MediaQuery.sizeOf(dialogContext).height < 760;

            return _MainMenuPanel(
              strings: strings,
              compact: compact,
              isMaster: isMaster,
              directMessageUnreadCount: unreadCount,
              onClose: () => Navigator.of(dialogContext).pop(),
              onOpenTasks: () {
                return _closeDialogThen(dialogContext, _openNoticeBoardDialog);
              },
              onOpenFamilyCenter: () {
                return _closeDialogThen(
                  dialogContext,
                  isMaster ? _openMasterDeskDialog : _openGuildChestDialog,
                );
              },
              onOpenRewards: () {
                return _closeDialogThen(dialogContext, _openGuildShopDialog);
              },
              onOpenBag: () {
                return _closeDialogThen(dialogContext, _openInventoryDialog);
              },
              onOpenVoice: () {
                return _closeDialogThen(dialogContext, _openCampfireDialog);
              },
              onOpenHabits: () {
                return _closeDialogThen(dialogContext, _openHabitsDialog);
              },
              onOpenDirectMessages: () {
                return _closeDialogThen(
                  dialogContext,
                  _openDirectMessagesDialog,
                );
              },
              onOpenPhotoDump: () {
                return _closeDialogThen(dialogContext, _openPhotoDumpDialog);
              },
              onOpenProfile: () {
                return _closeDialogThen(dialogContext, _openProfileDialog);
              },
              onOpenSettings: () {
                return _closeDialogThen(dialogContext, _openSettingsDialog);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openSettingsDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 560,
      preferredHeight: 620,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final strings = ref.watch(appStringsProvider);
            final compact =
                MediaQuery.sizeOf(dialogContext).width < 520 ||
                MediaQuery.sizeOf(dialogContext).height < 760;
            return _SettingsPanel(
              strings: strings,
              compact: compact,
              currentThemeLabel: _visualThemeLabel,
              onClose: () => Navigator.of(dialogContext).pop(),
              onCycleTheme: _cycleVisualTheme,
              onLogout: () async {
                Navigator.of(dialogContext).pop();
                await _logout();
              },
            );
          },
        );
      },
    );
  }
}
