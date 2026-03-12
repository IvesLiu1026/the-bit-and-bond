part of '../game_shell_page.dart';

extension _GameShellDialogs on _GameShellPageState {
  void _handleFurnitureInteraction(TavernFurnitureType furniture) {
    switch (furniture) {
      case TavernFurnitureType.noticeBoard:
        _openNoticeBoardDialog();
        break;
      case TavernFurnitureType.guildChest:
        _openGuildChestDialog();
        break;
      case TavernFurnitureType.masterDesk:
        _openMasterDeskDialog();
        break;
      case TavernFurnitureType.campfireBar:
        _openCampfireDialog();
        break;
      case TavernFurnitureType.guildMerchant:
        _openGuildShopDialog();
        break;
      case TavernFurnitureType.wallBookshelf:
        _openPhotoDumpDialog();
        break;
      case TavernFurnitureType.honorBanner:
        _openProfileDialog();
        break;
      case TavernFurnitureType.trainingDummy:
        _openHabitsDialog();
        break;
    }
  }

  Future<T?> _showOverlayDialog<T>({
    required double preferredWidth,
    double? preferredHeight,
    required WidgetBuilder builder,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        final compact = media.size.width < 520 || media.size.height < 760;
        final maxWidth = math.max(280.0, media.size.width - 24);
        final availableHeight =
            media.size.height -
            media.padding.vertical -
            media.viewInsets.vertical -
            24;
        final maxHeight = math.max(220.0, availableHeight);
        const panelChrome = 24.0;
        final width = math.min(preferredWidth, maxWidth);
        final height = preferredHeight == null
            ? null
            : math.min(preferredHeight, compact ? maxHeight * 0.94 : maxHeight);
        final bodyWidth = math.max(256.0, width - panelChrome);
        final bodyHeight = height == null
            ? null
            : math.max(180.0, math.min(height, maxHeight) - panelChrome);

        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: media.viewInsets,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width,
                maxHeight: maxHeight,
              ),
              child: _OverlayPanel(
                child: SizedBox(
                  width: bodyWidth,
                  height: bodyHeight,
                  child: builder(dialogContext),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNoticeBoardDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 560,
      preferredHeight: 560,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final strings = AppStrings.of(context);
            final questsState = ref.watch(questControllerProvider);
            final session = ref.watch(authSessionProvider);
            final canSubmit = session != null && !session.isGuildMaster;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.tr(zh: '生活任務板', en: 'Task Board'),
                  style: TextStyle(
                    color: AppColors.inkBrown,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _QuestList(
                    state: questsState,
                    onSubmit: (id) {
                      _submitQuest(id);
                    },
                    canSubmitQuests: canSubmit,
                    lowFxMode: ref.watch(appConfigProvider).lowFxMode,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openGuildChestDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 520,
      preferredHeight: 480,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            return _HudOverlay(
              progressionState: ref.watch(progressionControllerProvider),
              onRefresh: _refreshChildData,
            );
          },
        );
      },
    );
  }

  Future<void> _openMasterDeskDialog() async {
    final session = ref.read(authSessionProvider);
    if (session == null || !session.isGuildMaster) {
      final strings = ref.read(appStringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.tr(
              zh: '這是家庭中心，只有管理者可以操作',
              en: 'This is the Family Center. Only managers can use it.',
            ),
          ),
          backgroundColor: AppColors.hpRuby,
        ),
      );
      return;
    }

    await _showOverlayDialog<void>(
      preferredWidth: 620,
      preferredHeight: 620,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final strings = AppStrings.of(context);
            final questsState = ref.watch(questControllerProvider);
            final socialState = ref.watch(socialControllerProvider);
            final huntersState = ref.watch(hunterDirectoryControllerProvider);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.tr(zh: '家庭中心', en: 'Family Center'),
                  style: TextStyle(
                    color: AppColors.inkBrown,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                huntersState.when(
                  data: (hunters) => _MemberRosterPanel(hunters: hunters),
                  loading: () => const SizedBox(
                    height: 46,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                  error: (err, _) => Text(
                    strings.tr(
                      zh: '成員載入失敗：$err',
                      en: 'Failed to load members: $err',
                    ),
                    style: const TextStyle(color: AppColors.hpRuby),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      _SocialPanel(
                        state: socialState,
                        onAddFriend: _addFriendByPlayerId,
                        onInviteFriend: _inviteFriendByPlayerId,
                        onRespondFriendRequest: _respondFriendRequest,
                        onRespondGuildInvite: _respondGuildInvite,
                      ),
                      const SizedBox(height: 10),
                      _GuildToolsPanel(
                        questsState: questsState,
                        onCreateQuest: _createQuest,
                        onReviewQuest: _reviewQuest,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openCampfireDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 620,
      preferredHeight: 560,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final voiceState = ref.watch(voiceChatControllerProvider);
            return _CampfireVoicePanel(
              state: voiceState,
              onJoin: () {
                return ref
                    .read(voiceChatControllerProvider.notifier)
                    .joinCampfire();
              },
              onLeave: () {
                return ref
                    .read(voiceChatControllerProvider.notifier)
                    .leaveVoice();
              },
              onToggleMic: () {
                return ref
                    .read(voiceChatControllerProvider.notifier)
                    .toggleMic();
              },
              onSendMessage: (text) {
                return ref
                    .read(voiceChatControllerProvider.notifier)
                    .sendChat(text);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openGuildShopDialog() async {
    await ref
        .read(shopControllerProvider.notifier)
        .refresh(includeInactive: false);
    if (!mounted) {
      return;
    }
    await _showOverlayDialog<void>(
      preferredWidth: 620,
      preferredHeight: 560,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final authSession = ref.watch(authSessionProvider);
            final shopState = ref.watch(shopControllerProvider);
            final progressionState = ref.watch(progressionControllerProvider);
            return _GuildShopPanel(
              shopState: shopState,
              progressionState: progressionState,
              isMaster: authSession?.isGuildMaster ?? false,
              onBuy: (item) => _buyShopItem(item: item),
              onManageModeChanged: (enabled) =>
                  _setShopManageMode(enabled: enabled),
              onCreateItem:
                  ({
                    required name,
                    description,
                    required costCoins,
                    required iconTag,
                  }) => _createShopItem(
                    name: name,
                    description: description,
                    costCoins: costCoins,
                    iconTag: iconTag,
                  ),
              onUpdateItem:
                  ({
                    required itemId,
                    required name,
                    description,
                    required costCoins,
                    required iconTag,
                  }) => _updateShopItem(
                    itemId: itemId,
                    name: name,
                    description: description,
                    costCoins: costCoins,
                    iconTag: iconTag,
                  ),
              onDeactivateItem: (itemId) => _deactivateShopItem(itemId: itemId),
            );
          },
        );
      },
    );
  }

  Future<void> _openInventoryDialog() async {
    await ref.read(inventoryControllerProvider.notifier).refresh();
    if (!mounted) {
      return;
    }

    await _showOverlayDialog<void>(
      preferredWidth: 620,
      preferredHeight: 560,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final inventoryState = ref.watch(inventoryControllerProvider);
            return _InventoryPanel(
              inventoryState: inventoryState,
              onUse: _useInventoryItem,
            );
          },
        );
      },
    );
  }

  Future<void> _openProfileDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 560,
      preferredHeight: 620,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final socialState = ref.watch(socialControllerProvider);
            final progressionState = ref.watch(progressionControllerProvider);
            final statsState = ref.watch(hunterStatsControllerProvider);
            return _PlayerProfileDialog(
              socialState: socialState,
              progressionState: progressionState,
              statsState: statsState,
              onlineHunterIds: _onlineHunterIds,
              onSaveMotto: _savePlayerMotto,
              onLoadPlayerPassQr: () =>
                  ref.read(apiClientProvider).getPlayerPassQrBundle(),
            );
          },
        );
      },
    );
  }
}
