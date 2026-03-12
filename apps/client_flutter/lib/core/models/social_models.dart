import '../../features/quests/models.dart'
    show FriendProfile, FriendRequestInfo, GuildInviteInfo, SocialProfile;

export '../../features/quests/models.dart'
    show
        FriendProfile,
        FriendRequestInfo,
        GuildInviteInfo,
        PlayerPassQrBundle,
        SocialProfile;

class SocialSnapshot {
  const SocialSnapshot({
    required this.friends,
    required this.pendingInvites,
    required this.incomingFriendRequests,
    required this.profile,
  });

  factory SocialSnapshot.empty() {
    return const SocialSnapshot(
      friends: <FriendProfile>[],
      pendingInvites: <GuildInviteInfo>[],
      incomingFriendRequests: <FriendRequestInfo>[],
      profile: null,
    );
  }

  final List<FriendProfile> friends;
  final List<GuildInviteInfo> pendingInvites;
  final List<FriendRequestInfo> incomingFriendRequests;
  final SocialProfile? profile;

  SocialSnapshot copyWith({
    List<FriendProfile>? friends,
    List<GuildInviteInfo>? pendingInvites,
    List<FriendRequestInfo>? incomingFriendRequests,
    SocialProfile? profile,
    bool clearProfile = false,
  }) {
    return SocialSnapshot(
      friends: friends ?? this.friends,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      incomingFriendRequests:
          incomingFriendRequests ?? this.incomingFriendRequests,
      profile: clearProfile ? null : (profile ?? this.profile),
    );
  }
}
