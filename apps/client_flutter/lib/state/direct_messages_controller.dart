import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/auth/auth_session.dart';
import '../core/network/api_client.dart';
import '../core/security/dm_e2ee_service.dart';
import '../features/quests/models.dart';
import 'providers.dart';

final directMessagesControllerProvider =
    StateNotifierProvider<DirectMessagesController, DirectMessagesState>((ref) {
      final api = ref.watch(apiClientProvider);
      final session = ref.watch(authSessionProvider);
      final e2ee = ref.watch(dmE2eeServiceProvider);
      return DirectMessagesController(api: api, session: session, e2ee: e2ee)
        ..load();
    });

class DirectMessagesState {
  const DirectMessagesState({
    required this.loading,
    required this.refreshing,
    required this.sending,
    required this.contacts,
    required this.threads,
    required this.threadSecurityByCounterpart,
    required this.selectedCounterpartId,
    required this.messages,
    required this.errorMessage,
  });

  const DirectMessagesState.initial()
    : loading = true,
      refreshing = false,
      sending = false,
      contacts = const [],
      threads = const [],
      threadSecurityByCounterpart = const {},
      selectedCounterpartId = null,
      messages = const [],
      errorMessage = null;

  final bool loading;
  final bool refreshing;
  final bool sending;
  final List<FriendProfile> contacts;
  final List<DirectMessageThread> threads;
  final Map<String, DmThreadSecuritySnapshot> threadSecurityByCounterpart;
  final String? selectedCounterpartId;
  final List<DirectMessage> messages;
  final String? errorMessage;

  int get totalUnreadCount =>
      threads.fold<int>(0, (sum, thread) => sum + thread.unreadCount);

  DirectMessagesState copyWith({
    bool? loading,
    bool? refreshing,
    bool? sending,
    List<FriendProfile>? contacts,
    List<DirectMessageThread>? threads,
    Map<String, DmThreadSecuritySnapshot>? threadSecurityByCounterpart,
    String? selectedCounterpartId,
    bool clearSelectedCounterpartId = false,
    List<DirectMessage>? messages,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DirectMessagesState(
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      sending: sending ?? this.sending,
      contacts: contacts ?? this.contacts,
      threads: threads ?? this.threads,
      threadSecurityByCounterpart:
          threadSecurityByCounterpart ?? this.threadSecurityByCounterpart,
      selectedCounterpartId: clearSelectedCounterpartId
          ? null
          : (selectedCounterpartId ?? this.selectedCounterpartId),
      messages: messages ?? this.messages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DirectMessagesController extends StateNotifier<DirectMessagesState> {
  DirectMessagesController({
    required ApiClient api,
    required AuthSession? session,
    required DmE2eeService e2ee,
  }) : _api = api,
       _session = session,
       _e2ee = e2ee,
       super(const DirectMessagesState.initial());

  final ApiClient _api;
  final AuthSession? _session;
  final DmE2eeService _e2ee;
  final Uuid _uuid = const Uuid();
  int _refreshEpoch = 0;

  Future<void> load() async {
    if (_session == null) {
      state = const DirectMessagesState.initial().copyWith(
        loading: false,
        contacts: const [],
        threads: const [],
        messages: const [],
      );
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    await _bootstrapLocalEncryption(_session);
    await _refresh(preserveSelection: false);
  }

  Future<void> refresh() async {
    state = state.copyWith(refreshing: true, clearError: true);
    await _refresh(preserveSelection: true);
  }

  Future<void> selectCounterpart(String counterpartHunterId) async {
    final session = _session;
    state = state.copyWith(
      selectedCounterpartId: counterpartHunterId,
      refreshing: true,
      messages: const [],
      clearError: true,
    );
    if (session == null) {
      state = state.copyWith(refreshing: false, messages: const []);
      return;
    }
    try {
      final thread = _findThread(counterpartHunterId, state.threads);
      final security = await _resolveThreadSecurity(
        session: session,
        counterpartHunterId: counterpartHunterId,
        threadMode: thread?.encryptionMode ?? DmE2eeService.plaintextMode,
      );
      final messages = await _loadConversationMessages(
        session: session,
        counterpartHunterId: counterpartHunterId,
        security: security,
      );
      state = state.copyWith(
        refreshing: false,
        threadSecurityByCounterpart: {
          ...state.threadSecurityByCounterpart,
          counterpartHunterId: security,
        },
        messages: messages,
        clearError: true,
      );
      if ((thread?.unreadCount ?? 0) > 0) {
        await _markThreadRead(counterpartHunterId);
      }
    } catch (error) {
      state = state.copyWith(refreshing: false, errorMessage: '私訊讀取失敗：$error');
    }
  }

  Future<void> sendMessage(String content) async {
    final session = _session;
    final counterpartId = state.selectedCounterpartId;
    if (session == null || counterpartId == null || counterpartId.isEmpty) {
      return;
    }
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    state = state.copyWith(sending: true, clearError: true);
    try {
      final thread = _findThread(counterpartId, state.threads);
      final contact = _findContact(counterpartId, state.contacts);
      final threadMode = thread?.encryptionMode ?? DmE2eeService.plaintextMode;
      final security =
          state.threadSecurityByCounterpart[counterpartId] ??
          await _resolveThreadSecurity(
            session: session,
            counterpartHunterId: counterpartId,
            threadMode: threadMode,
          );
      final clientMessageId = _uuid.v4();
      final sentAt = DateTime.now();

      if (security.canEncryptNewMessages) {
        await _e2ee.sendEncryptedMessage(
          session: session,
          security: security,
          counterpartHunterId: counterpartId,
          counterpartName:
              thread?.counterpartName ?? contact?.name ?? counterpartId,
          counterpartPlayerId:
              thread?.counterpartPlayerId ?? contact?.playerId ?? '',
          counterpartGuildId:
              thread?.counterpartGuildId ?? contact?.guildId ?? session.guildId,
          content: trimmed,
          clientMessageId: clientMessageId,
          sentAt: sentAt,
        );
      } else {
        await _api.persistDirectMessage(
          recipientHunterId: counterpartId,
          content: trimmed,
          clientMessageId: clientMessageId,
          sentAtMs: sentAt.millisecondsSinceEpoch,
        );
      }

      final refreshedThreads = _sortThreads(
        await _api.listDirectMessageThreads(),
      );
      final refreshedSecurity = await _resolveSecurityMapFresh(
        session: session,
        contacts: state.contacts,
        threads: refreshedThreads,
      );
      final activeSecurity =
          refreshedSecurity[counterpartId] ??
          security.copyWith(threadMode: DmE2eeService.encryptedMode);
      final mergedMessages = await _loadConversationMessages(
        session: session,
        counterpartHunterId: counterpartId,
        security: activeSecurity,
      );
      state = state.copyWith(
        sending: false,
        threads: refreshedThreads,
        threadSecurityByCounterpart: refreshedSecurity,
        messages: mergedMessages,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(sending: false, errorMessage: '私訊發送失敗：$error');
    }
  }

  Future<void> _refresh({required bool preserveSelection}) async {
    final session = _session;
    final refreshEpoch = ++_refreshEpoch;
    if (session == null) {
      state = state.copyWith(
        loading: false,
        refreshing: false,
        contacts: const [],
        threads: const [],
        threadSecurityByCounterpart: const {},
        clearSelectedCounterpartId: true,
        messages: const [],
        clearError: true,
      );
      return;
    }
    try {
      final contactsFuture = _api.listFriends();
      final threadsFuture = _api.listDirectMessageThreads();
      final contacts = await contactsFuture;
      final threads = _sortThreads(await threadsFuture);
      String? nextSelected = preserveSelection
          ? state.selectedCounterpartId
          : null;
      if (nextSelected == null || nextSelected.isEmpty) {
        nextSelected = threads.isNotEmpty
            ? threads.first.counterpartHunterId
            : (contacts.isNotEmpty ? contacts.first.id : null);
      } else {
        final stillExists =
            contacts.any((contact) => contact.id == nextSelected) ||
            threads.any((thread) => thread.counterpartHunterId == nextSelected);
        if (!stillExists) {
          nextSelected = threads.isNotEmpty
              ? threads.first.counterpartHunterId
              : (contacts.isNotEmpty ? contacts.first.id : null);
        }
      }

      final cachedSecurityByCounterpart = _resolveCachedSecurityMap(
        session: session,
        contacts: contacts,
        threads: threads,
        seed: state.threadSecurityByCounterpart,
      );

      List<DirectMessage> messages = const <DirectMessage>[];
      if (nextSelected != null && nextSelected.isNotEmpty) {
        final thread = _findThread(nextSelected, threads);
        final security =
            cachedSecurityByCounterpart[nextSelected] ??
            DmThreadSecuritySnapshot(
              counterpartHunterId: nextSelected,
              threadMode: thread?.encryptionMode ?? DmE2eeService.plaintextMode,
              localIdentity: null,
              peerDeviceKeys: const [],
            );
        messages = await _loadConversationMessages(
          session: session,
          counterpartHunterId: nextSelected,
          security: security,
        );
      }

      if (refreshEpoch != _refreshEpoch) {
        return;
      }

      state = state.copyWith(
        loading: false,
        refreshing: false,
        contacts: contacts,
        threads: threads,
        threadSecurityByCounterpart: cachedSecurityByCounterpart,
        selectedCounterpartId: nextSelected,
        messages: messages,
        clearError: true,
      );

      unawaited(
        _revalidateSecurityMap(
          refreshEpoch: refreshEpoch,
          session: session,
          contacts: contacts,
          threads: threads,
          selectedCounterpartId: nextSelected,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        refreshing: false,
        errorMessage: '私訊列表讀取失敗：$error',
      );
    }
  }

  Future<void> _revalidateSecurityMap({
    required int refreshEpoch,
    required AuthSession session,
    required List<FriendProfile> contacts,
    required List<DirectMessageThread> threads,
    required String? selectedCounterpartId,
  }) async {
    try {
      final refreshedSecurity = await _resolveSecurityMapFresh(
        session: session,
        contacts: contacts,
        threads: threads,
        seed: state.threadSecurityByCounterpart,
      );

      if (refreshEpoch != _refreshEpoch) {
        return;
      }

      final activeSelected = state.selectedCounterpartId;
      if (selectedCounterpartId == null ||
          selectedCounterpartId.isEmpty ||
          selectedCounterpartId != activeSelected) {
        state = state.copyWith(
          threadSecurityByCounterpart: refreshedSecurity,
          clearError: true,
        );
        return;
      }

      final selectedSecurity = refreshedSecurity[selectedCounterpartId];
      if (selectedSecurity == null) {
        state = state.copyWith(
          threadSecurityByCounterpart: refreshedSecurity,
          clearError: true,
        );
        return;
      }
      final refreshedMessages = await _loadConversationMessages(
        session: session,
        counterpartHunterId: selectedCounterpartId,
        security: selectedSecurity,
      );

      if (refreshEpoch != _refreshEpoch ||
          state.selectedCounterpartId != selectedCounterpartId) {
        return;
      }
      state = state.copyWith(
        threadSecurityByCounterpart: refreshedSecurity,
        messages: refreshedMessages,
        clearError: true,
      );
    } catch (_) {
      // Keep cached snapshots if background revalidation fails.
    }
  }

  Future<void> _bootstrapLocalEncryption(AuthSession? session) async {
    if (session == null) {
      return;
    }
    try {
      await _e2ee.warmUp(session);
    } catch (_) {
      // Keep plaintext DM available if device-key bootstrap fails.
    }
  }

  Map<String, DmThreadSecuritySnapshot> _resolveCachedSecurityMap({
    required AuthSession session,
    required List<FriendProfile> contacts,
    required List<DirectMessageThread> threads,
    Map<String, DmThreadSecuritySnapshot> seed = const {},
  }) {
    final threadModeByCounterpart = <String, String>{
      for (final contact in contacts) contact.id: DmE2eeService.plaintextMode,
      for (final thread in threads)
        thread.counterpartHunterId: thread.encryptionMode,
    };
    final ids = threadModeByCounterpart.keys.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return <String, DmThreadSecuritySnapshot>{...seed};
    }
    final cachedSnapshots = _e2ee.cachedThreadSecuritySnapshots(
      session: session,
      counterpartHunterIds: ids,
      threadModeByCounterpart: threadModeByCounterpart,
    );
    final byCounterpart = <String, DmThreadSecuritySnapshot>{};
    for (final counterpartId in ids) {
      final thread = _findThread(counterpartId, threads);
      byCounterpart[counterpartId] =
          cachedSnapshots[counterpartId] ??
          byCounterpart[counterpartId] ??
          DmThreadSecuritySnapshot(
            counterpartHunterId: counterpartId,
            threadMode: thread?.encryptionMode ?? DmE2eeService.plaintextMode,
            localIdentity: null,
            peerDeviceKeys: const <DmDeviceKey>[],
          );
    }
    return byCounterpart;
  }

  Future<Map<String, DmThreadSecuritySnapshot>> _resolveSecurityMapFresh({
    required AuthSession session,
    required List<FriendProfile> contacts,
    required List<DirectMessageThread> threads,
    Map<String, DmThreadSecuritySnapshot> seed = const {},
  }) async {
    final threadModeByCounterpart = <String, String>{
      for (final contact in contacts) contact.id: DmE2eeService.plaintextMode,
      for (final thread in threads)
        thread.counterpartHunterId: thread.encryptionMode,
    };
    final ids = threadModeByCounterpart.keys.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return <String, DmThreadSecuritySnapshot>{...seed};
    }
    final byCounterpart = <String, DmThreadSecuritySnapshot>{};
    Map<String, DmThreadSecuritySnapshot> resolved;
    try {
      resolved = await _e2ee.resolveThreadSecurityBatch(
        session: session,
        counterpartHunterIds: ids,
        threadModeByCounterpart: threadModeByCounterpart,
      );
    } catch (_) {
      resolved = _e2ee.cachedThreadSecuritySnapshots(
        session: session,
        counterpartHunterIds: ids,
        threadModeByCounterpart: threadModeByCounterpart,
      );
    }
    for (final counterpartId in ids) {
      final thread = _findThread(counterpartId, threads);
      byCounterpart[counterpartId] =
          resolved[counterpartId] ??
          byCounterpart[counterpartId] ??
          DmThreadSecuritySnapshot(
            counterpartHunterId: counterpartId,
            threadMode: thread?.encryptionMode ?? DmE2eeService.plaintextMode,
            localIdentity: null,
            peerDeviceKeys: const <DmDeviceKey>[],
          );
    }
    return byCounterpart;
  }

  Future<DmThreadSecuritySnapshot> _resolveThreadSecurity({
    required AuthSession session,
    required String counterpartHunterId,
    required String threadMode,
  }) {
    return _e2ee.resolveThreadSecurity(
      session: session,
      counterpartHunterId: counterpartHunterId,
      threadMode: threadMode,
    );
  }

  Future<List<DirectMessage>> _loadConversationMessages({
    required AuthSession session,
    required String counterpartHunterId,
    required DmThreadSecuritySnapshot security,
  }) async {
    final plaintextMessages = await _api.getDirectMessageHistory(
      counterpartHunterId: counterpartHunterId,
      limit: 80,
    );
    List<DirectMessage> encryptedMessages = const [];
    if (security.isEncryptedThread || security.peerReady) {
      try {
        encryptedMessages = await _e2ee.loadEncryptedConversation(
          session: session,
          security: security,
          counterpartHunterId: counterpartHunterId,
          limit: 80,
        );
      } catch (_) {
        encryptedMessages = const [];
      }
    }
    return _mergeMessages(plaintextMessages, encryptedMessages);
  }

  List<DirectMessage> _mergeMessages(
    List<DirectMessage> plaintextMessages,
    List<DirectMessage> encryptedMessages,
  ) {
    final byKey = <String, DirectMessage>{};
    for (final message in [...plaintextMessages, ...encryptedMessages]) {
      final key = [
        message.encryptionMode,
        message.id,
        message.clientMessageId,
        message.sentAtMs,
      ].join('|');
      byKey[key] = message;
    }
    final merged = byKey.values.toList(growable: false)
      ..sort((a, b) {
        final byTime = a.sentAt.compareTo(b.sentAt);
        if (byTime != 0) {
          return byTime;
        }
        return a.id.compareTo(b.id);
      });
    return merged;
  }

  DirectMessageThread? _findThread(
    String counterpartHunterId,
    List<DirectMessageThread> threads,
  ) {
    for (final thread in threads) {
      if (thread.counterpartHunterId == counterpartHunterId) {
        return thread;
      }
    }
    return null;
  }

  FriendProfile? _findContact(
    String counterpartHunterId,
    List<FriendProfile> contacts,
  ) {
    for (final contact in contacts) {
      if (contact.id == counterpartHunterId) {
        return contact;
      }
    }
    return null;
  }

  Future<void> _markThreadRead(String counterpartHunterId) async {
    try {
      await _api.markDirectMessageThreadRead(
        counterpartHunterId: counterpartHunterId,
      );
      final patchedThreads = state.threads
          .map((thread) {
            if (thread.counterpartHunterId != counterpartHunterId) {
              return thread;
            }
            return DirectMessageThread(
              conversationKey: thread.conversationKey,
              counterpartHunterId: thread.counterpartHunterId,
              counterpartName: thread.counterpartName,
              counterpartPlayerId: thread.counterpartPlayerId,
              counterpartGuildId: thread.counterpartGuildId,
              counterpartAvatarType: thread.counterpartAvatarType,
              lastMessage: thread.lastMessage,
              lastMessageSenderHunterId: thread.lastMessageSenderHunterId,
              lastMessageSenderName: thread.lastMessageSenderName,
              lastMessageAt: thread.lastMessageAt,
              lastMessageAtMs: thread.lastMessageAtMs,
              encryptionMode: thread.encryptionMode,
              unreadCount: 0,
            );
          })
          .toList(growable: false);
      state = state.copyWith(
        threads: _sortThreads(patchedThreads),
        clearError: true,
      );
    } catch (_) {
      // Keep the conversation usable even if the read cursor update fails.
    }
  }

  List<DirectMessageThread> _sortThreads(List<DirectMessageThread> threads) {
    final sorted = [...threads];
    sorted.sort((a, b) {
      final aUnread = a.unreadCount > 0 ? 1 : 0;
      final bUnread = b.unreadCount > 0 ? 1 : 0;
      if (aUnread != bUnread) {
        return bUnread.compareTo(aUnread);
      }
      if (a.unreadCount != b.unreadCount) {
        return b.unreadCount.compareTo(a.unreadCount);
      }
      if (a.lastMessageAtMs != b.lastMessageAtMs) {
        return b.lastMessageAtMs.compareTo(a.lastMessageAtMs);
      }
      return a.counterpartName.compareTo(b.counterpartName);
    });
    return sorted;
  }
}
