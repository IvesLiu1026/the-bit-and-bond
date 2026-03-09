import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/auth/auth_session.dart';
import '../../core/audio/sfx_player.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/security/dm_e2ee_service.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/pixel_typography.dart';
import '../../core/ui/pixel_ui.dart';
import '../../state/direct_messages_controller.dart';
import '../../state/hunter_directory_controller.dart';
import '../../state/hunter_stats_controller.dart';
import '../../state/inventory_controller.dart';
import '../../state/progression_controller.dart';
import '../../state/providers.dart';
import '../../state/quest_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/shop_controller.dart';
import '../../state/social_controller.dart';
import '../../state/voice_chat_controller.dart';
import '../quests/models.dart';
import 'chen_game.dart';

part 'shell/hud.part.dart';
part 'shell/hud_icons.part.dart';
part 'shell/hud_panels.part.dart';
part 'shell/dialogs.part.dart';
part 'shell/presence.part.dart';
part 'shell/actions.part.dart';
part 'shell/rewards.part.dart';
part 'shell/profile.part.dart';
part 'shell/menu.part.dart';
part 'shell/primitives.part.dart';
part 'shell/panels.part.dart';
part 'shell/floorplan.part.dart';
part 'shell/panel_social.part.dart';
part 'shell/panel_voice.part.dart';
part 'shell/panel_inventory.part.dart';
part 'shell/panel_shop.part.dart';
part 'shell/panel_shop_editor.part.dart';
part 'shell/panel_shop_layout.part.dart';
part 'shell/panel_shop_primitives.part.dart';
part 'shell/quests_fx.part.dart';
part 'shell/life.part.dart';
part 'shell/life_habits.part.dart';
part 'shell/life_habits_proof.part.dart';
part 'shell/life_habits_widgets.part.dart';
part 'shell/life_dm_shared.part.dart';
part 'shell/life_dm_inbox.part.dart';
part 'shell/life_dm_chat.part.dart';
part 'shell/life_photo.part.dart';

enum _StampTone { wood, green, ruby, blue }

class GameShellPage extends ConsumerStatefulWidget {
  const GameShellPage({super.key});

  @override
  ConsumerState<GameShellPage> createState() => _GameShellPageState();
}

class _GameShellPageState extends ConsumerState<GameShellPage> {
  static const Duration _presenceSendInterval = Duration(milliseconds: 120);
  static const int _presenceHeartbeatMs = 900;
  static const int _movingSendIntervalMs = 75;
  static const int _idleSendIntervalMs = 280;
  static const double _minPoseDeltaForSync = 1.5;
  static const Duration _debugMeterWindow = Duration(seconds: 1);

  late final TheBitAndBondGame _game;
  late final Widget _gameWidget;
  String? _presenceConnectionKey;
  String? _presenceConnectingKey;
  WebSocketChannel? _presenceChannel;
  StreamSubscription<dynamic>? _presenceSubscription;
  Timer? _presenceSendTimer;
  Timer? _presenceReconnectTimer;
  Timer? _debugMeterTimer;
  Timer? _socialRefreshTimer;
  String _lastSentPoseFingerprint = '';
  int _lastSentPoseAtMs = 0;
  double? _lastSentPoseX;
  double? _lastSentPoseY;
  String _lastSentFacing = 'down';
  bool _lastSentMoving = false;
  bool _presenceConnected = false;
  bool _isDisposing = false;
  int _debugSentInWindow = 0;
  int _debugReceivedInWindow = 0;
  double _debugSentPerSec = 0;
  double _debugReceivedPerSec = 0;
  int _lastInboundAtMs = 0;
  int _lastOutboundAtMs = 0;
  String? _scrollNoticeText;
  Timer? _scrollNoticeTimer;
  int _lastIncomingFriendRequestCount = 0;
  bool _socialSnapshotBootstrapped = false;
  final Set<String> _knownPendingInviteIds = <String>{};
  GuildInviteInfo? _activeGuildInvite;
  Set<String> _onlineHunterIds = <String>{};
  String _interactionHintText = '';
  TavernFurnitureType? _nearbyFurniture;
  TavernVisualTheme _visualTheme = TavernVisualTheme.cozyWood;
  bool _showFloorplanOverlay = false;
  int _sandboxCurrentRoomIndex = 0;
  ProviderSubscription<AuthSession?>? _authSessionSubscription;
  ProviderSubscription<AppConfig>? _appConfigSubscription;
  ProviderSubscription<AppSettings>? _appSettingsSubscription;
  ProviderSubscription<AsyncValue<List<QuestInstance>>>? _questSubscription;
  ProviderSubscription<AsyncValue<List<HunterProfile>>>? _hunterSubscription;
  ProviderSubscription<AsyncValue<SocialSnapshot>>? _socialSubscription;
  ProviderSubscription<VoiceChatState>? _voiceSubscription;
  AuthSession? _latestAuthSession;
  AppConfig? _latestAppConfig;
  final Set<String> _consumedRewardEventIds = <String>{};
  final List<_FloatingRewardEvent> _floatingRewardEvents =
      <_FloatingRewardEvent>[];
  int _floatingRewardSeed = 0;
  bool _showingLevelUpDialog = false;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
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
    super.dispose();
  }

  void _applyState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  @override
  Widget build(BuildContext context) {
    final lowFxMode = ref.watch(
      appConfigProvider.select((config) => config.lowFxMode),
    );
    final uiScale = ref.watch(
      appSettingsProvider.select((settings) => settings.uiScale),
    );
    final progressionState = ref.watch(progressionControllerProvider);
    final authSession = ref.watch(authSessionProvider);
    final voiceConnected = ref.watch(
      voiceChatControllerProvider.select((state) => state.connected),
    );
    final strings = ref.watch(appStringsProvider);
    final missingHunterIdentity =
        authSession == null || authSession.hunterId.trim().isEmpty;

    if (missingHunterIdentity) {
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
          final topBannerHeight = isPhoneLayout ? 60.0 : 60.0;
          final topHudHeight = topBannerHeight;
          final avatarTop = topInset + topHudHeight + 10;
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
                          child: _TitleBadge(
                            lowFxMode: lowFxMode,
                            compact: isPhoneLayout,
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
                child: _AvatarHudButton(
                  progressionState: progressionState,
                  onTap: _openProfileDialog,
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.parchment.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.woodFrame, width: 2),
                    ),
                    child: Text(
                      _interactionHintText,
                      style: TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w800,
                        fontSize: 12 * uiScale,
                      ),
                    ),
                  ),
                ),
              ),
              if (voiceConnected || _nearbyFurniture != null)
                Positioned(
                  right: sideInset,
                  bottom: bottomInset,
                  child: Column(
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
