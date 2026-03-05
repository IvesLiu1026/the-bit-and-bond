part of 'game_shell_page.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請輸入玩家 ID'),
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
    return _ParchmentSection(
      title: '社交召喚',
      icon: Icons.groups_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _playerIdController,
            decoration: InputDecoration(
              labelText: '玩家 ID',
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
          Row(
            children: [
              Expanded(
                child: _StampButton(
                  label: _submitting ? '處理中...' : '送好友請求',
                  icon: Icons.person_add_alt_1,
                  tone: _StampTone.blue,
                  onPressed: _submitting
                      ? null
                      : () => _run(widget.onAddFriend, clearOnSuccess: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StampButton(
                  label: _submitting ? '處理中...' : '召喚入會',
                  icon: Icons.mail_outline_rounded,
                  tone: _StampTone.green,
                  onPressed: _submitting
                      ? null
                      : () =>
                            _run(widget.onInviteFriend, clearOnSuccess: false),
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
                    '好友 ${snapshot.friends.length} 位',
                    style: const TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (snapshot.friends.isEmpty)
                    const Text(
                      '尚未新增好友',
                      style: TextStyle(color: AppColors.navyBlue),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: snapshot.friends
                          .map(
                            (friend) => _StatGemChip(
                              icon: const _PixelLabelGlyph(glyph: 'FR'),
                              label: '${friend.name} (@${friend.playerId})',
                              color: AppColors.navyBlue,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '好友請求 ${snapshot.incomingFriendRequests.length} 筆',
                    style: const TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (snapshot.incomingFriendRequests.isEmpty)
                    const Text(
                      '目前沒有待回覆好友請求',
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${request.requesterName} (@${request.requesterPlayerId})',
                                    style: const TextStyle(
                                      color: AppColors.inkBrown,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StampButton(
                                          label: '接受好友',
                                          icon: Icons.check_circle,
                                          tone: _StampTone.green,
                                          onPressed: () {
                                            widget.onRespondFriendRequest(
                                              requestId: request.id,
                                              accept: true,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _StampButton(
                                          label: '拒絕',
                                          icon: Icons.cancel,
                                          tone: _StampTone.ruby,
                                          onPressed: () {
                                            widget.onRespondFriendRequest(
                                              requestId: request.id,
                                              accept: false,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '收到邀請 ${snapshot.pendingInvites.length} 筆',
                    style: const TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (snapshot.pendingInvites.isEmpty)
                    const Text(
                      '目前沒有公會邀請',
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${invite.inviterName} (@${invite.inviterPlayerId})',
                                    style: const TextStyle(
                                      color: AppColors.inkBrown,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StampButton(
                                          label: '接受',
                                          icon: Icons.check_circle,
                                          tone: _StampTone.green,
                                          onPressed: () {
                                            widget.onRespondGuildInvite(
                                              inviteId: invite.id,
                                              accept: true,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _StampButton(
                                          label: '拒絕',
                                          icon: Icons.cancel,
                                          tone: _StampTone.ruby,
                                          onPressed: () {
                                            widget.onRespondGuildInvite(
                                              inviteId: invite.id,
                                              accept: false,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
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
              '社交資料載入失敗：$error',
              style: const TextStyle(
                color: AppColors.hpRuby,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
