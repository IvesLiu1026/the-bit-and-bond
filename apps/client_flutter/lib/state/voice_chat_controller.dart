import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:uuid/uuid.dart';

import '../core/auth/auth_session.dart';
import '../core/l10n/app_strings.dart';
import '../core/models/models.dart';
import '../core/network/api_client.dart';
import 'providers.dart';

final voiceChatControllerProvider =
    StateNotifierProvider<VoiceChatController, VoiceChatState>((ref) {
      final api = ref.watch(apiClientProvider);
      final session = ref.watch(authSessionProvider);
      final strings = ref.watch(appStringsProvider);
      return VoiceChatController(api: api, session: session, strings: strings);
    });

class VoiceChatState {
  const VoiceChatState({
    required this.connecting,
    required this.connected,
    required this.micEnabled,
    required this.roomId,
    required this.chatTopic,
    required this.messages,
    required this.participantCount,
    required this.activeSpeakerIdentities,
    required this.errorMessage,
  });

  const VoiceChatState.initial()
    : connecting = false,
      connected = false,
      micEnabled = false,
      roomId = null,
      chatTopic = 'guild.chat',
      messages = const [],
      participantCount = 0,
      activeSpeakerIdentities = const {},
      errorMessage = null;

  final bool connecting;
  final bool connected;
  final bool micEnabled;
  final String? roomId;
  final String chatTopic;
  final List<ChatMessage> messages;
  final int participantCount;
  final Set<String> activeSpeakerIdentities;
  final String? errorMessage;

  VoiceChatState copyWith({
    bool? connecting,
    bool? connected,
    bool? micEnabled,
    String? roomId,
    bool clearRoomId = false,
    String? chatTopic,
    List<ChatMessage>? messages,
    int? participantCount,
    Set<String>? activeSpeakerIdentities,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceChatState(
      connecting: connecting ?? this.connecting,
      connected: connected ?? this.connected,
      micEnabled: micEnabled ?? this.micEnabled,
      roomId: clearRoomId ? null : (roomId ?? this.roomId),
      chatTopic: chatTopic ?? this.chatTopic,
      messages: messages ?? this.messages,
      participantCount: participantCount ?? this.participantCount,
      activeSpeakerIdentities:
          activeSpeakerIdentities ?? this.activeSpeakerIdentities,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class VoiceChatController extends StateNotifier<VoiceChatState> {
  VoiceChatController({
    required ApiClient api,
    required AuthSession? session,
    required AppStrings strings,
  }) : _api = api,
       _session = session,
       _strings = strings,
       super(const VoiceChatState.initial());

  final ApiClient _api;
  final AuthSession? _session;
  final AppStrings _strings;
  final Uuid _uuid = const Uuid();

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  int _roomEpoch = 0;

  void _applyState(VoiceChatState Function(VoiceChatState current) update) {
    if (!mounted) {
      return;
    }
    state = update(state);
  }

  Future<void> joinCampfire() async {
    if (state.connected || state.connecting) {
      return;
    }
    if (_session == null) {
      state = state.copyWith(errorMessage: _strings.voiceLoginRequiredError);
      return;
    }

    final epoch = ++_roomEpoch;
    _applyState(
      (current) => current.copyWith(connecting: true, clearError: true),
    );
    try {
      final bundle = await _api.issueVoiceToken();
      await _teardown();
      if (!mounted) {
        return;
      }
      if (epoch != _roomEpoch) {
        return;
      }

      final room = lk.Room();
      final listener = room.createListener();
      listener
        ..on<lk.RoomDisconnectedEvent>((_) {
          if (!mounted) {
            return;
          }
          if (epoch != _roomEpoch) {
            return;
          }
          _applyState(
            (current) => current.copyWith(
              connected: false,
              connecting: false,
              micEnabled: false,
              participantCount: 0,
              activeSpeakerIdentities: <String>{},
              clearError: true,
            ),
          );
        })
        ..on<lk.ParticipantConnectedEvent>((_) => _syncParticipantStatus())
        ..on<lk.ParticipantDisconnectedEvent>((_) => _syncParticipantStatus())
        ..on<lk.ActiveSpeakersChangedEvent>((_) => _syncParticipantStatus())
        ..on<lk.DataReceivedEvent>(_onDataReceived);

      await room
          .connect(bundle.url, bundle.token)
          .timeout(const Duration(seconds: 12));
      if (!mounted) {
        await room.disconnect();
        await room.dispose();
        return;
      }
      if (epoch != _roomEpoch) {
        await room.disconnect();
        await room.dispose();
        return;
      }

      _room = room;
      _listener = listener;

      _applyState(
        (current) => current.copyWith(
          connecting: false,
          connected: true,
          micEnabled: false,
          roomId: bundle.roomId,
          chatTopic: bundle.chatTopic,
          clearError: true,
        ),
      );
      _syncParticipantStatus();

      try {
        await _setMicrophoneEnabled(true).timeout(const Duration(seconds: 6));
        _applyState(
          (current) => current.copyWith(micEnabled: true, clearError: true),
        );
      } catch (error) {
        _applyState(
          (current) => current.copyWith(
            errorMessage: _strings.voiceMicStartFailed(error),
          ),
        );
      }

      try {
        final history = await _api.getChatHistory(
          roomId: bundle.roomId,
          limit: 80,
        );
        _applyState((current) => current.copyWith(messages: history));
      } catch (error) {
        _applyState(
          (current) => current.copyWith(
            errorMessage: _strings.voiceHistorySyncFailed(error),
          ),
        );
      }
    } catch (error) {
      await _teardown();
      if (!mounted) {
        return;
      }
      if (epoch != _roomEpoch) {
        return;
      }
      _applyState(
        (current) => current.copyWith(
          connecting: false,
          connected: false,
          micEnabled: false,
          participantCount: 0,
          activeSpeakerIdentities: <String>{},
          errorMessage: _strings.voiceConnectFailed(error),
        ),
      );
    }
  }

  Future<void> leaveVoice() async {
    _roomEpoch++;
    await _teardown();
    _applyState(
      (current) => current.copyWith(
        connecting: false,
        connected: false,
        micEnabled: false,
        participantCount: 0,
        activeSpeakerIdentities: <String>{},
        clearRoomId: true,
        clearError: true,
      ),
    );
  }

  Future<void> toggleMic() async {
    if (!state.connected) {
      return;
    }
    final next = !state.micEnabled;
    try {
      await _setMicrophoneEnabled(next);
      _applyState(
        (current) => current.copyWith(micEnabled: next, clearError: true),
      );
    } catch (error) {
      _applyState(
        (current) => current.copyWith(
          errorMessage: _strings.voiceToggleMicFailed(error),
        ),
      );
    }
  }

  Future<void> sendChat(String rawContent) async {
    final content = rawContent.trim();
    if (content.isEmpty) {
      return;
    }
    final roomId = state.roomId;
    if (roomId == null || roomId.isEmpty) {
      _applyState(
        (current) =>
            current.copyWith(errorMessage: _strings.voiceSendRequiresJoinError),
      );
      return;
    }

    final clientMessageId = _uuid.v4();
    final sentAtMs = DateTime.now().millisecondsSinceEpoch;
    final optimistic = ChatMessage(
      id: 'local:$clientMessageId',
      guildId: _session?.guildId ?? '',
      roomId: roomId,
      senderHunterId: _session?.hunterId ?? '',
      senderName:
          _session?.displayName ??
          _session?.playerId ??
          _strings.currentPlayerLabel,
      clientMessageId: clientMessageId,
      content: content,
      sentAt: DateTime.fromMillisecondsSinceEpoch(sentAtMs),
      sentAtMs: sentAtMs,
    );
    _mergeMessage(optimistic);
    try {
      final persisted = await _api.persistChatMessage(
        content: content,
        roomId: roomId,
        clientMessageId: clientMessageId,
        sentAtMs: sentAtMs,
      );
      _mergeMessage(persisted);
      await _publishData(buildVoiceRoomChatPayload(persisted));
    } catch (error) {
      _applyState(
        (current) =>
            current.copyWith(errorMessage: _strings.voiceChatSendFailed(error)),
      );
    }
  }

  Future<void> refreshChatHistory({int limit = 80}) async {
    final roomId = state.roomId;
    if (!state.connected || roomId == null || roomId.isEmpty) {
      return;
    }
    try {
      final history = await _api.getChatHistory(roomId: roomId, limit: limit);
      for (final message in history) {
        _mergeMessage(message);
      }
    } catch (error) {
      debugPrint('refresh chat history failed: $error');
    }
  }

  Future<void> _publishData(Map<String, dynamic> payload) async {
    final localParticipant = _room?.localParticipant;
    if (localParticipant == null) {
      return;
    }
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    try {
      await (localParticipant as dynamic).publishData(
        bytes,
        reliable: true,
        topic: state.chatTopic,
      );
    } catch (error) {
      debugPrint('publishData failed: $error');
    }
  }

  Future<void> _setMicrophoneEnabled(bool enabled) async {
    final localParticipant = _room?.localParticipant;
    if (localParticipant == null) {
      return;
    }
    await (localParticipant as dynamic).setMicrophoneEnabled(enabled);
  }

  Future<void> _onDataReceived(lk.DataReceivedEvent event) async {
    try {
      final jsonRaw = utf8.decode(event.data);
      final decoded = jsonDecode(jsonRaw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final message = parseVoiceRoomChatPayload(decoded);
      if (message != null) {
        _mergeMessage(message);
      }
    } catch (error) {
      debugPrint('handle data channel message failed: $error');
    }
  }

  void _mergeMessage(ChatMessage message) {
    if (!mounted) {
      return;
    }
    final merged = [...state.messages];
    final sameIdIndex = merged.indexWhere((item) => item.id == message.id);
    if (sameIdIndex != -1) {
      merged[sameIdIndex] = message;
    } else {
      final sameClientMessageIndex = merged.indexWhere(
        (item) => item.clientMessageId == message.clientMessageId,
      );
      if (sameClientMessageIndex != -1) {
        merged[sameClientMessageIndex] = message;
      } else {
        merged.add(message);
      }
    }
    merged.sort((a, b) => a.sentAtMs.compareTo(b.sentAtMs));
    _applyState(
      (current) => current.copyWith(messages: merged, clearError: true),
    );
  }

  void _syncParticipantStatus() {
    if (!mounted) {
      return;
    }
    final room = _room;
    if (room == null) {
      return;
    }

    final dynamic remoteParticipantsRaw = (room as dynamic).remoteParticipants;
    final participantCount = switch (remoteParticipantsRaw) {
      Map<dynamic, dynamic> map => map.length + 1,
      Iterable<dynamic> iterable => iterable.length + 1,
      _ => 1,
    };

    final dynamic speakersRaw = (room as dynamic).activeSpeakers;
    final activeSpeakerIdentities = <String>{};
    if (speakersRaw is Iterable) {
      for (final speaker in speakersRaw) {
        final identity = (speaker as dynamic).identity as String?;
        if (identity != null && identity.trim().isNotEmpty) {
          activeSpeakerIdentities.add(identity);
        }
      }
    }

    _applyState(
      (current) => current.copyWith(
        participantCount: participantCount,
        activeSpeakerIdentities: activeSpeakerIdentities,
      ),
    );
  }

  Future<void> _teardown() async {
    final listener = _listener;
    _listener = null;
    if (listener != null) {
      try {
        (listener as dynamic).dispose();
      } catch (_) {}
    }

    final room = _room;
    _room = null;
    if (room != null) {
      try {
        await (room as dynamic).disconnect();
      } catch (_) {}
      try {
        await room.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    unawaited(_teardown());
    super.dispose();
  }
}

Map<String, dynamic> buildVoiceRoomChatPayload(ChatMessage message) {
  return <String, dynamic>{'type': 'chat.message', 'message': message.toJson()};
}

ChatMessage? parseVoiceRoomChatPayload(Map<String, dynamic> payload) {
  if (payload['type'] != 'chat.message') {
    return null;
  }
  final message = payload['message'];
  if (message is Map<String, dynamic>) {
    return ChatMessage.fromJson(message);
  }
  if (message is Map) {
    return ChatMessage.fromJson(Map<String, dynamic>.from(message));
  }

  final content = (payload['content'] as String?)?.trim();
  final roomId = (payload['room_id'] as String?)?.trim();
  final senderHunterId = (payload['sender_hunter_id'] as String?)?.trim();
  if (content == null ||
      content.isEmpty ||
      roomId == null ||
      roomId.isEmpty ||
      senderHunterId == null ||
      senderHunterId.isEmpty) {
    return null;
  }

  final sentAtMs =
      (payload['sent_at_ms'] as num?)?.toInt() ??
      DateTime.now().millisecondsSinceEpoch;
  final sentAt = DateTime.fromMillisecondsSinceEpoch(sentAtMs);
  final rawClientMessageId = (payload['client_message_id'] as String?)
      ?.trim()
      .replaceAll('local:', '');
  final clientMessageId =
      (rawClientMessageId == null || rawClientMessageId.isEmpty)
      ? 'live:$senderHunterId:$sentAtMs'
      : rawClientMessageId;

  return ChatMessage(
    id: ((payload['id'] as String?)?.trim())?.isNotEmpty == true
        ? (payload['id'] as String).trim()
        : 'live:$clientMessageId',
    guildId: (payload['guild_id'] as String?)?.trim() ?? '',
    roomId: roomId,
    senderHunterId: senderHunterId,
    senderName: (payload['sender_name'] as String?)?.trim().isNotEmpty == true
        ? (payload['sender_name'] as String).trim()
        : senderHunterId,
    clientMessageId: clientMessageId,
    content: content,
    sentAt: sentAt,
    sentAtMs: sentAtMs,
  );
}
