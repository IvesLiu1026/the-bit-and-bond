import 'package:flutter_test/flutter_test.dart';
import 'package:the_bit_and_bond_client/core/models/social_models.dart';
import 'package:the_bit_and_bond_client/features/game/shell/game_shell_social_inbox_tracker.dart';

void main() {
  test('initial snapshot bootstraps without firing friend request notice', () {
    final tracker = GameShellSocialInboxTracker();

    final update = tracker.consumeSnapshot(
      snapshot: SocialSnapshot(
        friends: const <FriendProfile>[],
        pendingInvites: <GuildInviteInfo>[_invite('invite-existing')],
        incomingFriendRequests: <FriendRequestInfo>[
          _friendRequest('request-existing'),
        ],
        profile: null,
      ),
    );

    expect(update.hasNewIncomingFriendRequest, isFalse);
    expect(update.shouldClearActiveInvite, isFalse);
    expect(update.inviteToShow?.id, 'invite-existing');
  });

  test('new incoming friend request ids trigger notice even at same count', () {
    final tracker = GameShellSocialInboxTracker();

    tracker.consumeSnapshot(
      snapshot: SocialSnapshot(
        friends: const <FriendProfile>[],
        pendingInvites: const <GuildInviteInfo>[],
        incomingFriendRequests: <FriendRequestInfo>[
          _friendRequest('request-a'),
        ],
        profile: null,
      ),
    );

    final update = tracker.consumeSnapshot(
      snapshot: SocialSnapshot(
        friends: const <FriendProfile>[],
        pendingInvites: const <GuildInviteInfo>[],
        incomingFriendRequests: <FriendRequestInfo>[
          _friendRequest('request-b'),
        ],
        profile: null,
      ),
    );

    expect(update.hasNewIncomingFriendRequest, isTrue);
    expect(update.inviteToShow, isNull);
    expect(update.shouldClearActiveInvite, isFalse);
  });

  test(
    'invite updates surface newcomers and clear stale active invite ids',
    () {
      final tracker = GameShellSocialInboxTracker();

      tracker.consumeSnapshot(
        snapshot: SocialSnapshot(
          friends: const <FriendProfile>[],
          pendingInvites: <GuildInviteInfo>[_invite('invite-a')],
          incomingFriendRequests: const <FriendRequestInfo>[],
          profile: null,
        ),
      );

      final update = tracker.consumeSnapshot(
        snapshot: SocialSnapshot(
          friends: const <FriendProfile>[],
          pendingInvites: <GuildInviteInfo>[_invite('invite-b')],
          incomingFriendRequests: const <FriendRequestInfo>[],
          profile: null,
        ),
        activeInviteId: 'invite-a',
      );

      expect(update.shouldClearActiveInvite, isTrue);
      expect(update.inviteToShow?.id, 'invite-b');
      expect(update.hasNewIncomingFriendRequest, isFalse);
    },
  );
}

FriendRequestInfo _friendRequest(String id) {
  return FriendRequestInfo(
    id: id,
    requesterHunterId: '00000000-0000-0000-0000-000000000099',
    requesterPlayerId: 'demo_friend',
    requesterName: 'Demo Friend',
    targetHunterId: '00000000-0000-0000-0000-000000000011',
    targetPlayerId: 'demo_member',
    targetName: 'Demo Member',
    status: 'pending',
    createdAt: DateTime(2026, 3, 11, 12, 0),
    respondedAt: null,
  );
}

GuildInviteInfo _invite(String id) {
  return GuildInviteInfo(
    id: id,
    guildId: '00000000-0000-0000-0000-000000000001',
    inviterHunterId: '00000000-0000-0000-0000-000000000099',
    inviterPlayerId: 'demo_friend',
    inviterName: 'Demo Friend',
    invitedHunterId: '00000000-0000-0000-0000-000000000011',
    invitedPlayerId: 'demo_member',
    invitedName: 'Demo Member',
    status: 'pending',
    createdAt: DateTime(2026, 3, 11, 12, 0),
    respondedAt: null,
  );
}
