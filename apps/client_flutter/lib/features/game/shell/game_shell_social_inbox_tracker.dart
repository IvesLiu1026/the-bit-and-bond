import '../../../core/models/social_models.dart';

class GameShellSocialInboxUpdate {
  const GameShellSocialInboxUpdate({
    required this.hasNewIncomingFriendRequest,
    required this.shouldClearActiveInvite,
    this.inviteToShow,
  });

  final bool hasNewIncomingFriendRequest;
  final bool shouldClearActiveInvite;
  final GuildInviteInfo? inviteToShow;
}

class GameShellSocialInboxTracker {
  bool _bootstrapped = false;
  Set<String> _knownIncomingFriendRequestIds = <String>{};
  Set<String> _knownPendingInviteIds = <String>{};

  GameShellSocialInboxUpdate consumeSnapshot({
    required SocialSnapshot snapshot,
    String? activeInviteId,
  }) {
    final incomingIds = snapshot.incomingFriendRequests
        .map((request) => request.id)
        .toSet();
    final pendingIds = snapshot.pendingInvites
        .map((invite) => invite.id)
        .toSet();

    final hasNewIncomingFriendRequest =
        _bootstrapped &&
        incomingIds.any(
          (requestId) => !_knownIncomingFriendRequestIds.contains(requestId),
        );

    GuildInviteInfo? inviteToShow;
    if (!_bootstrapped) {
      if (activeInviteId == null && snapshot.pendingInvites.isNotEmpty) {
        inviteToShow = snapshot.pendingInvites.first;
      }
    } else {
      for (final invite in snapshot.pendingInvites) {
        if (!_knownPendingInviteIds.contains(invite.id)) {
          inviteToShow = invite;
          break;
        }
      }
    }

    final shouldClearActiveInvite =
        activeInviteId != null && !pendingIds.contains(activeInviteId);

    _knownIncomingFriendRequestIds = incomingIds;
    _knownPendingInviteIds = pendingIds;
    _bootstrapped = true;

    return GameShellSocialInboxUpdate(
      hasNewIncomingFriendRequest: hasNewIncomingFriendRequest,
      shouldClearActiveInvite: shouldClearActiveInvite,
      inviteToShow: inviteToShow,
    );
  }

  void reset() {
    _bootstrapped = false;
    _knownIncomingFriendRequestIds = <String>{};
    _knownPendingInviteIds = <String>{};
  }
}
