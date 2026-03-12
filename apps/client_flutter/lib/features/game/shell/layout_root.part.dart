part of '../game_shell_page.dart';

extension _GameShellRootLayout on _GameShellPageState {
  Widget _buildMissingHunterIdentityScaffold(AppStrings strings) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF7CB342),
        alignment: Alignment.center,
        child: _OverlayPanel(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.tr(zh: '登入狀態異常', en: 'Session Problem'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.inkBrown,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  strings.tr(
                    zh: '目前 Token 缺少玩家角色（hunter_id），無法進入可操作的生活空間。',
                    en: 'The current token is missing a player role (hunter_id), so the life space cannot open.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.inkBrown,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _StampButton(
                  label: strings.tr(zh: '重新登入', en: 'Sign In Again'),
                  icon: Icons.login_rounded,
                  tone: _StampTone.green,
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameplayScaffold({
    required BuildContext context,
    required AppStrings strings,
  }) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mediaPadding = MediaQuery.paddingOf(context);
          final topInset = mediaPadding.top + 12;
          final isPhoneLayout =
              constraints.maxWidth < 760 || constraints.maxHeight < 560;
          final hudCompactWidth = isPhoneLayout
              ? math.min(220.0, constraints.maxWidth * 0.52)
              : math.min(230.0, constraints.maxWidth * 0.38);
          final actionButtonWidth = isPhoneLayout
              ? math.min(152.0, constraints.maxWidth * 0.36)
              : 170.0;
          final actionGap = isPhoneLayout ? 8.0 : 10.0;
          final sideInset = isPhoneLayout ? 10.0 : 16.0;
          final bottomInset = mediaPadding.bottom + 12;
          final sandboxRooms = _game.sandboxRooms;
          final canShowFloorplan =
              _game.isSandboxRoomMode && sandboxRooms.length > 1;
          final boundedSandboxIndex = sandboxRooms.isEmpty
              ? 0
              : _sandboxCurrentRoomIndex
                    .clamp(0, sandboxRooms.length - 1)
                    .toInt();
          final currentSandboxRoom = sandboxRooms.isEmpty
              ? null
              : sandboxRooms[boundedSandboxIndex];
          final topOverlayMaxWidth = math.max(
            140.0,
            constraints.maxWidth - hudCompactWidth - sideInset - 32,
          );
          final hintMaxWidth = isPhoneLayout
              ? math.max(
                  104.0,
                  constraints.maxWidth -
                      actionButtonWidth -
                      sideInset -
                      14 -
                      20,
                )
              : 360.0;
          final topBannerHeight = 60.0;
          final avatarTop = topInset + topBannerHeight + 10;
          final rightOverlayTop = avatarTop - 4;

          return Stack(
            children: [
              Positioned.fill(child: _gameWidget),
              Positioned(
                top: topInset,
                left: sideInset,
                right: sideInset,
                child: _game.isSandboxRoomMode
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: topBannerHeight,
                                  child: _TopHudBanner(
                                    title: strings.appTitle,
                                    subtitle: strings.currentSpace(
                                      currentSandboxRoom?.label ??
                                          strings.tr(
                                            zh: '主接點室',
                                            en: 'Main Link Room',
                                          ),
                                    ),
                                    accentColor:
                                        currentSandboxRoom?.accentColor ??
                                        AppColors.submitGreen,
                                    compact: isPhoneLayout,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (canShowFloorplan)
                                    _TopIconButton(
                                      icon: _PixelHudIcon.map,
                                      label: strings.spaceMap,
                                      tooltip: _showFloorplanOverlay
                                          ? strings.closeMap
                                          : strings.openMap,
                                      compact: isPhoneLayout,
                                      selected: _showFloorplanOverlay,
                                      onPressed: () {
                                        _applyState(() {
                                          _showFloorplanOverlay =
                                              !_showFloorplanOverlay;
                                        });
                                      },
                                    ),
                                  if (canShowFloorplan)
                                    const SizedBox(width: 8),
                                  _TopIconButton(
                                    key: AppTestIds.mainMenuOpenButtonKey,
                                    icon: _PixelHudIcon.menu,
                                    label: strings.mainMenu,
                                    tooltip: strings.openMainMenu,
                                    compact: isPhoneLayout,
                                    onPressed: _openMainMenuDialog,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      )
                    : IgnorePointer(
                        child: Center(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final lowFxMode = ref.watch(
                                appConfigProvider.select(
                                  (config) => config.lowFxMode,
                                ),
                              );
                              return _TitleBadge(
                                lowFxMode: lowFxMode,
                                compact: isPhoneLayout,
                              );
                            },
                          ),
                        ),
                      ),
              ),
              if (kDebugMode && !isPhoneLayout)
                Positioned(
                  top: rightOverlayTop,
                  right: sideInset,
                  child: _RealtimeDebugHud(
                    connected: _presenceConnected,
                    txPerSec: _debugSentPerSec,
                    rxPerSec: _debugReceivedPerSec,
                    lastInboundAge: _ageLabel(_lastInboundAtMs),
                    lastOutboundAge: _ageLabel(_lastOutboundAtMs),
                    totalActors: _game.actorCount,
                    remoteActors: _game.realtimeActorCount,
                  ),
                ),
              Positioned(
                top: avatarTop,
                left: 14,
                width: hudCompactWidth,
                child: Consumer(
                  builder: (context, ref, _) {
                    final progressionState = ref.watch(
                      progressionControllerProvider,
                    );
                    return _AvatarHudButton(
                      progressionState: progressionState,
                      onTap: _openProfileDialog,
                    );
                  },
                ),
              ),
              if (_scrollNoticeText != null)
                Positioned(
                  top: rightOverlayTop,
                  right: sideInset,
                  child: AnimatedOpacity(
                    opacity: _scrollNoticeText == null ? 0 : 1,
                    duration: const Duration(milliseconds: 260),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: topOverlayMaxWidth),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.parchment,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.woodFrame,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowHard,
                              offset: Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          _scrollNoticeText!,
                          style: const TextStyle(
                            color: AppColors.inkBrown,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_activeGuildInvite != null)
                Positioned(
                  top: rightOverlayTop + 46,
                  right: sideInset,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: topOverlayMaxWidth),
                    child: _SummonScrollOverlay(
                      invite: _activeGuildInvite!,
                      onAccept: () {
                        _respondGuildInvite(
                          inviteId: _activeGuildInvite!.id,
                          accept: true,
                        );
                      },
                      onReject: () {
                        _respondGuildInvite(
                          inviteId: _activeGuildInvite!.id,
                          accept: false,
                        );
                      },
                    ),
                  ),
                ),
              for (final event in _floatingRewardEvents)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _FloatingRewardText(
                      key: ValueKey(event.id),
                      event: event,
                      anchorResolver: () => _resolveRewardAnchor(
                        hunterId: event.hunterId,
                        lane: event.lane,
                      ),
                      onFinished: () => _removeFloatingReward(event.id),
                    ),
                  ),
                ),
              Positioned(
                left: 14,
                bottom: bottomInset,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: hintMaxWidth),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final uiScale = ref.watch(
                        appSettingsProvider.select(
                          (settings) => settings.uiScale,
                        ),
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.parchment.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.woodFrame,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          _interactionHintText,
                          style: TextStyle(
                            color: AppColors.inkBrown,
                            fontWeight: FontWeight.w800,
                            fontSize: 12 * uiScale,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                right: sideInset,
                bottom: bottomInset,
                child: Consumer(
                  builder: (context, ref, _) {
                    final voiceConnected = ref.watch(
                      voiceChatControllerProvider.select(
                        (state) => state.connected,
                      ),
                    );
                    if (!voiceConnected && _nearbyFurniture == null) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (voiceConnected)
                          SizedBox(
                            width: actionButtonWidth,
                            child: _StampButton(
                              label: strings.tr(
                                zh: '離開語音房',
                                en: 'Leave Voice Room',
                              ),
                              icon: Icons.logout_rounded,
                              tone: _StampTone.ruby,
                              onPressed: _leaveVoiceQuick,
                            ),
                          ),
                        if (voiceConnected && _nearbyFurniture != null)
                          SizedBox(height: actionGap),
                        if (_nearbyFurniture != null)
                          SizedBox(
                            width: actionButtonWidth,
                            child: _StampButton(
                              label: _interactButtonLabel,
                              icon: Icons.touch_app_rounded,
                              tone: _StampTone.green,
                              onPressed: _interactNearbyFurniture,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (canShowFloorplan && _showFloorplanOverlay)
                Positioned.fill(
                  child: _SandboxFloorplanOverlay(
                    rooms: sandboxRooms,
                    currentRoomIndex: _sandboxCurrentRoomIndex,
                    compact: isPhoneLayout,
                    onClose: () {
                      _applyState(() {
                        _showFloorplanOverlay = false;
                      });
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
