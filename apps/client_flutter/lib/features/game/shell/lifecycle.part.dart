part of '../game_shell_page.dart';

extension _GameShellLifecycle on _GameShellPageState {
  void _initializeShellState() {
    _game = TheBitAndBondGame(
      onFurnitureInteracted: _handleFurnitureInteraction,
    );
    _gameWidget = RepaintBoundary(child: GameWidget(game: _game));
    _game.setVisualTheme(_visualTheme);
    _game.interactionHintListenable.addListener(_syncInteractionHint);
    _game.activeHunterIdsListenable.addListener(_syncOnlineHunters);
    _game.nearbyFurnitureListenable.addListener(_syncNearbyFurniture);
    _game.sandboxRoomIndexListenable.addListener(_syncSandboxRoomIndex);
    _interactionHintText = ref.read(appStringsProvider).leftJoystickHint;
    _syncInteractionHint();
    _syncOnlineHunters();
    _syncNearbyFurniture();
    _syncSandboxRoomIndex();
    _latestAuthSession = ref.read(authSessionProvider);
    _latestAppConfig = ref.read(appConfigProvider);
    _game.setLanguage(ref.read(appSettingsProvider).language);
    final initialVoiceState = ref.read(voiceChatControllerProvider);
    _game.setCampfireVoiceActivity(
      connected: initialVoiceState.connected,
      hasActiveSpeaker: initialVoiceState.activeSpeakerIdentities.isNotEmpty,
    );
    _game.setControlledHunterId(_latestAuthSession?.hunterId);
    _bindProviderSubscriptions();
    unawaited(
      _syncDesiredPresenceConnection(
        session: _latestAuthSession,
        apiBaseUrl:
            _latestAppConfig?.apiBaseUrl ??
            ref.read(appConfigProvider).apiBaseUrl,
      ),
    );
    _socialRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_isDisposing || _latestAuthSession == null) {
        return;
      }
      ref.read(socialControllerProvider.notifier).refresh();
    });
    _startDebugMeter();
  }

  void _bindProviderSubscriptions() {
    _authSessionSubscription = ref.listenManual<AuthSession?>(
      authSessionProvider,
      (previous, next) {
        _latestAuthSession = next;
        _game.setControlledHunterId(next?.hunterId);
        final apiBaseUrl =
            _latestAppConfig?.apiBaseUrl ??
            ref.read(appConfigProvider).apiBaseUrl;
        unawaited(
          _syncDesiredPresenceConnection(session: next, apiBaseUrl: apiBaseUrl),
        );
        _syncHuntersToGame(
          ref.read(hunterDirectoryControllerProvider),
          authSessionOverride: next,
        );
      },
    );

    _appConfigSubscription = ref.listenManual<AppConfig>(appConfigProvider, (
      previous,
      next,
    ) {
      _latestAppConfig = next;
      unawaited(
        _syncDesiredPresenceConnection(
          session: _latestAuthSession,
          apiBaseUrl: next.apiBaseUrl,
        ),
      );
    });

    _appSettingsSubscription = ref.listenManual<AppSettings>(
      appSettingsProvider,
      (previous, next) {
        if (previous?.language != next.language) {
          _game.setLanguage(next.language);
        }
      },
      fireImmediately: true,
    );

    _voiceSubscription = ref.listenManual<VoiceChatState>(
      voiceChatControllerProvider,
      (previous, next) {
        final previousConnected = previous?.connected ?? false;
        final previousHasSpeaker =
            previous?.activeSpeakerIdentities.isNotEmpty ?? false;
        final nextHasSpeaker = next.activeSpeakerIdentities.isNotEmpty;
        if (previousConnected != next.connected ||
            previousHasSpeaker != nextHasSpeaker) {
          _game.setCampfireVoiceActivity(
            connected: next.connected,
            hasActiveSpeaker: nextHasSpeaker,
          );
        }
      },
      fireImmediately: true,
    );

    _questSubscription = ref.listenManual<AsyncValue<List<QuestInstance>>>(
      questControllerProvider,
      (previous, next) {
        next.whenData(_game.syncQuests);
      },
      fireImmediately: true,
    );

    _hunterSubscription = ref.listenManual<AsyncValue<List<HunterProfile>>>(
      hunterDirectoryControllerProvider,
      (previous, next) {
        _syncHuntersToGame(next);
      },
      fireImmediately: true,
    );

    _socialSubscription = ref.listenManual<AsyncValue<SocialSnapshot>>(
      socialControllerProvider,
      (previous, next) {
        next.whenData((snapshot) {
          final incomingCount = snapshot.incomingFriendRequests.length;
          if (incomingCount > _lastIncomingFriendRequestCount) {
            _showScrollNotice(
              ref
                  .read(appStringsProvider)
                  .tr(zh: '收到新的好友請求捲軸', en: 'A new friend request arrived.'),
            );
          }
          _lastIncomingFriendRequestCount = incomingCount;
          _handleGuildInviteScroll(snapshot);
        });
      },
      fireImmediately: true,
    );
  }

  void _disposeShellState() {
    _isDisposing = true;
    _game.interactionHintListenable.removeListener(_syncInteractionHint);
    _game.activeHunterIdsListenable.removeListener(_syncOnlineHunters);
    _game.nearbyFurnitureListenable.removeListener(_syncNearbyFurniture);
    _game.sandboxRoomIndexListenable.removeListener(_syncSandboxRoomIndex);
    _authSessionSubscription?.close();
    _authSessionSubscription = null;
    _appConfigSubscription?.close();
    _appConfigSubscription = null;
    _appSettingsSubscription?.close();
    _appSettingsSubscription = null;
    _questSubscription?.close();
    _questSubscription = null;
    _hunterSubscription?.close();
    _hunterSubscription = null;
    _socialSubscription?.close();
    _socialSubscription = null;
    _voiceSubscription?.close();
    _voiceSubscription = null;
    _debugMeterTimer?.cancel();
    _debugMeterTimer = null;
    _socialRefreshTimer?.cancel();
    _socialRefreshTimer = null;
    _scrollNoticeTimer?.cancel();
    _scrollNoticeTimer = null;
    _disconnectPresenceSync();
  }
}
