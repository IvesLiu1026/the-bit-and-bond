part of '../game_shell_page.dart';

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
        _SettingsFontStyleSection(strings: strings, compact: compact),
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
  const _SettingsLanguageSection({
    required this.strings,
    required this.compact,
  });

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
    final uiScale = ref.watch(
      appSettingsProvider.select((settings) => settings.uiScale),
    );
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

class _SettingsFontStyleSection extends ConsumerWidget {
  const _SettingsFontStyleSection({
    required this.strings,
    required this.compact,
  });

  final AppStrings strings;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pixelFontEnabled = ref.watch(
      appSettingsProvider.select((settings) => settings.pixelFontEnabled),
    );
    final controller = ref.read(settingsControllerProvider.notifier);
    return _SettingsSection(
      compact: compact,
      title: strings.fontStyle,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _SettingsChoiceButton(
            label: strings.pixelFont,
            selected: pixelFontEnabled,
            onPressed: () {
              unawaited(controller.setPixelFontEnabled(true));
            },
          ),
          _SettingsChoiceButton(
            label: strings.standardFont,
            selected: !pixelFontEnabled,
            onPressed: () {
              unawaited(controller.setPixelFontEnabled(false));
            },
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
