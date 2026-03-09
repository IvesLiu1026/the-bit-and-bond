part of '../game_shell_page.dart';

class _SocialPanel extends StatefulWidget {
  const _SocialPanel({
    required this.state,
    required this.onAddFriend,
    required this.onInviteFriend,
    required this.onRespondFriendRequest,
    required this.onRespondGuildInvite,
  });

  final AsyncValue<SocialSnapshot> state;
  final Future<void> Function(String playerId) onAddFriend;
  final Future<void> Function(String playerId) onInviteFriend;
  final Future<void> Function({required String requestId, required bool accept})
  onRespondFriendRequest;
  final Future<void> Function({required String inviteId, required bool accept})
  onRespondGuildInvite;

  @override
  State<_SocialPanel> createState() => _SocialPanelState();
}

class _SocialPanelState extends State<_SocialPanel> {
  final TextEditingController _playerIdController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _playerIdController.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(String playerId) action, {
    bool clearOnSuccess = false,
  }) async {
    if (_submitting) {
      return;
    }
    final playerId = _playerIdController.text.trim();
    if (playerId.isEmpty) {
      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.tr(zh: '請輸入玩家 ID', en: 'Enter a Player ID')),
          backgroundColor: AppColors.hpRuby,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await action(playerId);
      if (clearOnSuccess) {
        _playerIdController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return _ParchmentSection(
      title: strings.tr(zh: '社交召喚', en: 'Social Links'),
      icon: Icons.groups_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackedPrimaryActions = constraints.maxWidth < 460;
          final stackedCardActions = constraints.maxWidth < 380;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _playerIdController,
                decoration: InputDecoration(
                  labelText: strings.tr(zh: '玩家 ID', en: 'Player ID'),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFE7DDC9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.woodFrame,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (stackedPrimaryActions)
                Column(
                  children: [
                    _StampButton(
                      label: _submitting
                          ? strings.tr(zh: '處理中...', en: 'Working...')
                          : strings.tr(zh: '送好友請求', en: 'Add Friend'),
                      icon: Icons.person_add_alt_1,
                      tone: _StampTone.blue,
                      onPressed: _submitting
                          ? null
                          : () =>
                                _run(widget.onAddFriend, clearOnSuccess: true),
                    ),
                    const SizedBox(height: 8),
                    _StampButton(
                      label: _submitting
                          ? strings.tr(zh: '處理中...', en: 'Working...')
                          : strings.tr(zh: '召喚入會', en: 'Invite to Family'),
                      icon: Icons.mail_outline_rounded,
                      tone: _StampTone.green,
                      onPressed: _submitting
                          ? null
                          : () => _run(
                              widget.onInviteFriend,
                              clearOnSuccess: false,
                            ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StampButton(
                      label: _submitting
                          ? strings.tr(zh: '處理中...', en: 'Working...')
                          : strings.tr(zh: '送好友請求', en: 'Add Friend'),
                      icon: Icons.person_add_alt_1,
                      tone: _StampTone.blue,
                      onPressed: _submitting
                          ? null
                          : () =>
                                _run(widget.onAddFriend, clearOnSuccess: true),
                    ),
                    _StampButton(
                      label: _submitting
                          ? strings.tr(zh: '處理中...', en: 'Working...')
                          : strings.tr(zh: '召喚入會', en: 'Invite to Family'),
                      icon: Icons.mail_outline_rounded,
                      tone: _StampTone.green,
                      onPressed: _submitting
                          ? null
                          : () => _run(
                              widget.onInviteFriend,
                              clearOnSuccess: false,
                            ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              widget.state.when(
                data: (snapshot) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.tr(
                          zh: '好友 ${snapshot.friends.length} 位',
                          en: '${snapshot.friends.length} Friends',
                        ),
                        style: const TextStyle(
                          color: AppColors.inkBrown,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (snapshot.friends.isEmpty)
                        Text(
                          strings.tr(zh: '尚未新增好友', en: 'No friends yet'),
                          style: TextStyle(color: AppColors.navyBlue),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: snapshot.friends
                              .map(
                                (friend) => ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  child: _StatGemChip(
                                    icon: const _PixelLabelGlyph(glyph: 'FR'),
                                    label:
                                        '${friend.name} (@${friend.playerId})',
                                    color: AppColors.navyBlue,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        strings.tr(
                          zh: '好友請求 ${snapshot.incomingFriendRequests.length} 筆',
                          en: '${snapshot.incomingFriendRequests.length} Friend Requests',
                        ),
                        style: const TextStyle(
                          color: AppColors.inkBrown,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (snapshot.incomingFriendRequests.isEmpty)
                        Text(
                          strings.tr(
                            zh: '目前沒有待回覆好友請求',
                            en: 'No pending friend requests',
                          ),
                          style: TextStyle(color: AppColors.navyBlue),
                        )
                      else
                        Column(
                          children: snapshot.incomingFriendRequests
                              .map(
                                (request) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8EED7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF7B5A3C),
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${request.requesterName} (@${request.requesterPlayerId})',
                                        style: const TextStyle(
                                          color: AppColors.inkBrown,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _SocialActionButtons(
                                        stacked: stackedCardActions,
                                        primaryLabel: strings.tr(
                                          zh: '接受好友',
                                          en: 'Accept',
                                        ),
                                        primaryIcon: Icons.check_circle,
                                        primaryTone: _StampTone.green,
                                        onPrimaryPressed: () {
                                          widget.onRespondFriendRequest(
                                            requestId: request.id,
                                            accept: true,
                                          );
                                        },
                                        secondaryLabel: strings.tr(
                                          zh: '拒絕',
                                          en: 'Decline',
                                        ),
                                        secondaryIcon: Icons.cancel,
                                        secondaryTone: _StampTone.ruby,
                                        onSecondaryPressed: () {
                                          widget.onRespondFriendRequest(
                                            requestId: request.id,
                                            accept: false,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        strings.tr(
                          zh: '收到邀請 ${snapshot.pendingInvites.length} 筆',
                          en: '${snapshot.pendingInvites.length} Invites',
                        ),
                        style: const TextStyle(
                          color: AppColors.inkBrown,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (snapshot.pendingInvites.isEmpty)
                        Text(
                          strings.tr(
                            zh: '目前沒有家庭邀請',
                            en: 'No family invites right now',
                          ),
                          style: TextStyle(color: AppColors.navyBlue),
                        )
                      else
                        Column(
                          children: snapshot.pendingInvites
                              .map(
                                (invite) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8EED7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF7B5A3C),
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${invite.inviterName} (@${invite.inviterPlayerId})',
                                        style: const TextStyle(
                                          color: AppColors.inkBrown,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _SocialActionButtons(
                                        stacked: stackedCardActions,
                                        primaryLabel: strings.tr(
                                          zh: '接受',
                                          en: 'Accept',
                                        ),
                                        primaryIcon: Icons.check_circle,
                                        primaryTone: _StampTone.green,
                                        onPrimaryPressed: () {
                                          widget.onRespondGuildInvite(
                                            inviteId: invite.id,
                                            accept: true,
                                          );
                                        },
                                        secondaryLabel: strings.tr(
                                          zh: '拒絕',
                                          en: 'Decline',
                                        ),
                                        secondaryIcon: Icons.cancel,
                                        secondaryTone: _StampTone.ruby,
                                        onSecondaryPressed: () {
                                          widget.onRespondGuildInvite(
                                            inviteId: invite.id,
                                            accept: false,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text(
                  strings.tr(
                    zh: '社交資料載入失敗：$error',
                    en: 'Failed to load social data: $error',
                  ),
                  style: const TextStyle(
                    color: AppColors.hpRuby,
                    fontWeight: FontWeight.w700,
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

class _SocialActionButtons extends StatelessWidget {
  const _SocialActionButtons({
    required this.stacked,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.primaryTone,
    required this.onPrimaryPressed,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.secondaryTone,
    required this.onSecondaryPressed,
  });

  final bool stacked;
  final String primaryLabel;
  final IconData primaryIcon;
  final _StampTone primaryTone;
  final VoidCallback onPrimaryPressed;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final _StampTone secondaryTone;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        children: [
          _StampButton(
            label: primaryLabel,
            icon: primaryIcon,
            tone: primaryTone,
            onPressed: onPrimaryPressed,
          ),
          const SizedBox(height: 6),
          _StampButton(
            label: secondaryLabel,
            icon: secondaryIcon,
            tone: secondaryTone,
            onPressed: onSecondaryPressed,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _StampButton(
          label: primaryLabel,
          icon: primaryIcon,
          tone: primaryTone,
          onPressed: onPrimaryPressed,
        ),
        _StampButton(
          label: secondaryLabel,
          icon: secondaryIcon,
          tone: secondaryTone,
          onPressed: onSecondaryPressed,
        ),
      ],
    );
  }
}
