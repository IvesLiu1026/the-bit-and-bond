part of '../game_shell_page.dart';

extension _GameShellActionsProfileVoice on _GameShellPageState {
  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _leaveVoiceQuick() async {
    final strings = ref.read(appStringsProvider);
    await ref.read(voiceChatControllerProvider.notifier).leaveVoice();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.tr(zh: '已離開語音房', en: 'Left voice room')),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _savePlayerMotto(String motto) async {
    final strings = ref.read(appStringsProvider);
    await _runAction(
      action: () async {
        await ref.read(socialControllerProvider.notifier).updateMotto(motto);
      },
      successMessage: strings.tr(zh: '已更新個人格言', en: 'Motto updated'),
    );
  }

  void _cycleVisualTheme() {
    final next = switch (_visualTheme) {
      TavernVisualTheme.cozyWood => TavernVisualTheme.technoMinimal,
      TavernVisualTheme.technoMinimal => TavernVisualTheme.hotbloodAdventure,
      TavernVisualTheme.hotbloodAdventure => TavernVisualTheme.cozyWood,
    };
    _applyState(() {
      _visualTheme = next;
    });
    _game.setVisualTheme(next);
    if (mounted) {
      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.tr(
              zh: '主題已切換：$_visualThemeLabel',
              en: 'Theme switched: $_visualThemeLabel',
            ),
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
  }

  String get _visualThemeLabel {
    final strings = AppStrings.of(context);
    return switch (_visualTheme) {
      TavernVisualTheme.cozyWood => strings.tr(zh: '溫馨木質', en: 'Warm Wood'),
      TavernVisualTheme.technoMinimal => strings.tr(
        zh: '科技簡約',
        en: 'Tech Minimal',
      ),
      TavernVisualTheme.hotbloodAdventure => strings.tr(
        zh: '熱血冒險',
        en: 'Bold Adventure',
      ),
    };
  }

  String get _interactButtonLabel {
    final strings = AppStrings.of(context);
    return switch (_nearbyFurniture) {
      TavernFurnitureType.noticeBoard => strings.tr(zh: '查看任務', en: 'Tasks'),
      TavernFurnitureType.masterDesk => strings.tr(zh: '家庭中心', en: 'Family'),
      TavernFurnitureType.guildChest => strings.tr(zh: '打開收藏櫃', en: 'Open Bag'),
      TavernFurnitureType.campfireBar => strings.tr(
        zh: '進入語音房',
        en: 'Open Voice',
      ),
      TavernFurnitureType.guildMerchant => strings.tr(
        zh: '打開獎勵站',
        en: 'Open Rewards',
      ),
      TavernFurnitureType.wallBookshelf => strings.photoDump,
      TavernFurnitureType.honorBanner => strings.openProfile,
      TavernFurnitureType.trainingDummy => strings.habits,
      null => strings.tr(zh: '互動', en: 'Act'),
    };
  }

  void _interactNearbyFurniture() {
    final strings = ref.read(appStringsProvider);
    final done = _game.interactWithNearbyFurniture();
    if (!done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.tr(zh: '請先靠近家具再互動', en: 'Move closer to interact'),
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
  }
}
