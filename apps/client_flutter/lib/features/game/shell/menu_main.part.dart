part of '../game_shell_page.dart';

class _MainMenuPanel extends StatelessWidget {
  const _MainMenuPanel({
    required this.strings,
    required this.compact,
    required this.isMaster,
    required this.directMessageUnreadCount,
    required this.onClose,
    required this.onOpenTasks,
    required this.onOpenFamilyCenter,
    required this.onOpenRewards,
    required this.onOpenBag,
    required this.onOpenVoice,
    required this.onOpenHabits,
    required this.onOpenDirectMessages,
    required this.onOpenPhotoDump,
    required this.onOpenProfile,
    required this.onOpenSettings,
  });

  final AppStrings strings;
  final bool compact;
  final bool isMaster;
  final int directMessageUnreadCount;
  final VoidCallback onClose;
  final Future<void> Function() onOpenTasks;
  final Future<void> Function() onOpenFamilyCenter;
  final Future<void> Function() onOpenRewards;
  final Future<void> Function() onOpenBag;
  final Future<void> Function() onOpenVoice;
  final Future<void> Function() onOpenHabits;
  final Future<void> Function() onOpenDirectMessages;
  final Future<void> Function() onOpenPhotoDump;
  final Future<void> Function() onOpenProfile;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wideLayout = size.width >= 700;
    final crossAxisCount = wideLayout ? 3 : (compact ? 2 : 3);
    final childAspectRatio = wideLayout ? 1.38 : (compact ? 1.18 : 1.08);
    final cards = <_MainMenuEntry>[
      _MainMenuEntry(
        id: 'tasks',
        glyph: 'TSK',
        title: strings.tasks,
        subtitle: strings.taskBoard,
        tone: const Color(0xFFD9A441),
        onPressed: onOpenTasks,
      ),
      _MainMenuEntry(
        id: 'family',
        glyph: 'FAM',
        title: strings.familyCenter,
        subtitle: isMaster ? strings.familyDesk : strings.profile,
        tone: const Color(0xFF9A7354),
        onPressed: onOpenFamilyCenter,
      ),
      _MainMenuEntry(
        id: 'rewards',
        glyph: 'RWD',
        title: strings.rewards,
        subtitle: strings.rewardShelf,
        tone: AppColors.submitGreen,
        onPressed: onOpenRewards,
      ),
      _MainMenuEntry(
        id: 'bag',
        glyph: 'BAG',
        title: strings.bag,
        subtitle: strings.bag,
        tone: const Color(0xFFB28A58),
        onPressed: onOpenBag,
      ),
      _MainMenuEntry(
        id: 'voice',
        glyph: 'VOX',
        title: strings.voiceRoom,
        subtitle: strings.campfireRoom,
        tone: const Color(0xFFED8C34),
        onPressed: onOpenVoice,
      ),
      _MainMenuEntry(
        id: 'profile',
        glyph: 'ID',
        title: strings.profile,
        subtitle: strings.openProfile,
        tone: const Color(0xFF6ABFD6),
        onPressed: onOpenProfile,
      ),
      _MainMenuEntry(
        id: 'habits',
        glyph: 'HBT',
        title: strings.habits,
        subtitle: strings.tr(
          zh: '進度板、習慣挑戰、回傳照片',
          en: 'Progress board, challenges, proof shots',
        ),
        tone: const Color(0xFF8D6E63),
        onPressed: onOpenHabits,
      ),
      _MainMenuEntry(
        id: 'dm',
        glyph: 'DM',
        title: strings.directMessages,
        subtitle: directMessageUnreadCount > 0
            ? strings.tr(
                zh: '$directMessageUnreadCount 則未讀訊息等你回覆',
                en: '$directMessageUnreadCount unread messages waiting',
              )
            : strings.tr(
                zh: '朋友與家人的一對一聊天',
                en: '1-on-1 chats with friends and family',
              ),
        tone: const Color(0xFF7C5FB3),
        badgeLabel: directMessageUnreadCount > 0
            ? (directMessageUnreadCount > 99
                  ? '99+'
                  : '$directMessageUnreadCount')
            : null,
        onPressed: onOpenDirectMessages,
      ),
      _MainMenuEntry(
        id: 'photo_dump',
        glyph: 'PIC',
        title: strings.photoDump,
        subtitle: strings.tr(
          zh: '用像素相框記錄今天的照片',
          en: 'Capture today with pixel frames',
        ),
        tone: const Color(0xFFCE7F6D),
        onPressed: onOpenPhotoDump,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.gameplayMenuTitle,
                    style: TextStyle(
                      color: AppColors.inkBrown,
                      fontSize: compact ? 22 : 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.gameplayMenuSubtitle,
                    style: TextStyle(
                      color: AppColors.inkBrown.withValues(alpha: 0.74),
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _FloorplanCloseButton(onPressed: onClose),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            key: AppTestIds.mainMenuGridKey,
            padding: EdgeInsets.only(bottom: compact ? 8 : 0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: cards.length + 1,
            itemBuilder: (context, index) {
              if (index < cards.length) {
                return _MainMenuCard(entry: cards[index]);
              }
              return _MainMenuCard(
                entry: _MainMenuEntry(
                  id: 'settings',
                  glyph: 'CFG',
                  title: strings.settings,
                  subtitle: strings.settingsSubtitle,
                  tone: const Color(0xFF6F8CCF),
                  onPressed: onOpenSettings,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MainMenuEntry {
  const _MainMenuEntry({
    required this.id,
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.tone,
    this.badgeLabel,
    this.onPressed,
  });

  final String id;
  final String glyph;
  final String title;
  final String subtitle;
  final Color tone;
  final String? badgeLabel;
  final Future<void> Function()? onPressed;

  bool get enabled => onPressed != null;
}

class _MainMenuCard extends StatefulWidget {
  const _MainMenuCard({required this.entry});

  final _MainMenuEntry entry;

  @override
  State<_MainMenuCard> createState() => _MainMenuCardState();
}

class _MainMenuCardState extends State<_MainMenuCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.entry.enabled;
    final tone = widget.entry.tone;
    final cardColor = enabled
        ? tone.withValues(alpha: _pressed ? 0.2 : 0.12)
        : tone.withValues(alpha: 0.08);

    return GestureDetector(
      key: AppTestIds.mainMenuCard(widget.entry.id),
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? () => widget.entry.onPressed!.call() : null,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 70),
        offset: _pressed ? const Offset(0, 0.03) : Offset.zero,
        child: PixelPanel(
          tone: PixelTone.parchment,
          padding: const EdgeInsets.all(12),
          cut: 14,
          shadowDepth: _pressed || !enabled ? 1.5 : 4,
          faceColor: cardColor,
          edgeColor: enabled ? tone : tone.withValues(alpha: 0.4),
          shadowColor: enabled ? AppColors.shadowHard : AppColors.shadowHard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PixelLabelGlyph(glyph: widget.entry.glyph),
                  const Spacer(),
                  if (widget.entry.badgeLabel != null) ...[
                    PixelTag(
                      label: widget.entry.badgeLabel!,
                      tone: PixelTone.ruby,
                      compact: true,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (!enabled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        'SOON',
                        style: TextStyle(
                          color: AppColors.inkBrown.withValues(alpha: 0.72),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                widget.entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.inkBrown,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.entry.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.inkBrown.withValues(alpha: 0.76),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
