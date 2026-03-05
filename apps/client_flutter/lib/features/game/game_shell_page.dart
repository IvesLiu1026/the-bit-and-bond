import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/auth/auth_session.dart';
import '../../core/audio/sfx_player.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../state/hunter_directory_controller.dart';
import '../../state/hunter_stats_controller.dart';
import '../../state/inventory_controller.dart';
import '../../state/progression_controller.dart';
import '../../state/providers.dart';
import '../../state/quest_controller.dart';
import '../../state/shop_controller.dart';
import '../../state/social_controller.dart';
import '../../state/voice_chat_controller.dart';
import '../quests/models.dart';
import 'chen_game.dart';

part 'game_shell_page_hud.part.dart';
part 'game_shell_page_dialogs.part.dart';
part 'game_shell_page_presence.part.dart';
part 'game_shell_page_actions.part.dart';
part 'game_shell_page_rewards.part.dart';
part 'game_shell_page_profile.part.dart';
part 'game_shell_page_panels.part.dart';
part 'game_shell_page_panels_social.part.dart';
part 'game_shell_page_panels_campfire.part.dart';
part 'game_shell_page_panels_inventory.part.dart';
part 'game_shell_page_panels_shop.part.dart';
part 'game_shell_page_quests_fx.part.dart';

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

  late final ChenLevelingGame _game;
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
  String _interactionHintText = '拖曳任意位置，叫出搖桿移動';
  TavernFurnitureType? _nearbyFurniture;
  TavernVisualTheme _visualTheme = TavernVisualTheme.cozyWood;
  ProviderSubscription<AuthSession?>? _authSessionSubscription;
  ProviderSubscription<AppConfig>? _appConfigSubscription;
  ProviderSubscription<AsyncValue<List<QuestInstance>>>? _questSubscription;
  ProviderSubscription<AsyncValue<List<HunterProfile>>>? _hunterSubscription;
  ProviderSubscription<AsyncValue<SocialSnapshot>>? _socialSubscription;
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
    _game = ChenLevelingGame(
      onFurnitureInteracted: _handleFurnitureInteraction,
    );
    _game.setVisualTheme(_visualTheme);
    _game.interactionHintListenable.addListener(_syncInteractionHint);
    _game.activeHunterIdsListenable.addListener(_syncOnlineHunters);
    _game.nearbyFurnitureListenable.addListener(_syncNearbyFurniture);
    _syncInteractionHint();
    _syncOnlineHunters();
    _syncNearbyFurniture();
    _latestAuthSession = ref.read(authSessionProvider);
    _latestAppConfig = ref.read(appConfigProvider);

    _authSessionSubscription = ref.listenManual<AuthSession?>(
      authSessionProvider,
      (previous, next) {
        _latestAuthSession = next;
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
            _showScrollNotice('收到新的好友請求捲軸');
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
    _authSessionSubscription?.close();
    _authSessionSubscription = null;
    _appConfigSubscription?.close();
    _appConfigSubscription = null;
    _questSubscription?.close();
    _questSubscription = null;
    _hunterSubscription?.close();
    _hunterSubscription = null;
    _socialSubscription?.close();
    _socialSubscription = null;
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
    final appConfig = ref.watch(appConfigProvider);
    final lowFxMode = appConfig.lowFxMode;
    final progressionState = ref.watch(progressionControllerProvider);
    final authSession = ref.watch(authSessionProvider);
    final voiceState = ref.watch(voiceChatControllerProvider);
    _game.setCampfireVoiceActivity(
      connected: voiceState.connected,
      hasActiveSpeaker: voiceState.activeSpeakerIdentities.isNotEmpty,
    );
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
                  const Text(
                    '登入狀態異常',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.inkBrown,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '目前 Token 缺少玩家角色（hunter_id），無法進入可操作的酒館場景。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StampButton(
                    label: '重新登入',
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
          final hintMaxWidth = isPhoneLayout
              ? constraints.maxWidth * 0.58
              : 360.0;
          final topActionY = isPhoneLayout ? topInset + 52 : topInset + 4;
          final avatarTop = isPhoneLayout ? topInset + 96 : topInset + 62;

          return Stack(
            children: [
              Positioned.fill(child: GameWidget(game: _game)),
              Positioned(
                top: topInset,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _TitleBadge(
                      lowFxMode: lowFxMode,
                      compact: isPhoneLayout,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topActionY,
                right: sideInset,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TopIconButton(
                      glyph: '退',
                      tooltip: '登出',
                      compact: isPhoneLayout,
                      onPressed: _logout,
                    ),
                    const SizedBox(width: 6),
                    _TopIconButton(
                      glyph: '景',
                      tooltip: '切換主題：$_visualThemeLabel',
                      compact: isPhoneLayout,
                      onPressed: _cycleVisualTheme,
                    ),
                    if (!isPhoneLayout) ...[
                      const SizedBox(width: 6),
                      _TopIconButton(
                        glyph: '包',
                        tooltip: '背包',
                        onPressed: _openInventoryDialog,
                      ),
                      const SizedBox(width: 6),
                      _TopIconButton(
                        glyph: '聊',
                        tooltip: '營火語音聊天室',
                        onPressed: _openCampfireDialog,
                      ),
                    ],
                  ],
                ),
              ),
              if (kDebugMode && !isPhoneLayout)
                Positioned(
                  top: topInset + 56,
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
                  top: avatarTop + 50,
                  right: sideInset,
                  child: AnimatedOpacity(
                    opacity: _scrollNoticeText == null ? 0 : 1,
                    duration: const Duration(milliseconds: 260),
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
              if (_activeGuildInvite != null)
                Positioned(
                  top: avatarTop + 88,
                  right: sideInset,
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
                      style: const TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: sideInset,
                bottom: bottomInset,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isPhoneLayout)
                      SizedBox(
                        width: actionButtonWidth,
                        child: _StampButton(
                          label: '背包',
                          icon: Icons.backpack_outlined,
                          tone: _StampTone.wood,
                          onPressed: _openInventoryDialog,
                        ),
                      ),
                    if (isPhoneLayout) SizedBox(height: actionGap),
                    SizedBox(
                      width: actionButtonWidth,
                      child: _StampButton(
                        label: '營火聊天',
                        iconWidget: _PixelMicStoneIcon(
                          enabled: voiceState.micEnabled,
                        ),
                        tone: voiceState.connected
                            ? _StampTone.blue
                            : _StampTone.wood,
                        onPressed: _openCampfireDialog,
                      ),
                    ),
                    if (voiceState.connected) SizedBox(height: actionGap),
                    if (voiceState.connected)
                      SizedBox(
                        width: actionButtonWidth,
                        child: _StampButton(
                          label: '離開營火',
                          icon: Icons.logout_rounded,
                          tone: _StampTone.ruby,
                          onPressed: _leaveVoiceQuick,
                        ),
                      ),
                    if (_nearbyFurniture != null) SizedBox(height: actionGap),
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
            ],
          );
        },
      ),
    );
  }
}
