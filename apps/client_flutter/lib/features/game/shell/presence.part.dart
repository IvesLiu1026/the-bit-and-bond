part of '../game_shell_page.dart';

extension _GameShellPresence on _GameShellPageState {
  void _startDebugMeter() {
    if (!kDebugMode) {
      return;
    }
    _debugMeterTimer?.cancel();
    _debugMeterTimer = Timer.periodic(_GameShellPageState._debugMeterWindow, (
      _,
    ) {
      if (!mounted) {
        return;
      }
      _applyState(() {
        _debugSentPerSec = _debugSentInWindow.toDouble();
        _debugReceivedPerSec = _debugReceivedInWindow.toDouble();
        _debugSentInWindow = 0;
        _debugReceivedInWindow = 0;
      });
    });
  }

  void _markPresenceConnected(bool connected) {
    if (_presenceConnected == connected) {
      return;
    }
    if (mounted && !_isDisposing) {
      _applyState(() {
        _presenceConnected = connected;
      });
      return;
    }
    _presenceConnected = connected;
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

  String _ageLabel(int timestampMs) {
    if (timestampMs <= 0) {
      return '--';
    }
    final ageMs = DateTime.now().millisecondsSinceEpoch - timestampMs;
    if (ageMs < 1000) {
      return '${ageMs}ms';
    }
    return '${(ageMs / 1000).toStringAsFixed(1)}s';
  }

  void _syncInteractionHint() {
    if (!mounted) {
      return;
    }
    final next = _game.interactionHintListenable.value;
    if (next == null || next == _interactionHintText) {
      return;
    }
    _applyState(() {
      _interactionHintText = next;
    });
  }

  void _syncOnlineHunters() {
    if (!mounted) {
      return;
    }
    final next = _game.activeHunterIdsListenable.value;
    if (next.length == _onlineHunterIds.length &&
        next.containsAll(_onlineHunterIds)) {
      return;
    }
    _applyState(() {
      _onlineHunterIds = Set<String>.from(next);
    });
  }

  void _syncNearbyFurniture() {
    if (!mounted) {
      return;
    }
    final next = _game.nearbyFurnitureListenable.value;
    if (next == _nearbyFurniture) {
      return;
    }
    _applyState(() {
      _nearbyFurniture = next;
    });
  }

  void _syncSandboxRoomIndex() {
    if (!mounted) {
      return;
    }
    final next = _game.sandboxRoomIndexListenable.value;
    if (next == _sandboxCurrentRoomIndex) {
      return;
    }
    _applyState(() {
      _sandboxCurrentRoomIndex = next;
    });
  }

  Future<void> _syncDesiredPresenceConnection({
    required AuthSession? session,
    required String apiBaseUrl,
  }) async {
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
    if (issuedTicket == null) {
      return;
    }
    if (!mounted || _isDisposing || _presenceConnectingKey != key) {
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
    _markPresenceConnected(true);

    _presenceSubscription = channel.stream.listen(
      (raw) => _handlePresenceRaw(raw, key),
      onDone: () => _handlePresenceClosed(key),
      onError: (_) => _handlePresenceClosed(key),
      cancelOnError: true,
    );
    _presenceSendTimer = Timer.periodic(
      _GameShellPageState._presenceSendInterval,
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
      return await ref.read(apiClientProvider).issueRealtimeTicket();
    } catch (_) {
      if (!mounted || _isDisposing || _presenceConnectingKey != key) {
        return null;
      }
      _markPresenceConnected(false);
      _presenceReconnectTimer?.cancel();
      _presenceReconnectTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted || _isDisposing) {
          return;
        }
        final session = ref.read(authSessionProvider);
        final appConfig = ref.read(appConfigProvider);
        unawaited(
          _syncDesiredPresenceConnection(
            session: session,
            apiBaseUrl: appConfig.apiBaseUrl,
          ),
        );
      });
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
        deltaSq >=
            (_GameShellPageState._minPoseDeltaForSync *
                _GameShellPageState._minPoseDeltaForSync);
    final stateChanged =
        pose.facing != _lastSentFacing || pose.moving != _lastSentMoving;
    final minIntervalMs = pose.moving
        ? _GameShellPageState._movingSendIntervalMs
        : _GameShellPageState._idleSendIntervalMs;

    if (!stateChanged &&
        !movedEnough &&
        nowMs - _lastSentPoseAtMs < minIntervalMs) {
      return;
    }

    final unchanged = fingerprint == _lastSentPoseFingerprint;
    if (unchanged &&
        nowMs - _lastSentPoseAtMs < _GameShellPageState._presenceHeartbeatMs) {
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
        ref.read(voiceChatControllerProvider.notifier).refreshChatHistory(),
      );
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
    _markPresenceConnected(false);

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
        ref.read(authSessionProvider);

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
