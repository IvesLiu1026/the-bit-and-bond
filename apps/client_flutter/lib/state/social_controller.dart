import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../features/quests/models.dart';
import 'providers.dart';

final socialControllerProvider =
    StateNotifierProvider<SocialController, AsyncValue<SocialSnapshot>>((ref) {
      final api = ref.watch(apiClientProvider);
      return SocialController(api: api)..load();
    });

class SocialSnapshot {
  SocialSnapshot({
    required this.friends,
    required this.pendingInvites,
    required this.incomingFriendRequests,
    required this.profile,
  });

  final List<FriendProfile> friends;
  final List<GuildInviteInfo> pendingInvites;
  final List<FriendRequestInfo> incomingFriendRequests;
  final SocialProfile? profile;
}

class SocialController extends StateNotifier<AsyncValue<SocialSnapshot>> {
  SocialController({required ApiClient api})
    : _api = api,
      super(const AsyncValue.loading());

  final ApiClient _api;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;

  Future<void> load() async {
    state = const AsyncValue.loading();
    await _refreshInternal();
  }

  Future<void> refresh() async {
    await _refreshInternal();
  }

  Future<FriendProfile> addFriend(String playerId) async {
    final friend = await _api.addFriend(playerId: playerId);
    await _refreshInternal();
    return friend;
  }

  Future<FriendRequestInfo> requestFriend(String playerId) async {
    final request = await _api.requestFriend(playerId: playerId);
    await _refreshInternal();
    return request;
  }

  Future<FriendRequestInfo> respondFriendRequest({
    required String requestId,
    required bool accept,
  }) async {
    final response = await _api.respondFriendRequest(
      requestId: requestId,
      accept: accept,
    );
    await _refreshInternal();
    return response;
  }

  Future<GuildInviteInfo> inviteToGuild(String playerId) async {
    final invite = await _api.inviteFriendToGuild(playerId: playerId);
    await _refreshInternal();
    return invite;
  }

  Future<GuildInviteInfo> respondInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final invite = await _api.respondGuildInvite(
      inviteId: inviteId,
      accept: accept,
    );
    await _refreshInternal();
    return invite;
  }

  Future<SocialProfile> updateMotto(String motto) async {
    final profile = await _api.updateSocialProfile(motto: motto);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        SocialSnapshot(
          friends: current.friends,
          pendingInvites: current.pendingInvites,
          incomingFriendRequests: current.incomingFriendRequests,
          profile: profile,
        ),
      );
    } else {
      await _refreshInternal();
    }
    return profile;
  }

  Future<void> _refreshInternal() async {
    if (_refreshInFlight) {
      _refreshQueued = true;
      return;
    }

    _refreshInFlight = true;
    try {
      do {
        _refreshQueued = false;
        final profile = await _api.getSocialProfile();
        List<FriendProfile> friends = const [];
        List<GuildInviteInfo> invites = const [];
        List<FriendRequestInfo> requests = const [];
        try {
          friends = await _api.listFriends();
          invites = await _api.listMyGuildInvites();
          requests = await _api.listIncomingFriendRequests();
        } on ApiException catch (error) {
          if (error.statusCode != 403) {
            rethrow;
          }
        }
        state = AsyncValue.data(
          SocialSnapshot(
            friends: friends,
            pendingInvites: invites,
            incomingFriendRequests: requests,
            profile: profile,
          ),
        );
      } while (_refreshQueued);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    } finally {
      _refreshInFlight = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(_refreshInternal());
      }
    }
  }
}
