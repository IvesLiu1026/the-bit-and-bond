import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/settings/app_settings.dart';
import '../../../state/hunter_directory_controller.dart';
import '../../../state/providers.dart';
import '../../../state/quest_controller.dart';
import '../../../state/social_controller.dart';
import '../../../state/voice_chat_controller.dart';
import '../bitbond_game.dart';

class GameShellRealtimeMetrics {
  const GameShellRealtimeMetrics({
    required this.txPerSec,
    required this.rxPerSec,
    required this.lastInboundAtMs,
    required this.lastOutboundAtMs,
  });

  final double txPerSec;
  final double rxPerSec;
  final int lastInboundAtMs;
  final int lastOutboundAtMs;
}

typedef GameShellSocialSnapshotListener =
    void Function(SocialSnapshot snapshot);

class GameShellRuntimeCoordinator {
  GameShellRuntimeCoordinator({
    required WidgetRef ref,
    required TheBitAndBondGame game,
    required this.onInteractionHintChanged,
    required this.onOnlineHuntersChanged,
    required this.onNearbyFurnitureChanged,
    required this.onSandboxRoomIndexChanged,
    required this.onPresenceConnectedChanged,
    required this.onRealtimeMetricsChanged,
    required this.onSocialSnapshotChanged,
  }) : _ref = ref,
       _game = game;

  static const Duration _presenceSendInterval = Duration(milliseconds: 120);
  static const int _presenceHeartbeatMs = 900;
  static const int _movingSendIntervalMs = 75;
  static const int _idleSendIntervalMs = 280;
  static const double _minPoseDeltaForSync = 1.5;
  static const Duration _debugMeterWindow = Duration(seconds: 1);

  final WidgetRef _ref;
  final TheBitAndBondGame _game;
  final ValueChanged<String> onInteractionHintChanged;
  final ValueChanged<Set<String>> onOnlineHuntersChanged;
  final ValueChanged<TavernFurnitureType?> onNearbyFurnitureChanged;
  final ValueChanged<int> onSandboxRoomIndexChanged;
  final ValueChanged<bool> onPresenceConnectedChanged;
  final ValueChanged<GameShellRealtimeMetrics> onRealtimeMetricsChanged;
  final GameShellSocialSnapshotListener onSocialSnapshotChanged;

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
  int _debugSentInWindow = 0;
  int _debugReceivedInWindow = 0;
  double _debugSentPerSec = 0;
  double _debugReceivedPerSec = 0;
  int _lastInboundAtMs = 0;
  int _lastOutboundAtMs = 0;
  String _interactionHintText = '';
  Set<String> _onlineHunterIds = <String>{};
  TavernFurnitureType? _nearbyFurniture;
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
  bool _disposed = false;

  void start() {
    _game.interactionHintListenable.addListener(_syncInteractionHint);
    _game.activeHunterIdsListenable.addListener(_syncOnlineHunters);
    _game.nearbyFurnitureListenable.addListener(_syncNearbyFurniture);
    _game.sandboxRoomIndexListenable.addListener(_syncSandboxRoomIndex);
    _interactionHintText = _ref.read(appStringsProvider).leftJoystickHint;
    onInteractionHintChanged(_interactionHintText);
    _syncInteractionHint();
    _syncOnlineHunters();
    _syncNearbyFurniture();
    _syncSandboxRoomIndex();
    _latestAuthSession = _ref.read(authSessionProvider);
    _latestAppConfig = _ref.read(appConfigProvider);
    _game.setLanguage(_ref.read(appSettingsProvider).language);
    final initialVoiceState = _ref.read(voiceChatControllerProvider);
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
            _ref.read(appConfigProvider).apiBaseUrl,
      ),
    );
    _socialRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_disposed || _latestAuthSession == null) {
        return;
      }
      _ref.read(socialControllerProvider.notifier).refresh();
    });
    _startDebugMeter();
  }

  void dispose() {
    _disposed = true;
    _game.interactionHintListenable.removeListener(_syncInteractionHint);
    _game.activeHunterIdsListenable.removeListener(_syncOnlineHunters);
    _game.nearbyFurnitureListenable.removeListener(_syncNearbyFurniture);
    _game.sandboxRoomIndexListenable.removeListener(_syncSandboxRoomIndex);
    _authSessionSubscription?.close();
    _appConfigSubscription?.close();
    _appSettingsSubscription?.close();
    _questSubscription?.close();
    _hunterSubscription?.close();
    _socialSubscription?.close();
    _voiceSubscription?.close();
    _debugMeterTimer?.cancel();
    _debugMeterTimer = null;
    _socialRefreshTimer?.cancel();
    _socialRefreshTimer = null;
    _disconnectPresenceSync();
  }

  void _bindProviderSubscriptions() {
    _authSessionSubscription = _ref.listenManual<AuthSession?>(
      authSessionProvider,
      (previous, next) {
        _latestAuthSession = next;
        _game.setControlledHunterId(next?.hunterId);
        final apiBaseUrl =
            _latestAppConfig?.apiBaseUrl ??
            _ref.read(appConfigProvider).apiBaseUrl;
        unawaited(
          _syncDesiredPresenceConnection(session: next, apiBaseUrl: apiBaseUrl),
        );
        _syncHuntersToGame(
          _ref.read(hunterDirectoryControllerProvider),
          authSessionOverride: next,
        );
      },
    );

    _appConfigSubscription = _ref.listenManual<AppConfig>(appConfigProvider, (
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

    _appSettingsSubscription = _ref.listenManual<AppSettings>(
      appSettingsProvider,
      (previous, next) {
        if (previous?.language != next.language) {
          _game.setLanguage(next.language);
        }
      },
      fireImmediately: true,
    );

    _voiceSubscription = _ref.listenManual<VoiceChatState>(
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

    _questSubscription = _ref.listenManual<AsyncValue<List<QuestInstance>>>(
      questControllerProvider,
      (previous, next) {
        next.whenData(_game.syncQuests);
      },
      fireImmediately: true,
    );

    _hunterSubscription = _ref.listenManual<AsyncValue<List<HunterProfile>>>(
      hunterDirectoryControllerProvider,
      (previous, next) {
        _syncHuntersToGame(next);
      },
      fireImmediately: true,
    );

    _socialSubscription = _ref.listenManual<AsyncValue<SocialSnapshot>>(
      socialControllerProvider,
      (previous, next) {
        next.whenData(onSocialSnapshotChanged);
      },
      fireImmediately: true,
    );
  }

  void _startDebugMeter() {
    if (!kDebugMode) {
      return;
    }
    _debugMeterTimer?.cancel();
    _debugMeterTimer = Timer.periodic(_debugMeterWindow, (_) {
      if (_disposed) {
        return;
      }
      _debugSentPerSec = _debugSentInWindow.toDouble();
      _debugReceivedPerSec = _debugReceivedInWindow.toDouble();
      _debugSentInWindow = 0;
      _debugReceivedInWindow = 0;
      _emitRealtimeMetrics();
    });
  }

  void _setPresenceConnected(bool connected) {
    if (_presenceConnected == connected) {
      return;
    }
    _presenceConnected = connected;
    onPresenceConnectedChanged(connected);
  }

  void _recordOutboundPose([int count = 1]) {
    if (!kDebugMode) {
      return;
    }
    _debugSentInWindow += count;
    _lastOutboundAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _recordInboundPose([int count = 1]) {
    if (!kDebugMode) {
      return;
    }
    _debugReceivedInWindow += count;
    _lastInboundAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _emitRealtimeMetrics() {
    onRealtimeMetricsChanged(
      GameShellRealtimeMetrics(
        txPerSec: _debugSentPerSec,
        rxPerSec: _debugReceivedPerSec,
        lastInboundAtMs: _lastInboundAtMs,
        lastOutboundAtMs: _lastOutboundAtMs,
      ),
    );
  }

  void _syncInteractionHint() {
    if (_disposed) {
      return;
    }
    final next = _game.interactionHintListenable.value;
    if (next == null || next == _interactionHintText) {
      return;
    }
    _interactionHintText = next;
    onInteractionHintChanged(next);
  }

  void _syncOnlineHunters() {
    if (_disposed) {
      return;
    }
    final next = _game.activeHunterIdsListenable.value;
    if (next.length == _onlineHunterIds.length &&
        next.containsAll(_onlineHunterIds)) {
      return;
    }
    _onlineHunterIds = Set<String>.from(next);
    onOnlineHuntersChanged(_onlineHunterIds);
  }

  void _syncNearbyFurniture() {
    if (_disposed) {
      return;
    }
    final next = _game.nearbyFurnitureListenable.value;
    if (next == _nearbyFurniture) {
      return;
    }
    _nearbyFurniture = next;
    onNearbyFurnitureChanged(next);
  }

  void _syncSandboxRoomIndex() {
    if (_disposed) {
      return;
    }
    final next = _game.sandboxRoomIndexListenable.value;
    if (next == _sandboxCurrentRoomIndex) {
      return;
    }
    _sandboxCurrentRoomIndex = next;
    onSandboxRoomIndexChanged(next);
  }

  Future<void> _syncDesiredPresenceConnection({
    required AuthSession? session,
    required String apiBaseUrl,
  }) async {
    if (_disposed) {
      return;
    }
    if (session == null ||
        session.accessToken.isEmpty ||
        session.hunterId.trim().isEmpty) {
      _presenceConnectingKey = null;
      _disconnectPresenceSync();
      return;
    }

    final key = '$apiBaseUrl|${session.accessToken}';
    if (_presenceConnectionKey == key && _presenceChannel != null) {
      return;
    }

    _presenceConnectingKey = key;
    _cleanupPresenceChannel(clearKey: true);
    _presenceReconnectTimer?.cancel();
    _presenceReconnectTimer = null;

    final issuedTicket = await _issuePresenceTicket(key);
    if (issuedTicket == null || _disposed || _presenceConnectingKey != key) {
      return;
    }

    final uri = _buildPresenceUri(
      apiBaseUrl: apiBaseUrl,
      ticket: issuedTicket.ticket,
    );
    final channel = WebSocketChannel.connect(uri);
    _presenceChannel = channel;
    _presenceConnectionKey = key;
    _presenceConnectingKey = null;
    _lastSentPoseFingerprint = '';
    _lastSentPoseAtMs = 0;
    _lastSentPoseX = null;
    _lastSentPoseY = null;
    _lastSentFacing = 'down';
    _lastSentMoving = false;
    _setPresenceConnected(true);

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

  Uri _buildPresenceUri({required String apiBaseUrl, required String ticket}) {
    final base = Uri.parse(apiBaseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    final port = base.hasPort ? base.port : (wsScheme == 'wss' ? 443 : 80);
    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: port,
      path: '/api/v1/realtime/ws',
      queryParameters: {'ticket': ticket},
    );
  }

  Future<RealtimeWsTicket?> _issuePresenceTicket(String key) async {
    try {
      return await _ref.read(apiClientProvider).issueRealtimeTicket();
    } catch (_) {
      if (_disposed || _presenceConnectingKey != key) {
        return null;
      }
      _setPresenceConnected(false);
      _schedulePresenceReconnect();
      return null;
    }
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

    final lastX = _lastSentPoseX;
    final lastY = _lastSentPoseY;
    final hasLastPosition = lastX != null && lastY != null;
    final prevX = lastX ?? pose.x;
    final prevY = lastY ?? pose.y;
    final deltaSq =
        ((pose.x - prevX) * (pose.x - prevX)) +
        ((pose.y - prevY) * (pose.y - prevY));
    final movedEnough =
        !hasLastPosition ||
        deltaSq >= (_minPoseDeltaForSync * _minPoseDeltaForSync);
    final stateChanged =
        pose.facing != _lastSentFacing || pose.moving != _lastSentMoving;
    final minIntervalMs = pose.moving
        ? _movingSendIntervalMs
        : _idleSendIntervalMs;

    if (!stateChanged &&
        !movedEnough &&
        nowMs - _lastSentPoseAtMs < minIntervalMs) {
      return;
    }

    final unchanged = fingerprint == _lastSentPoseFingerprint;
    if (unchanged && nowMs - _lastSentPoseAtMs < _presenceHeartbeatMs) {
      return;
    }

    _lastSentPoseFingerprint = fingerprint;
    _lastSentPoseAtMs = nowMs;
    _lastSentPoseX = pose.x;
    _lastSentPoseY = pose.y;
    _lastSentFacing = pose.facing;
    _lastSentMoving = pose.moving;
    try {
      channel.sink.add(jsonEncode(pose.toClientMessage()));
      _recordOutboundPose();
    } catch (_) {
      _handlePresenceClosed(key);
    }
  }

  void _handlePresenceRaw(dynamic raw, String key) {
    if (_disposed || _presenceConnectionKey != key || raw is! String) {
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
      var applied = 0;
      for (final item in positions) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final pose = HunterRealtimePose.fromServerJson(item);
        if (pose == null) {
          continue;
        }
        _game.applyRemotePose(pose);
        applied++;
      }
      if (applied > 0) {
        _recordInboundPose(applied);
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
      _recordInboundPose();
      return;
    }

    if (type == 'chat_notice') {
      unawaited(
        _ref.read(voiceChatControllerProvider.notifier).refreshChatHistory(),
      );
    }
  }

  void _handlePresenceClosed(String key) {
    if (_disposed || _presenceConnectionKey != key) {
      return;
    }
    _cleanupPresenceChannel(clearKey: true);
    _schedulePresenceReconnect();
  }

  void _schedulePresenceReconnect() {
    _presenceReconnectTimer?.cancel();
    _presenceReconnectTimer = Timer(const Duration(seconds: 1), () {
      if (_disposed) {
        return;
      }
      final session = _ref.read(authSessionProvider);
      final appConfig = _ref.read(appConfigProvider);
      unawaited(
        _syncDesiredPresenceConnection(
          session: session,
          apiBaseUrl: appConfig.apiBaseUrl,
        ),
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
    _setPresenceConnected(false);

    if (clearKey) {
      _presenceConnectionKey = null;
      _presenceConnectingKey = null;
      _lastSentPoseFingerprint = '';
      _lastSentPoseAtMs = 0;
      _lastSentPoseX = null;
      _lastSentPoseY = null;
      _lastSentFacing = 'down';
      _lastSentMoving = false;
    }
  }

  void _syncHuntersToGame(
    AsyncValue<List<HunterProfile>> huntersState, {
    AuthSession? authSessionOverride,
  }) {
    final authSession =
        authSessionOverride ??
        _latestAuthSession ??
        _ref.read(authSessionProvider);

    final roster = huntersState.maybeWhen(
      data: (hunters) => List<HunterProfile>.from(hunters),
      orElse: () => <HunterProfile>[],
    );
    final controlledHunterId =
        authSession == null || authSession.hunterId.isEmpty
        ? null
        : authSession.hunterId;
    _game.setControlledHunterId(controlledHunterId);
    _game.syncHunters(roster, controlledHunterId: controlledHunterId);
  }
}
