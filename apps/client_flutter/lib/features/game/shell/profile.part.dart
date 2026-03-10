part of '../game_shell_page.dart';

class _PlayerProfileDialog extends StatefulWidget {
  const _PlayerProfileDialog({
    required this.socialState,
    required this.progressionState,
    required this.statsState,
    required this.onlineHunterIds,
    required this.onSaveMotto,
  });

  final AsyncValue<SocialSnapshot> socialState;
  final AsyncValue<Progression> progressionState;
  final AsyncValue<HunterStatsSummary?> statsState;
  final Set<String> onlineHunterIds;
  final Future<void> Function(String motto) onSaveMotto;

  @override
  State<_PlayerProfileDialog> createState() => _PlayerProfileDialogState();
}

class _PlayerProfileDialogState extends State<_PlayerProfileDialog> {
  final TextEditingController _mottoController = TextEditingController();
  bool _savingMotto = false;
  String? _mottoSeed;

  @override
  void dispose() {
    _mottoController.dispose();
    super.dispose();
  }

  void _syncMottoFromProfile(SocialProfile? profile) {
    final source = profile?.motto ?? '';
    if (_mottoSeed == source) {
      return;
    }
    _mottoSeed = source;
    _mottoController.text = source;
  }

  Future<void> _submitMotto() async {
    if (_savingMotto) {
      return;
    }
    final motto = _mottoController.text.trim();
    setState(() {
      _savingMotto = true;
    });
    try {
      await widget.onSaveMotto(motto);
    } finally {
      if (mounted) {
        setState(() {
          _savingMotto = false;
          _mottoSeed = motto;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final socialState = widget.socialState;
    final profile = socialState.maybeWhen(
      data: (s) => s.profile,
      orElse: () => null,
    );
    _syncMottoFromProfile(profile);

    final progression = widget.progressionState.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );
    final hunterStats = widget.statsState.maybeWhen(
      data: (stats) => stats,
      orElse: () => null,
    );
    final friends = socialState.maybeWhen(
      data: (s) => s.friends,
      orElse: () => const <FriendProfile>[],
    );
    final tag = profile?.hunterTag ?? 'ID-UNKNOWN';
    final level = profile?.level ?? progression?.level ?? 1;
    final xp = profile?.xp ?? progression?.xp ?? 0;
    final coins = profile?.coins ?? progression?.coins ?? 0;

    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _PixelLabelGlyph(glyph: 'ID'),
              const SizedBox(width: 8),
              Text(
                strings.tr(zh: '玩家通行證', en: 'Player Pass'),
                style: const TextStyle(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE7DDC9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.woodFrame, width: 2.2),
            ),
            child: TabBar(
              indicatorColor: AppColors.navyBlue,
              labelColor: AppColors.navyBlue,
              unselectedLabelColor: AppColors.inkBrown,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900),
              tabs: [
                Tab(
                  text: strings.tr(zh: '通行證', en: 'Pass'),
                ),
                Tab(
                  text: strings.tr(zh: '夥伴', en: 'Friends'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  children: [
                    Text(
                      '${profile?.displayName ?? strings.tr(zh: '目前玩家', en: 'Current Player')}  #$tag',
                      style: const TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.tr(
                        zh: '家庭：${profile?.guildName ?? '-'}｜身份：${profile?.roleTitle ?? '成員'}',
                        en: 'Family: ${profile?.guildName ?? '-'} | Role: ${profile?.roleTitle ?? 'Member'}',
                      ),
                      style: const TextStyle(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            title: strings.tr(zh: '等級', en: 'Level'),
                            value: '$level',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(title: 'XP', value: '$xp'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            title: strings.tr(zh: '金幣', en: 'Coins'),
                            value: '$coins',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _HunterRadarPanel(
                      statsState: widget.statsState,
                      stats: hunterStats,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8EED7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.woodFrame,
                          width: 2,
                        ),
                      ),
                      child: CustomPaint(
                        size: const Size(168, 168),
                        painter: _PseudoQrPainter(seed: tag),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PixelTextInput(
                      controller: _mottoController,
                      label: strings.tr(zh: '個人格言', en: 'Motto'),
                      hintText: strings.tr(
                        zh: '例如：每天前進一小步',
                        en: 'Ex: One small step every day',
                      ),
                      maxLength: 40,
                    ),
                    _StampButton(
                      label: _savingMotto
                          ? strings.tr(zh: '儲存中...', en: 'Saving...')
                          : strings.tr(zh: '儲存格言', en: 'Save Motto'),
                      icon: Icons.bookmark_add_rounded,
                      tone: _StampTone.blue,
                      onPressed: _savingMotto ? null : _submitMotto,
                    ),
                  ],
                ),
                ListView(
                  children: [
                    Text(
                      strings.tr(
                        zh: '夥伴 ${friends.length} 位',
                        en: '${friends.length} Friends',
                      ),
                      style: const TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      Text(
                        strings.tr(
                          zh: '目前沒有夥伴，先輸入玩家 ID 發送好友請求吧。',
                          en: 'No friends yet. Add one with a player ID first.',
                        ),
                        style: const TextStyle(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      ...friends.map((friend) {
                        final isOnline = widget.onlineHunterIds.contains(
                          friend.id,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8EED7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.woodFrame,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF9E9E9E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${friend.name} (@${friend.playerId})',
                                      style: const TextStyle(
                                        color: AppColors.inkBrown,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isOnline
                                          ? strings.tr(zh: '在線中', en: 'Online')
                                          : strings.tr(
                                              zh: '最近成就：Lv.${friend.level} · ${friend.xp} XP',
                                              en: 'Latest: Lv.${friend.level} · ${friend.xp} XP',
                                            ),
                                      style: TextStyle(
                                        color: isOnline
                                            ? AppColors.stampGreen
                                            : AppColors.navyBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
