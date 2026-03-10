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
import 'bitbond_game.dart';

part 'shell/hud.part.dart';
part 'shell/hud_icons.part.dart';
part 'shell/hud_panels.part.dart';
part 'shell/dialogs.part.dart';
part 'shell/presence.part.dart';
part 'shell/actions_common.part.dart';
part 'shell/actions_shop.part.dart';
part 'shell/actions_social.part.dart';
part 'shell/actions_voice.part.dart';
part 'shell/rewards.part.dart';
part 'shell/profile.part.dart';
part 'shell/profile_visuals.part.dart';
part 'shell/menu.part.dart';
part 'shell/menu_main.part.dart';
part 'shell/menu_settings.part.dart';
part 'shell/lifecycle.part.dart';
part 'shell/layout_root.part.dart';
part 'shell/primitives_surface.part.dart';
part 'shell/primitives_inputs.part.dart';
part 'shell/primitives_actions.part.dart';
part 'shell/hud_overlay.part.dart';
part 'shell/panel_family.part.dart';
part 'shell/floorplan.part.dart';
part 'shell/panel_social.part.dart';
part 'shell/panel_voice.part.dart';
part 'shell/panel_voice_ui.part.dart';
part 'shell/panel_inventory.part.dart';
part 'shell/panel_shop.part.dart';
part 'shell/panel_shop_editor.part.dart';
part 'shell/panel_shop_layout.part.dart';
part 'shell/panel_shop_primitives.part.dart';
part 'shell/panel_quests.part.dart';
part 'shell/rewards_fx.part.dart';
part 'shell/life/life_root.part.dart';
part 'shell/life/habits.part.dart';
part 'shell/life/habits_creation.part.dart';
part 'shell/life/habits_logic.part.dart';
part 'shell/life/habits_proof.part.dart';
part 'shell/life/habits_widgets.part.dart';
part 'shell/life/dm_shared.part.dart';
part 'shell/life/dm_inbox.part.dart';
part 'shell/life/dm_inbox_view.part.dart';
part 'shell/life/dm_chat.part.dart';
part 'shell/life/dm_chat_view.part.dart';
part 'shell/life/photo.part.dart';
part 'shell/life/photo_actions.part.dart';
part 'shell/life/photo_tabs.part.dart';
part 'shell/life/photo_widgets.part.dart';

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
    _initializeShellState();
  }

  @override
  void dispose() {
    _disposeShellState();
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
    final authSession = ref.watch(authSessionProvider);
    final strings = ref.watch(appStringsProvider);
    final missingHunterIdentity =
        authSession == null || authSession.hunterId.trim().isEmpty;

    if (missingHunterIdentity) {
      return _buildMissingHunterIdentityScaffold(strings);
    }
    return _buildGameplayScaffold(context: context, strings: strings);
  }
}
