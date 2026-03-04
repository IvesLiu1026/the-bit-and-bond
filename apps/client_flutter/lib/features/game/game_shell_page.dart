import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../state/guardian_review_controller.dart';
import '../../state/hunter_directory_controller.dart';
import '../../state/progression_controller.dart';
import '../../state/providers.dart';
import '../../state/quest_controller.dart';
import '../quests/models.dart';
import 'chen_game.dart';

enum _PanelMode { child, guardian }

enum _StampTone { wood, green, ruby, blue }

class GameShellPage extends ConsumerStatefulWidget {
  const GameShellPage({super.key});

  @override
  ConsumerState<GameShellPage> createState() => _GameShellPageState();
}

class _GameShellPageState extends ConsumerState<GameShellPage> {
  static const Duration _presenceSendInterval = Duration(milliseconds: 180);
  static const int _presenceHeartbeatMs = 2200;

  late final ChenLevelingGame _game;
  _PanelMode _panelMode = _PanelMode.child;
  String? _presenceConnectionKey;
  WebSocketChannel? _presenceChannel;
  StreamSubscription<dynamic>? _presenceSubscription;
  Timer? _presenceSendTimer;
  Timer? _presenceReconnectTimer;
  String _lastSentPoseFingerprint = '';
  int _lastSentPoseAtMs = 0;
  ProviderSubscription<AuthSession?>? _authSessionSubscription;
  ProviderSubscription<AppConfig>? _appConfigSubscription;
  ProviderSubscription<AsyncValue<List<QuestInstance>>>? _questSubscription;
  ProviderSubscription<AsyncValue<List<HunterProfile>>>? _hunterSubscription;
  AuthSession? _latestAuthSession;
  AppConfig? _latestAppConfig;

  @override
  void initState() {
    super.initState();
    _game = ChenLevelingGame();
    _latestAuthSession = ref.read(authSessionProvider);
    _latestAppConfig = ref.read(appConfigProvider);

    _authSessionSubscription = ref.listenManual<AuthSession?>(
      authSessionProvider,
      (previous, next) {
        _latestAuthSession = next;
        final apiBaseUrl =
            _latestAppConfig?.apiBaseUrl ??
            ref.read(appConfigProvider).apiBaseUrl;
        _syncDesiredPresenceConnection(session: next, apiBaseUrl: apiBaseUrl);
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
      _syncDesiredPresenceConnection(
        session: _latestAuthSession,
        apiBaseUrl: next.apiBaseUrl,
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

    _syncDesiredPresenceConnection(
      session: _latestAuthSession,
      apiBaseUrl:
          _latestAppConfig?.apiBaseUrl ??
          ref.read(appConfigProvider).apiBaseUrl,
    );
  }

  @override
  void dispose() {
    _authSessionSubscription?.close();
    _authSessionSubscription = null;
    _appConfigSubscription?.close();
    _appConfigSubscription = null;
    _questSubscription?.close();
    _questSubscription = null;
    _hunterSubscription?.close();
    _hunterSubscription = null;
    _disconnectPresenceSync();
    super.dispose();
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    String? successMessage,
  }) async {
    try {
      await action();
      if (!mounted || successMessage == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action failed: $error'),
          backgroundColor: AppColors.hpRuby,
        ),
      );
    }
  }

  Future<void> _refreshGuardianPending() async {
    await _runAction(
      action: () async {
        await ref.read(guardianReviewControllerProvider.notifier).refresh();
        await ref.read(hunterDirectoryControllerProvider.notifier).refresh();
      },
    );
  }

  Future<void> _approveSubmission(String submissionId) async {
    final hunterId = ref.read(activeHunterIdProvider);
    if (hunterId == null || hunterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a hunter before approving rewards.'),
          backgroundColor: AppColors.hpRuby,
        ),
      );
      return;
    }

    await _runAction(
      action: () async {
        await ref
            .read(guardianReviewControllerProvider.notifier)
            .approve(
              submissionId,
              hunterId: hunterId,
              reviewNote: 'approved by guardian',
            );
        await ref.read(questControllerProvider.notifier).refresh();
        await ref.read(progressionControllerProvider.notifier).refresh();
        await ref.read(hunterDirectoryControllerProvider.notifier).refresh();
      },
      successMessage: 'Submission approved',
    );
  }

  Future<void> _rejectSubmission(String submissionId) async {
    await _runAction(
      action: () async {
        await ref
            .read(guardianReviewControllerProvider.notifier)
            .reject(submissionId, reviewNote: 'please retry');
        await ref.read(questControllerProvider.notifier).refresh();
        await ref.read(progressionControllerProvider.notifier).refresh();
      },
      successMessage: 'Submission rejected',
    );
  }

  Future<void> _refreshChildData() async {
    await _runAction(
      action: () async {
        await ref.read(questControllerProvider.notifier).refresh();
        await ref.read(progressionControllerProvider.notifier).refresh();
        await ref.read(hunterDirectoryControllerProvider.notifier).refresh();
      },
    );
  }

  Future<void> _submitQuest(String questId) async {
    await _runAction(
      action: () async {
        await ref
            .read(questControllerProvider.notifier)
            .submitQuest(questId, note: 'done from client');
        await ref.read(progressionControllerProvider.notifier).refresh();
      },
      successMessage: 'Quest submitted',
    );
  }

  Future<void> _createHunter({
    required String name,
    required String avatarType,
    required String pinCode,
  }) async {
    await _runAction(
      action: () async {
        final created = await ref
            .read(hunterDirectoryControllerProvider.notifier)
            .createHunter(name: name, avatarType: avatarType, pinCode: pinCode);
        ref.read(selectedHunterIdProvider.notifier).state = created.id;
        await ref.read(progressionControllerProvider.notifier).refresh();
      },
      successMessage: 'Hunter created',
    );
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  void _syncDesiredPresenceConnection({
    required AuthSession? session,
    required String apiBaseUrl,
  }) {
    if (session == null || session.accessToken.isEmpty) {
      _disconnectPresenceSync();
      return;
    }

    final key = '$apiBaseUrl|${session.accessToken}';
    if (_presenceConnectionKey == key && _presenceChannel != null) {
      return;
    }

    _cleanupPresenceChannel(clearKey: true);
    _presenceReconnectTimer?.cancel();
    _presenceReconnectTimer = null;

    final uri = _buildPresenceUri(
      apiBaseUrl: apiBaseUrl,
      token: session.accessToken,
    );
    final channel = WebSocketChannel.connect(uri);
    _presenceChannel = channel;
    _presenceConnectionKey = key;
    _lastSentPoseFingerprint = '';
    _lastSentPoseAtMs = 0;

    _presenceSubscription = channel.stream.listen(
      (raw) => _handlePresenceRaw(raw, key),
      onDone: () => _handlePresenceClosed(key),
      onError: (_) => _handlePresenceClosed(key),
      cancelOnError: true,
    );
    _presenceSendTimer = Timer.periodic(
      _presenceSendInterval,
      (_) => _sendPoseTick(key),
    );
  }

  Uri _buildPresenceUri({required String apiBaseUrl, required String token}) {
    final base = Uri.parse(apiBaseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    final port = base.hasPort ? base.port : (wsScheme == 'wss' ? 443 : 80);
    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: port,
      path: '/api/v1/realtime/ws',
      queryParameters: {'token': token},
    );
  }

  void _sendPoseTick(String key) {
    if (_presenceConnectionKey != key) {
      return;
    }
    final channel = _presenceChannel;
    if (channel == null) {
      return;
    }
    final pose = _game.controlledPoseForSync();
    if (pose == null) {
      return;
    }

    final fingerprint =
        '${pose.hunterId}|${pose.facing}|${pose.moving}|'
        '${pose.x.toStringAsFixed(1)}|${pose.y.toStringAsFixed(1)}';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final unchanged = fingerprint == _lastSentPoseFingerprint;
    if (unchanged && nowMs - _lastSentPoseAtMs < _presenceHeartbeatMs) {
      return;
    }

    _lastSentPoseFingerprint = fingerprint;
    _lastSentPoseAtMs = nowMs;
    try {
      channel.sink.add(jsonEncode(pose.toClientMessage()));
    } catch (_) {
      _handlePresenceClosed(key);
    }
  }

  void _handlePresenceRaw(dynamic raw, String key) {
    if (_presenceConnectionKey != key || raw is! String) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    final type = decoded['type'];
    if (type == 'snapshot') {
      final positions = decoded['positions'];
      if (positions is! List) {
        return;
      }
      for (final item in positions) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final pose = HunterRealtimePose.fromServerJson(item);
        if (pose == null) {
          continue;
        }
        _game.applyRemotePose(pose);
      }
      return;
    }

    if (type == 'pose') {
      final poseJson = decoded['pose'];
      if (poseJson is! Map<String, dynamic>) {
        return;
      }
      final pose = HunterRealtimePose.fromServerJson(poseJson);
      if (pose == null) {
        return;
      }
      _game.applyRemotePose(pose);
    }
  }

  void _handlePresenceClosed(String key) {
    if (!mounted || _presenceConnectionKey != key) {
      return;
    }
    _cleanupPresenceChannel(clearKey: true);

    _presenceReconnectTimer?.cancel();
    _presenceReconnectTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) {
        return;
      }
      final session = ref.read(authSessionProvider);
      final appConfig = ref.read(appConfigProvider);
      _syncDesiredPresenceConnection(
        session: session,
        apiBaseUrl: appConfig.apiBaseUrl,
      );
    });
  }

  void _disconnectPresenceSync() {
    _presenceReconnectTimer?.cancel();
    _presenceReconnectTimer = null;
    _cleanupPresenceChannel(clearKey: true);
  }

  void _cleanupPresenceChannel({required bool clearKey}) {
    _presenceSendTimer?.cancel();
    _presenceSendTimer = null;

    _presenceSubscription?.cancel();
    _presenceSubscription = null;

    _presenceChannel?.sink.close();
    _presenceChannel = null;

    if (clearKey) {
      _presenceConnectionKey = null;
      _lastSentPoseFingerprint = '';
      _lastSentPoseAtMs = 0;
    }
  }

  String? _jwtSubject(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return null;
      }
      final payloadRaw = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(payloadRaw));
      final payload = jsonDecode(payloadJson);
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      final sub = payload['sub'];
      if (sub is String && sub.trim().isNotEmpty) {
        return sub.trim();
      }
    } catch (_) {
      // Ignore malformed JWT payloads and fallback to spectator mode.
    }
    return null;
  }

  void _syncHuntersToGame(
    AsyncValue<List<HunterProfile>> huntersState, {
    AuthSession? authSessionOverride,
  }) {
    final authSession =
        authSessionOverride ??
        _latestAuthSession ??
        ref.read(authSessionProvider);

    huntersState.whenData((hunters) {
      final roster = List<HunterProfile>.from(hunters);
      String? controlledHunterId;

      if (authSession?.isHunter == true) {
        controlledHunterId = authSession?.hunterId;
      } else if (authSession?.isGuildMaster == true) {
        final masterId = _jwtSubject(authSession!.accessToken);
        controlledHunterId = masterId;
        if (masterId != null &&
            masterId.isNotEmpty &&
            !roster.any((hunter) => hunter.id == masterId)) {
          roster.add(
            HunterProfile(
              id: masterId,
              guildId: authSession.guildId,
              name: 'Guild Master',
              avatarType: 'master',
              level: 1,
              xp: 0,
              coins: 0,
            ),
          );
        }
      }

      _game.syncHunters(roster, controlledHunterId: controlledHunterId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authSession = ref.watch(authSessionProvider);
    final appConfig = ref.watch(appConfigProvider);
    final lowFxMode = appConfig.lowFxMode;
    final canSubmitQuests = authSession?.role == AuthUserRole.hunter;
    final canReviewSubmissions = authSession?.role == AuthUserRole.guildMaster;
    final resolvedPanelMode = canReviewSubmissions
        ? _panelMode
        : _PanelMode.child;

    final questsState = ref.watch(questControllerProvider);
    final progressionState = ref.watch(progressionControllerProvider);
    final huntersState = ref.watch(hunterDirectoryControllerProvider);
    final activeHunterId = ref.watch(activeHunterIdProvider);
    final pendingState = canReviewSubmissions
        ? ref.watch(guardianReviewControllerProvider)
        : const AsyncValue.data(<PendingSubmission>[]);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mediaPadding = MediaQuery.paddingOf(context);
          final topInset = mediaPadding.top + 12;
          final bottomInset = mediaPadding.bottom + 12;
          final compact = constraints.maxWidth < 1040;
          final rightPanelWidth = math.min(460.0, constraints.maxWidth * 0.36);
          final hudWidth = math.min(340.0, constraints.maxWidth * 0.44);

          return Stack(
            children: [
              Positioned.fill(child: GameWidget(game: _game)),
              Positioned(
                top: topInset,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(child: _TitleBadge(lowFxMode: lowFxMode)),
                ),
              ),
              Positioned(
                top: topInset + 4,
                right: 16,
                child: _StampButton(
                  label: 'Sign Out',
                  icon: Icons.logout,
                  tone: _StampTone.wood,
                  onPressed: _logout,
                ),
              ),
              Positioned(
                top: topInset + 62,
                left: 14,
                width: hudWidth,
                child: _OverlayPanel(
                  child: _HudOverlay(
                    progressionState: progressionState,
                    onRefresh: () {
                      _refreshChildData();
                    },
                  ),
                ),
              ),
              if (compact)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: bottomInset,
                  height: math.min(constraints.maxHeight * 0.58, 500),
                  child: _OverlayPanel(
                    child: _QuestOverlay(
                      panelMode: resolvedPanelMode,
                      allowGuardianMode: canReviewSubmissions,
                      onPanelModeChanged: (next) {
                        setState(() {
                          _panelMode = next;
                        });
                      },
                      guardian: _GuardianPanel(
                        state: pendingState,
                        huntersState: huntersState,
                        activeHunterId: activeHunterId,
                        onCreateHunter:
                            ({
                              required name,
                              required avatarType,
                              required pinCode,
                            }) {
                              return _createHunter(
                                name: name,
                                avatarType: avatarType,
                                pinCode: pinCode,
                              );
                            },
                        onHunterChanged: (hunterId) {
                          ref.read(selectedHunterIdProvider.notifier).state =
                              hunterId;
                        },
                        onRefresh: () {
                          _refreshGuardianPending();
                        },
                        onApprove: (submissionId) {
                          _approveSubmission(submissionId);
                        },
                        onReject: (submissionId) {
                          _rejectSubmission(submissionId);
                        },
                      ),
                      child: _ChildPanel(
                        questsState: questsState,
                        progressionState: progressionState,
                        lowFxMode: lowFxMode,
                        onRefreshAll: () {
                          _refreshChildData();
                        },
                        onSubmit: (questId) {
                          _submitQuest(questId);
                        },
                        canSubmitQuests: canSubmitQuests,
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  top: topInset + 62,
                  right: 14,
                  bottom: bottomInset,
                  width: rightPanelWidth,
                  child: _OverlayPanel(
                    child: _QuestOverlay(
                      panelMode: resolvedPanelMode,
                      allowGuardianMode: canReviewSubmissions,
                      onPanelModeChanged: (next) {
                        setState(() {
                          _panelMode = next;
                        });
                      },
                      guardian: _GuardianPanel(
                        state: pendingState,
                        huntersState: huntersState,
                        activeHunterId: activeHunterId,
                        onCreateHunter:
                            ({
                              required name,
                              required avatarType,
                              required pinCode,
                            }) {
                              return _createHunter(
                                name: name,
                                avatarType: avatarType,
                                pinCode: pinCode,
                              );
                            },
                        onHunterChanged: (hunterId) {
                          ref.read(selectedHunterIdProvider.notifier).state =
                              hunterId;
                        },
                        onRefresh: () {
                          _refreshGuardianPending();
                        },
                        onApprove: (submissionId) {
                          _approveSubmission(submissionId);
                        },
                        onReject: (submissionId) {
                          _rejectSubmission(submissionId);
                        },
                      ),
                      child: _ChildPanel(
                        questsState: questsState,
                        progressionState: progressionState,
                        lowFxMode: lowFxMode,
                        onRefreshAll: () {
                          _refreshChildData();
                        },
                        onSubmit: (questId) {
                          _submitQuest(questId);
                        },
                        canSubmitQuests: canSubmitQuests,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TitleBadge extends StatefulWidget {
  const _TitleBadge({required this.lowFxMode});

  final bool lowFxMode;

  @override
  State<_TitleBadge> createState() => _TitleBadgeState();
}

class _TitleBadgeState extends State<_TitleBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final math.Random _flickerRandom;
  late double _leftFrom;
  late double _leftTo;
  late double _rightFrom;
  late double _rightTo;

  @override
  void initState() {
    super.initState();
    _flickerRandom = math.Random();
    _leftFrom = _nextFlickerValue();
    _rightFrom = _nextFlickerValue();
    _leftTo = _nextFlickerValue();
    _rightTo = _nextFlickerValue();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && !widget.lowFxMode) {
            _leftFrom = _leftTo;
            _rightFrom = _rightTo;
            _leftTo = _nextFlickerValue();
            _rightTo = _nextFlickerValue();
            _controller.forward(from: 0);
          }
        });
    if (!widget.lowFxMode) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TitleBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lowFxMode == widget.lowFxMode) {
      return;
    }
    if (widget.lowFxMode) {
      _controller.stop();
      return;
    }
    _leftFrom = _nextFlickerValue();
    _rightFrom = _nextFlickerValue();
    _leftTo = _nextFlickerValue();
    _rightTo = _nextFlickerValue();
    _controller.forward(from: 0);
  }

  double _nextFlickerValue() {
    return 0.6 + (_flickerRandom.nextDouble() * 0.4);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lowFxMode) {
      return _buildBadge(0.82, 0.82, lowFxMode: true);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.bounceIn.transform(_controller.value);
        final leftFlicker = _leftFrom + ((_leftTo - _leftFrom) * t);
        final rightFlicker = _rightFrom + ((_rightTo - _rightFrom) * t);
        return _buildBadge(leftFlicker, rightFlicker, lowFxMode: false);
      },
    );
  }

  Widget _buildBadge(
    double leftFlicker,
    double rightFlicker, {
    required bool lowFxMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2E6C8), Color(0xFFE6D4AE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF745238), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF402B1E),
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PixelTorch(flicker: leftFlicker, lowFxMode: lowFxMode),
          const SizedBox(width: 10),
          const Icon(Icons.auto_awesome, size: 18, color: AppColors.navyBlue),
          const SizedBox(width: 8),
          const Text(
            'Cozy Guild Board',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: AppColors.inkBrown,
            ),
          ),
          const SizedBox(width: 10),
          _PixelTorch(flicker: rightFlicker, lowFxMode: lowFxMode),
        ],
      ),
    );
  }
}

class _PixelTorch extends StatelessWidget {
  const _PixelTorch({required this.flicker, required this.lowFxMode});

  final double flicker;
  final bool lowFxMode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 32,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 7,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF6D4C41),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: const Color(0xFF3E2723), width: 1.2),
            ),
          ),
          Positioned(
            top: 0,
            child: Opacity(
              opacity: lowFxMode ? 0.8 : flicker.clamp(0.0, 1.0),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFF59D), Color(0xFFFFA000)],
                  ),
                  boxShadow: lowFxMode
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x55FFB300),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayPanel extends StatelessWidget {
  const _OverlayPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.woodFrame, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowHard,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HudOverlay extends StatelessWidget {
  const _HudOverlay({required this.progressionState, required this.onRefresh});

  final AsyncValue<ProgressionBundle> progressionState;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Icon(Icons.map, size: 18, color: AppColors.inkBrown),
            SizedBox(width: 6),
            Text(
              'Guild Map',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.inkBrown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        progressionState.when(
          data: (bundle) {
            final p = bundle.progression;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player Lv.${p.level}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppColors.inkBrown,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatGemChip(
                      icon: Icons.stars,
                      label: '${p.xp} XP',
                      color: AppColors.apSapphire,
                    ),
                    _StatGemChip(
                      icon: Icons.monetization_on,
                      label: '${p.coins} Coins',
                      color: const Color(0xFFB26A00),
                    ),
                    _StatGemChip(
                      icon: Icons.task,
                      label: '${p.availableQuests} Quests',
                      color: AppColors.stampGreen,
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 68,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.8)),
          ),
          error: (err, _) => Text(
            'Status error: $err',
            style: const TextStyle(
              color: AppColors.hpRuby,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _StampButton(
          label: 'Refresh State',
          icon: Icons.refresh,
          tone: _StampTone.wood,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

class _QuestOverlay extends StatelessWidget {
  const _QuestOverlay({
    required this.panelMode,
    required this.allowGuardianMode,
    required this.onPanelModeChanged,
    required this.child,
    required this.guardian,
  });

  final _PanelMode panelMode;
  final bool allowGuardianMode;
  final ValueChanged<_PanelMode> onPanelModeChanged;
  final Widget child;
  final Widget guardian;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_PanelMode>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            side: WidgetStatePropertyAll(
              BorderSide(color: Color(0xFF6A4D33), width: 2),
            ),
          ),
          segments: [
            const ButtonSegment(value: _PanelMode.child, label: Text('Child')),
            if (allowGuardianMode)
              const ButtonSegment(
                value: _PanelMode.guardian,
                label: Text('Guardian'),
              ),
          ],
          selected: {panelMode},
          onSelectionChanged: (selection) {
            onPanelModeChanged(selection.first);
          },
        ),
        const SizedBox(height: 10),
        Expanded(child: panelMode == _PanelMode.child ? child : guardian),
      ],
    );
  }
}

class _ChildPanel extends StatelessWidget {
  const _ChildPanel({
    required this.questsState,
    required this.progressionState,
    required this.lowFxMode,
    required this.onRefreshAll,
    required this.onSubmit,
    required this.canSubmitQuests,
  });

  final AsyncValue<List<QuestInstance>> questsState;
  final AsyncValue<ProgressionBundle> progressionState;
  final bool lowFxMode;
  final VoidCallback onRefreshAll;
  final void Function(String questId) onSubmit;
  final bool canSubmitQuests;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ParchmentSection(
          title: 'Adventure Summary',
          icon: Icons.shield,
          child: _ProgressionPanel(state: progressionState),
        ),
        const SizedBox(height: 10),
        _StampButton(
          label: 'Refresh State',
          icon: Icons.refresh,
          tone: _StampTone.wood,
          onPressed: onRefreshAll,
        ),
        const SizedBox(height: 10),
        const Text(
          'Quest Cards',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.inkBrown,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _QuestList(
            state: questsState,
            onSubmit: onSubmit,
            canSubmitQuests: canSubmitQuests,
            lowFxMode: lowFxMode,
          ),
        ),
      ],
    );
  }
}

class _GuardianPanel extends StatelessWidget {
  const _GuardianPanel({
    required this.state,
    required this.huntersState,
    required this.activeHunterId,
    required this.onCreateHunter,
    required this.onHunterChanged,
    required this.onRefresh,
    required this.onApprove,
    required this.onReject,
  });

  final AsyncValue<List<PendingSubmission>> state;
  final AsyncValue<List<HunterProfile>> huntersState;
  final String? activeHunterId;
  final Future<void> Function({
    required String name,
    required String avatarType,
    required String pinCode,
  })
  onCreateHunter;
  final ValueChanged<String?> onHunterChanged;
  final VoidCallback onRefresh;
  final void Function(String submissionId) onApprove;
  final void Function(String submissionId) onReject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HunterForgeCard(onCreate: onCreateHunter),
        const SizedBox(height: 10),
        _StampButton(
          label: 'Refresh Pending',
          icon: Icons.refresh,
          tone: _StampTone.wood,
          onPressed: onRefresh,
        ),
        const SizedBox(height: 10),
        huntersState.when(
          data: (hunters) {
            if (hunters.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hpRuby, width: 2),
                ),
                child: const Text(
                  'No hunters in this guild. Create one before approving rewards.',
                  style: TextStyle(
                    color: AppColors.hpRuby,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1E7D2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.woodFrame, width: 3),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_pin_circle,
                    size: 18,
                    color: AppColors.inkBrown,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Reward Hunter:',
                    style: TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: hunters.any((h) => h.id == activeHunterId)
                            ? activeHunterId
                            : hunters.first.id,
                        borderRadius: BorderRadius.circular(10),
                        items: hunters
                            .map(
                              (hunter) => DropdownMenuItem<String>(
                                value: hunter.id,
                                child: Text(
                                  '${hunter.name} (Lv.${hunter.level})',
                                  style: const TextStyle(
                                    color: AppColors.inkBrown,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: onHunterChanged,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
          error: (err, _) => Text(
            'Hunters error: $err',
            style: const TextStyle(color: AppColors.hpRuby),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Pending Review Queue',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.inkBrown,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: state.when(
            data: (rows) {
              final canApprove = huntersState.maybeWhen(
                data: (hunters) =>
                    hunters.isNotEmpty &&
                    activeHunterId != null &&
                    activeHunterId!.isNotEmpty,
                orElse: () => false,
              );

              if (rows.isEmpty) {
                return const Center(
                  child: Text(
                    'No pending submissions',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkBrown,
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return _ParchmentSection(
                    title: row.templateTitle ?? row.questInstanceId,
                    icon: Icons.assignment_turned_in,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (row.note != null && row.note!.isNotEmpty)
                          Text(
                            'Note: ${row.note}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkBrown,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Submitted: ${_formatDateTime(row.submittedAt)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.navyBlue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _StampButton(
                                label: 'Approve',
                                icon: Icons.check_circle,
                                tone: _StampTone.green,
                                onPressed: canApprove
                                    ? () {
                                        onApprove(row.submissionId);
                                      }
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StampButton(
                                label: 'Reject',
                                icon: Icons.cancel,
                                tone: _StampTone.ruby,
                                onPressed: () {
                                  onReject(row.submissionId);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                'Pending error: $err',
                style: const TextStyle(color: AppColors.hpRuby),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HunterForgeCard extends StatefulWidget {
  const _HunterForgeCard({required this.onCreate});

  final Future<void> Function({
    required String name,
    required String avatarType,
    required String pinCode,
  })
  onCreate;

  @override
  State<_HunterForgeCard> createState() => _HunterForgeCardState();
}

class _HunterForgeCardState extends State<_HunterForgeCard> {
  static const List<String> _avatarOptions = <String>[
    'warrior',
    'mage',
    'archer',
    'knight',
  ];

  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  String _avatarType = _avatarOptions.first;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final name = _nameController.text.trim();
    final pinCode = _pinController.text.trim();

    if (name.isEmpty) {
      _showError('Hunter name is required');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pinCode)) {
      _showError('PIN must be exactly 4 digits');
      return;
    }

    setState(() {
      _submitting = true;
    });
    try {
      await widget.onCreate(
        name: name,
        avatarType: _avatarType,
        pinCode: pinCode,
      );
      _nameController.clear();
      _pinController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.hpRuby),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFE7DDC9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.woodFrame, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.woodFrame, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.navyBlue, width: 2.2),
      ),
    );

    return _ParchmentSection(
      title: 'Hunter Forge',
      icon: Icons.person_add_alt_1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create a hunter for this guild.',
            style: TextStyle(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            enabled: !_submitting,
            decoration: inputDecoration.copyWith(
              labelText: 'Hunter Name',
              labelStyle: const TextStyle(
                color: AppColors.inkBrown,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: const TextStyle(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _avatarType,
            decoration: inputDecoration.copyWith(
              labelText: 'Avatar Type',
              labelStyle: const TextStyle(
                color: AppColors.inkBrown,
                fontWeight: FontWeight.w800,
              ),
            ),
            borderRadius: BorderRadius.circular(10),
            items: _avatarOptions
                .map(
                  (avatar) => DropdownMenuItem<String>(
                    value: avatar,
                    child: Text(
                      avatar,
                      style: const TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _submitting
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _avatarType = value;
                    });
                  },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pinController,
            enabled: !_submitting,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: inputDecoration.copyWith(
              labelText: '4-digit PIN',
              labelStyle: const TextStyle(
                color: AppColors.inkBrown,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: const TextStyle(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          _StampButton(
            label: _submitting ? 'Forging...' : 'Create Hunter',
            icon: Icons.auto_awesome,
            tone: _StampTone.green,
            onPressed: _submitting
                ? null
                : () {
                    _submit();
                  },
          ),
        ],
      ),
    );
  }
}

class _ProgressionPanel extends StatelessWidget {
  const _ProgressionPanel({required this.state});

  final AsyncValue<ProgressionBundle> state;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (bundle) {
        final p = bundle.progression;
        final xpProgress = (p.xp % 100) / 100.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Level ${p.level}',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: AppColors.inkBrown,
                  ),
                ),
                const Spacer(),
                _StatGemChip(
                  icon: Icons.stars,
                  label: '${p.xp} XP',
                  color: AppColors.apSapphire,
                ),
                const SizedBox(width: 6),
                _StatGemChip(
                  icon: Icons.monetization_on,
                  label: '${p.coins}',
                  color: const Color(0xFFB26A00),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PixelMeter(
              label: 'XP Progress',
              value: xpProgress,
              color: AppColors.apSapphire,
            ),
            const SizedBox(height: 8),
            _PixelMeter(
              label: 'Quest Readiness',
              value:
                  ((p.availableQuests + p.submittedQuests).clamp(0, 10)) / 10,
              color: AppColors.stampGreen,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    title: 'Available',
                    value: '${p.availableQuests}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    title: 'Submitted',
                    value: '${p.submittedQuests}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    title: 'Ledger',
                    value: '${bundle.ledger.length}',
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Text(
        'Progression error: $err',
        style: const TextStyle(color: AppColors.hpRuby),
      ),
    );
  }
}

class _QuestList extends StatelessWidget {
  const _QuestList({
    required this.state,
    required this.onSubmit,
    required this.canSubmitQuests,
    required this.lowFxMode,
  });

  final AsyncValue<List<QuestInstance>> state;
  final void Function(String questId) onSubmit;
  final bool canSubmitQuests;
  final bool lowFxMode;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (quests) {
        if (quests.isEmpty) {
          return _QuestEmptyState(animateLockFlash: !lowFxMode);
        }

        return ListView.separated(
          itemCount: quests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final quest = quests[index];
            final canSubmit =
                canSubmitQuests &&
                (quest.status == QuestStatus.available ||
                    quest.status == QuestStatus.rejected);

            return _ParchmentSection(
              title: quest.templateTitle ?? quest.templateId,
              icon: _questCategoryIcon(quest.category),
              badge: _StatusBadge(status: quest.status),
              hoverLift: !lowFxMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatGemChip(
                        icon: Icons.stars,
                        label: '${quest.baseXp ?? 0} XP',
                        color: AppColors.apSapphire,
                      ),
                      const SizedBox(width: 6),
                      _StatGemChip(
                        icon: Icons.monetization_on,
                        label: '${quest.baseCoins ?? 0}',
                        color: const Color(0xFFB26A00),
                      ),
                    ],
                  ),
                  if (quest.dueAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Due: ${_formatDateTime(quest.dueAt!)}',
                      style: const TextStyle(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _StampButton(
                    label: 'Submit',
                    icon: Icons.task_alt,
                    tone: _StampTone.green,
                    onPressed: canSubmit
                        ? () {
                            onSubmit(quest.id);
                          }
                        : null,
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Quest load error: $err',
          style: const TextStyle(color: AppColors.hpRuby),
        ),
      ),
    );
  }
}

class _QuestEmptyState extends StatefulWidget {
  const _QuestEmptyState({required this.animateLockFlash});

  final bool animateLockFlash;

  @override
  State<_QuestEmptyState> createState() => _QuestEmptyStateState();
}

class _QuestEmptyStateState extends State<_QuestEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.animateLockFlash) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _QuestEmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animateLockFlash == widget.animateLockFlash) {
      return;
    }
    if (widget.animateLockFlash) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1E7D2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.woodFrame, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 88,
                  height: 72,
                  child: CustomPaint(
                    painter: _PixelChestPainter(lockFlash: _controller.value),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No quests assigned',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkBrown,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'The guild chest is waiting for new missions.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navyBlue,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PixelChestPainter extends CustomPainter {
  const _PixelChestPainter({required this.lockFlash});

  final double lockFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final pixel = size.width / 22;
    final flashProgress = lockFlash > 0.9 ? ((lockFlash - 0.9) / 0.1) : 0.0;
    final lockColor = Color.lerp(
      const Color(0xFFB26A00),
      const Color(0xFFFFE082),
      flashProgress,
    )!;

    void fill(int x, int y, int w, int h, Color color) {
      final paint = Paint()..color = color;
      canvas.drawRect(
        Rect.fromLTWH(x * pixel, y * pixel, w * pixel, h * pixel),
        paint,
      );
    }

    fill(1, 6, 20, 10, const Color(0xFF8D6E63));
    fill(1, 6, 20, 2, const Color(0xFFA1887F));
    fill(2, 8, 18, 8, const Color(0xFF6D4C41));
    fill(9, 8, 4, 8, lockColor);
    fill(9, 10, 4, 2, const Color(0xFFB26A00));
    fill(1, 5, 20, 1, const Color(0xFF3E2723));
    fill(1, 16, 20, 1, const Color(0xFF3E2723));
    fill(0, 6, 1, 10, const Color(0xFF3E2723));
    fill(21, 6, 1, 10, const Color(0xFF3E2723));
    fill(10, 11, 2, 2, const Color(0xFF5D4037));
    fill(
      9,
      9,
      4,
      1,
      Color.lerp(const Color(0xFFFFE082), Colors.white, flashProgress)!,
    );
    if (flashProgress > 0) {
      fill(11, 8, 1, 1, Colors.white.withValues(alpha: 0.9));
    }
  }

  @override
  bool shouldRepaint(covariant _PixelChestPainter oldDelegate) {
    return oldDelegate.lockFlash != lockFlash;
  }
}

class _ParchmentSection extends StatefulWidget {
  const _ParchmentSection({
    required this.title,
    required this.icon,
    required this.child,
    this.badge,
    this.hoverLift = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? badge;
  final bool hoverLift;

  @override
  State<_ParchmentSection> createState() => _ParchmentSectionState();
}

class _ParchmentSectionState extends State<_ParchmentSection> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final highlight = widget.hoverLift && (_hovered || _pressed);

    return MouseRegion(
      onEnter: widget.hoverLift ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.hoverLift ? (_) => setState(() => _hovered = false) : null,
      child: Listener(
        onPointerDown: widget.hoverLift
            ? (_) => setState(() => _pressed = true)
            : null,
        onPointerUp: widget.hoverLift
            ? (_) => setState(() => _pressed = false)
            : null,
        onPointerCancel: widget.hoverLift
            ? (_) => setState(() => _pressed = false)
            : null,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 110),
          tween: Tween<double>(begin: 0, end: highlight ? -8 : 0),
          curve: Curves.easeOut,
          builder: (context, y, child) {
            return Transform.translate(offset: Offset(0, y), child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.parchment,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.woodFrame, width: 3),
              boxShadow: [
                const BoxShadow(
                  color: AppColors.shadowHard,
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
                if (highlight)
                  BoxShadow(
                    color: AppColors.stampGreen.withValues(alpha: 0.28),
                    offset: const Offset(0, 0),
                    blurRadius: 10,
                    spreadRadius: 0.5,
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: 18, color: AppColors.navyBlue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AppColors.inkBrown,
                        ),
                      ),
                    ),
                    ...?(widget.badge == null ? null : [widget.badge!]),
                  ],
                ),
                const SizedBox(height: 8),
                widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final QuestStatus status;

  @override
  Widget build(BuildContext context) {
    final (text, tint) = switch (status) {
      QuestStatus.available => ('Available', AppColors.stampGreen),
      QuestStatus.submitted => ('Submitted', const Color(0xFFB26A00)),
      QuestStatus.approved => ('Approved', AppColors.apSapphire),
      QuestStatus.rejected => ('Retry', AppColors.hpRuby),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.65), width: 1.6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: tint,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatGemChip extends StatelessWidget {
  const _StatGemChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EED7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7B5A3C), width: 2),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navyBlue,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.inkBrown,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _PixelMeter extends StatelessWidget {
  const _PixelMeter({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.hpTrack,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.woodFrame, width: 1.8),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: clamped,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StampButton extends StatefulWidget {
  const _StampButton({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final _StampTone tone;
  final VoidCallback? onPressed;

  @override
  State<_StampButton> createState() => _StampButtonState();
}

class _StampButtonState extends State<_StampButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final palette = _buttonPalette(widget.tone, enabled);

    return GestureDetector(
      onTapDown: enabled
          ? (_) {
              setState(() {
                _pressed = true;
              });
            }
          : null,
      onTapUp: enabled
          ? (_) {
              setState(() {
                _pressed = false;
              });
            }
          : null,
      onTapCancel: enabled
          ? () {
              setState(() {
                _pressed = false;
              });
            }
          : null,
      onTap: widget.onPressed,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 70),
        offset: _pressed ? const Offset(0, 0.08) : Offset.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _pressed ? palette.pressedFace : palette.face,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              top: BorderSide(color: palette.edge, width: 2.2),
              left: BorderSide(color: palette.edge, width: 2.2),
              right: BorderSide(color: palette.edge, width: 2.2),
              bottom: BorderSide(
                color: palette.edge,
                width: _pressed ? 1.4 : 5,
              ),
            ),
            boxShadow: _pressed
                ? const []
                : [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.65),
                      offset: const Offset(0, 2),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: palette.text),
              const SizedBox(width: 6),
              Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonPalette {
  const _ButtonPalette({
    required this.face,
    required this.pressedFace,
    required this.edge,
    required this.shadow,
    required this.text,
  });

  final Color face;
  final Color pressedFace;
  final Color edge;
  final Color shadow;
  final Color text;
}

_ButtonPalette _buttonPalette(_StampTone tone, bool enabled) {
  final raw = switch (tone) {
    _StampTone.wood => const _ButtonPalette(
      face: AppColors.woodButton,
      pressedFace: Color(0xFF775A52),
      edge: AppColors.woodButtonEdge,
      shadow: Color(0xFF4E342E),
      text: Color(0xFFF9F4EA),
    ),
    _StampTone.green => const _ButtonPalette(
      face: AppColors.submitGreen,
      pressedFace: Color(0xFF2E8B33),
      edge: AppColors.submitGreenEdge,
      shadow: Color(0xFF1B5E20),
      text: Color(0xFFF4F8EC),
    ),
    _StampTone.ruby => const _ButtonPalette(
      face: Color(0xFFD32F2F),
      pressedFace: Color(0xFFB71C1C),
      edge: Color(0xFF7F1111),
      shadow: Color(0xFF601010),
      text: Color(0xFFFDF1EF),
    ),
    _StampTone.blue => const _ButtonPalette(
      face: Color(0xFF1976D2),
      pressedFace: Color(0xFF125CA6),
      edge: Color(0xFF103F72),
      shadow: Color(0xFF0B2A4D),
      text: Color(0xFFEAF3FE),
    ),
  };

  if (enabled) {
    return raw;
  }

  return _ButtonPalette(
    face: raw.face.withValues(alpha: 0.45),
    pressedFace: raw.pressedFace.withValues(alpha: 0.45),
    edge: raw.edge.withValues(alpha: 0.5),
    shadow: raw.shadow.withValues(alpha: 0.35),
    text: raw.text.withValues(alpha: 0.55),
  );
}

IconData _questCategoryIcon(QuestCategory category) {
  return switch (category) {
    QuestCategory.chore => Icons.home_repair_service,
    QuestCategory.study => Icons.menu_book_rounded,
    QuestCategory.exam => Icons.fact_check_rounded,
    QuestCategory.habit => Icons.self_improvement,
    QuestCategory.unknown => Icons.map,
  };
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} $hour:$minute';
}
