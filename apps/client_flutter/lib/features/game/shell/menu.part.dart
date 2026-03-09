part of '../game_shell_page.dart';

extension _GameShellMenu on _GameShellPageState {
  Future<void> _closeDialogThen(
    BuildContext dialogContext,
    FutureOr<void> Function() action,
  ) async {
    Navigator.of(dialogContext).pop();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted) {
      return;
    }
    await action();
  }

  Future<void> _openMainMenuDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 760,
      preferredHeight: 620,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final strings = ref.watch(appStringsProvider);
            final isMaster = ref.watch(
              authSessionProvider.select(
                (session) => session?.isGuildMaster ?? false,
              ),
            );
            final unreadCount = ref.watch(
              directMessagesControllerProvider.select(
                (state) => state.totalUnreadCount,
              ),
            );
            final compact =
                MediaQuery.sizeOf(dialogContext).width < 540 ||
                MediaQuery.sizeOf(dialogContext).height < 760;

            return _MainMenuPanel(
              strings: strings,
              compact: compact,
              isMaster: isMaster,
              directMessageUnreadCount: unreadCount,
              onClose: () => Navigator.of(dialogContext).pop(),
              onOpenTasks: () {
                return _closeDialogThen(dialogContext, _openNoticeBoardDialog);
              },
              onOpenFamilyCenter: () {
                return _closeDialogThen(
                  dialogContext,
                  isMaster ? _openMasterDeskDialog : _openGuildChestDialog,
                );
              },
              onOpenRewards: () {
                return _closeDialogThen(dialogContext, _openGuildShopDialog);
              },
              onOpenBag: () {
                return _closeDialogThen(dialogContext, _openInventoryDialog);
              },
              onOpenVoice: () {
                return _closeDialogThen(dialogContext, _openCampfireDialog);
              },
              onOpenHabits: () {
                return _closeDialogThen(dialogContext, _openHabitsDialog);
              },
              onOpenDirectMessages: () {
                return _closeDialogThen(
                  dialogContext,
                  _openDirectMessagesDialog,
                );
              },
              onOpenPhotoDump: () {
                return _closeDialogThen(dialogContext, _openPhotoDumpDialog);
              },
              onOpenProfile: () {
                return _closeDialogThen(dialogContext, _openProfileDialog);
              },
              onOpenSettings: () {
                return _closeDialogThen(dialogContext, _openSettingsDialog);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openSettingsDialog() async {
    await _showOverlayDialog<void>(
      preferredWidth: 560,
      preferredHeight: 620,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final strings = ref.watch(appStringsProvider);
            final compact =
                MediaQuery.sizeOf(dialogContext).width < 520 ||
                MediaQuery.sizeOf(dialogContext).height < 760;
            return _SettingsPanel(
              strings: strings,
              compact: compact,
              currentThemeLabel: _visualThemeLabel,
              onClose: () => Navigator.of(dialogContext).pop(),
              onCycleTheme: _cycleVisualTheme,
              onLogout: () async {
                Navigator.of(dialogContext).pop();
                await _logout();
              },
            );
          },
        );
      },
    );
  }
}

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
            key: const ValueKey('main_menu_grid'),
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
      key: ValueKey('main_menu_card_${widget.entry.id}'),
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

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.strings,
    required this.compact,
    required this.currentThemeLabel,
    required this.onClose,
    required this.onCycleTheme,
    required this.onLogout,
  });

  final AppStrings strings;
  final bool compact;
  final String currentThemeLabel;
  final VoidCallback onClose;
  final VoidCallback onCycleTheme;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final sectionGap = compact ? 8.0 : 10.0;
    return ListView(
      key: const ValueKey('settings_list'),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.settingsTitle,
                    style: TextStyle(
                      color: AppColors.inkBrown,
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  Text(
                    strings.settingsSubtitle,
                    style: TextStyle(
                      color: AppColors.inkBrown.withValues(alpha: 0.74),
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 11 : 14,
                    ),
                  ),
                ],
              ),
            ),
            _FloorplanCloseButton(onPressed: onClose),
          ],
        ),
        SizedBox(height: compact ? 10 : 14),
        _SettingsLanguageSection(strings: strings, compact: compact),
        SizedBox(height: sectionGap),
        _SettingsToggleSection(
          compact: compact,
          title: strings.soundEffects,
          label: strings.soundEffects,
          selector: (settings) => settings.soundEffectsEnabled,
          onChanged: (controller, nextValue) {
            return controller.setSoundEffectsEnabled(nextValue);
          },
        ),
        SizedBox(height: sectionGap),
        _SettingsToggleSection(
          compact: compact,
          title: strings.music,
          label: strings.music,
          selector: (settings) => settings.musicEnabled,
          onChanged: (controller, nextValue) {
            return controller.setMusicEnabled(nextValue);
          },
        ),
        SizedBox(height: sectionGap),
        _SettingsToggleSection(
          compact: compact,
          title: strings.haptics,
          label: strings.haptics,
          selector: (settings) => settings.hapticsEnabled,
          onChanged: (controller, nextValue) {
            return controller.setHapticsEnabled(nextValue);
          },
        ),
        SizedBox(height: sectionGap),
        _SettingsToggleSection(
          compact: compact,
          title: strings.pixelFx,
          label: strings.pixelFx,
          selector: (settings) => settings.pixelFxEnabled,
          onChanged: (controller, nextValue) {
            return controller.setPixelFxEnabled(nextValue);
          },
        ),
        SizedBox(height: sectionGap),
        _SettingsUiScaleSection(strings: strings, compact: compact),
        SizedBox(height: sectionGap),
        _SettingsSection(
          compact: compact,
          title: strings.visualTheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.currentTheme(currentThemeLabel),
                style: PixelTypography.style(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 12 : 14,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              _StampButton(
                label: strings.cycleTheme,
                icon: Icons.auto_awesome,
                tone: _StampTone.blue,
                onPressed: onCycleTheme,
              ),
            ],
          ),
        ),
        SizedBox(height: sectionGap),
        _SettingsSection(
          compact: compact,
          title: strings.logout,
          child: _StampButton(
            label: strings.logout,
            icon: Icons.logout_rounded,
            tone: _StampTone.ruby,
            onPressed: () {
              unawaited(onLogout());
            },
          ),
        ),
      ],
    );
  }
}

String _settingsLanguageLabel(AppLanguage language) {
  return switch (language) {
    AppLanguage.traditionalChinese => '繁體中文',
    AppLanguage.english => 'English',
  };
}

class _SettingsLanguageSection extends ConsumerWidget {
  const _SettingsLanguageSection({required this.strings, required this.compact});

  final AppStrings strings;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLanguage = ref.watch(
      appSettingsProvider.select((settings) => settings.language),
    );
    final controller = ref.read(settingsControllerProvider.notifier);
    return _SettingsSection(
      compact: compact,
      title: strings.systemLanguage,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: AppLanguage.values
            .map((language) {
              final selected = selectedLanguage == language;
              return _SettingsChoiceButton(
                label: _settingsLanguageLabel(language),
                selected: selected,
                onPressed: () {
                  unawaited(controller.setLanguage(language));
                },
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _SettingsUiScaleSection extends ConsumerWidget {
  const _SettingsUiScaleSection({required this.strings, required this.compact});

  final AppStrings strings;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiScale = ref.watch(appSettingsProvider.select((settings) => settings.uiScale));
    final controller = ref.read(settingsControllerProvider.notifier);
    return _SettingsSection(
      compact: compact,
      title: strings.uiScale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSlider(
            min: AppSettings.minUiScale,
            max: AppSettings.maxUiScale,
            value: uiScale,
            divisions: 5,
            onChanged: (value) {
              unawaited(controller.setUiScale(value));
            },
          ),
          Text(
            uiScale.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: PixelTypography.style(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 12 : 14,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

typedef _SettingsBoolSelector = bool Function(AppSettings settings);
typedef _SettingsBoolChange =
    Future<void> Function(SettingsController controller, bool nextValue);

class _SettingsToggleSection extends ConsumerWidget {
  const _SettingsToggleSection({
    required this.compact,
    required this.title,
    required this.label,
    required this.selector,
    required this.onChanged,
  });

  final bool compact;
  final String title;
  final String label;
  final _SettingsBoolSelector selector;
  final _SettingsBoolChange onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(appSettingsProvider.select(selector));
    final controller = ref.read(settingsControllerProvider.notifier);
    return _SettingsSection(
      compact: compact,
      title: title,
      child: _SettingsToggleRow(
        label: label,
        value: value,
        onChanged: (nextValue) {
          return onChanged(controller, nextValue);
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    required this.compact,
  });

  final String title;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: EdgeInsets.all(compact ? 10 : 12),
      cut: compact ? 10 : 12,
      shadowDepth: 3,
      faceColor: Colors.white.withValues(alpha: 0.42),
      edgeColor: AppColors.woodFrame,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: PixelTypography.style(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 13 : 14,
              height: 1,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          child,
        ],
      ),
    );
  }
}

class _SettingsChoiceButton extends StatelessWidget {
  const _SettingsChoiceButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kPixelButtonCompactWidth,
      child: PixelButton(
        label: label,
        tone: selected ? PixelTone.green : PixelTone.parchment,
        compact: true,
        onPressed: onPressed,
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Future<void> Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: PixelTypography.style(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1,
            ),
          ),
        ),
        PixelToggle(
          value: value,
          onChanged: (nextValue) {
            unawaited(onChanged(nextValue));
          },
        ),
      ],
    );
  }
}
