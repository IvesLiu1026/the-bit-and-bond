part of 'game_shell_page.dart';

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
      case TavernFurnitureType.honorBanner:
      case TavernFurnitureType.trainingDummy:
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
        final maxWidth = math.max(300.0, media.size.width - 24);
        final maxHeight = math.max(
          320.0,
          media.size.height - media.padding.vertical - 24,
        );
        final width = math.min(preferredWidth, maxWidth);
        final height = preferredHeight == null
            ? null
            : math.min(preferredHeight, compact ? maxHeight * 0.88 : maxHeight);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
            child: _OverlayPanel(
              child: SizedBox(
                width: width,
                height: height,
                child: builder(dialogContext),
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
            final questsState = ref.watch(questControllerProvider);
            final session = ref.watch(authSessionProvider);
            final canSubmit = session != null && !session.isGuildMaster;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '公會懸賞佈告欄',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('這是公會長的書桌，請勿亂動'),
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
            final questsState = ref.watch(questControllerProvider);
            final socialState = ref.watch(socialControllerProvider);
            final huntersState = ref.watch(hunterDirectoryControllerProvider);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '公會長書桌',
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
                    '成員載入失敗：$err',
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
            );
          },
        );
      },
    );
  }
}
