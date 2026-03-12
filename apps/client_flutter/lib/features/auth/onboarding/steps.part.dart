part of '../immersive_onboarding_page.dart';

class _GreetingStep extends StatelessWidget {
  const _GreetingStep({
    super.key,
    required this.blink,
    required this.compact,
    required this.onTap,
  });

  final Animation<double> blink;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SizedBox.expand(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: AppTestIds.onboardingEnterSpaceButtonKey,
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 20 : 32,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        const _PixelLogoPlaque(),
                        const SizedBox(height: 28),
                        Text(
                          'The Bit and Bond',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFF8E9C8),
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 28 : 38,
                            height: 1,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Bonding Bits between you and me.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(
                              0xFFF4D9A2,
                            ).withValues(alpha: 0.92),
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 14 : 16,
                          ),
                        ),
                        const SizedBox(height: 26),
                        PixelPanel(
                          tone: PixelTone.wood,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 18 : 22,
                            vertical: compact ? 14 : 16,
                          ),
                          child: Text(
                            strings.tr(
                              zh: '先進來看看今天的生活空間。沒有表單壓力，也不用立刻解釋自己，先讓 Bibon 進來陪你。',
                              en: 'Step into your life space first. No forms, no pressure. Let Bibon arrive before anything else.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFFCECD0),
                              fontWeight: FontWeight.w800,
                              fontSize: compact ? 15 : 17,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        FadeTransition(
                          opacity: Tween<double>(
                            begin: 0.28,
                            end: 1,
                          ).animate(blink),
                          child: const _BlinkingPrompt(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CustomizationStep extends StatelessWidget {
  const _CustomizationStep({
    super.key,
    required this.hairStyle,
    required this.clothTone,
    required this.compact,
    required this.onHairSelected,
    required this.onClothSelected,
    required this.onBack,
    required this.onContinue,
  });

  final _AvatarHairStyle hairStyle;
  final _AvatarClothTone clothTone;
  final bool compact;
  final ValueChanged<_AvatarHairStyle> onHairSelected;
  final ValueChanged<_AvatarClothTone> onClothSelected;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SingleChildScrollView(
      key: key,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 24,
        compact ? 14 : 28,
        compact ? 12 : 24,
        compact ? 14 : 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StepProgress(currentStep: 2),
              SizedBox(height: compact ? 10 : 16),
              _NarrationPanel(
                badge: 'LOOK',
                title: compact
                    ? strings.tr(zh: '先決定今天的模樣。', en: 'Pick your look.')
                    : strings.tr(
                        zh: '歡迎來到 The Bit and Bond。',
                        en: 'Welcome to The Bit and Bond.',
                      ),
                body: compact
                    ? strings.tr(
                        zh: '替 Bibon 挑個插頭樣式，再替機殼選一組配色。做完這一步，它就真正屬於你了。',
                        en: 'Choose a plug style and shell color for Bibon. After this step, it starts feeling like yours.',
                      )
                    : strings.tr(
                        zh: '先替你的 Bibon 選個插頭樣式，再挑一組機殼配色。當你替這台小機器做了選擇，它就不只是角色，而是會陪你完成生活任務、記錄回憶和維持習慣的夥伴。',
                        en: 'First choose a plug style, then a shell color. Once you make those choices, this little machine stops feeling generic and starts feeling like your companion for tasks, memories, and habits.',
                      ),
                dense: compact,
              ),
              SizedBox(height: compact ? 12 : 18),
              Wrap(
                spacing: compact ? 12 : 18,
                runSpacing: compact ? 12 : 18,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : 280,
                    child: _AvatarPreviewCard(
                      hairStyle: hairStyle,
                      clothTone: clothTone,
                      dense: compact,
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 540,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SelectionPanel<_AvatarHairStyle>(
                          badge: 'PLUG',
                          title: strings.tr(zh: '插頭樣式', en: 'Plug Style'),
                          items: _AvatarHairStyle.values,
                          selected: hairStyle,
                          dense: compact,
                          itemLabel: (value) => value.localizedLabel(strings),
                          itemBuilder: (value, active) => _HairStyleChip(
                            style: value,
                            active: active,
                            compact: compact,
                          ),
                          onSelected: onHairSelected,
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        _SelectionPanel<_AvatarClothTone>(
                          badge: 'SHELL',
                          title: strings.tr(zh: '機殼配色', en: 'Shell Color'),
                          items: _AvatarClothTone.values,
                          selected: clothTone,
                          dense: compact,
                          itemLabel: (value) => value.localizedLabel(strings),
                          itemBuilder: (value, active) => _ColorToneChip(
                            tone: value,
                            active: active,
                            compact: compact,
                          ),
                          onSelected: onClothSelected,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 18),
              if (compact)
                Row(
                  children: [
                    Expanded(
                      child: PixelButton(
                        label: strings.tr(zh: '返回', en: 'Back'),
                        tone: PixelTone.parchment,
                        compact: true,
                        expand: true,
                        onPressed: onBack,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PixelButton(
                        tapTargetKey:
                            AppTestIds.onboardingContinueToContractButtonKey,
                        label: strings.tr(zh: '前往契約', en: 'Go to Contract'),
                        tone: PixelTone.gold,
                        compact: true,
                        expand: true,
                        onPressed: onContinue,
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  spacing: 12,
                  children: [
                    SizedBox(
                      width: 180,
                      child: PixelButton(
                        label: strings.tr(zh: '返回門口', en: 'Back to Door'),
                        tone: PixelTone.parchment,
                        onPressed: onBack,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: PixelButton(
                        tapTargetKey:
                            AppTestIds.onboardingContinueToContractButtonKey,
                        label: strings.tr(
                          zh: '裝扮完成，簽署契約',
                          en: 'Look Ready, Sign Contract',
                        ),
                        tone: PixelTone.gold,
                        onPressed: onContinue,
                      ),
                    ),
                  ],
                ),
              if (compact) ...[
                const SizedBox(height: 8),
                Text(
                  strings.tr(
                    zh: '之後仍可在遊戲內繼續調整角色外觀。',
                    en: 'You can keep tuning Bibon inside the app later.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF5E9D2),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContractStep extends StatelessWidget {
  const _ContractStep({
    super.key,
    required this.compact,
    required this.hairStyle,
    required this.clothTone,
    required this.showLegacyContract,
    required this.googleSubmitting,
    required this.contractNotice,
    required this.onBack,
    required this.onGoogleContract,
    required this.onLegacyRegister,
    required this.onLegacyLogin,
  });

  final bool compact;
  final _AvatarHairStyle hairStyle;
  final _AvatarClothTone clothTone;
  final bool showLegacyContract;
  final bool googleSubmitting;
  final String? contractNotice;
  final VoidCallback onBack;
  final VoidCallback onGoogleContract;
  final VoidCallback onLegacyRegister;
  final VoidCallback onLegacyLogin;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final appearance = AvatarAppearance(
      hairStyle: hairStyle,
      clothTone: clothTone,
    );

    return SingleChildScrollView(
      key: key,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 24,
        compact ? 14 : 28,
        compact ? 12 : 24,
        compact ? 14 : 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StepProgress(currentStep: 3),
              SizedBox(height: compact ? 10 : 16),
              _NarrationPanel(
                badge: 'SEAL',
                title: compact
                    ? strings.tr(zh: '簽下生活契約。', en: 'Sign the life contract.')
                    : strings.tr(zh: '很棒的裝扮。', en: 'That look works.'),
                body: compact
                    ? strings.tr(
                        zh: 'Google 是最快的啟用方式；如果你偏好玩家 ID，也可以直接打開手動契約。',
                        en: 'Google is the fastest way in, but you can also use a manual Player ID contract.',
                      )
                    : strings.tr(
                        zh: '為了保護你的生活進度，請在這份生活契約上蓋下印記。契約一旦成立，你的 Bibon 就會正式入住你的空間，之後任務、語音房與家庭身分都會跟著它一起保存。',
                        en: 'To protect your progress, seal this life contract. Once it is approved, your Bibon officially moves into your space and keeps your tasks, voice room, and family identity with it.',
                      ),
                dense: compact,
              ),
              SizedBox(height: compact ? 12 : 18),
              Wrap(
                spacing: compact ? 12 : 18,
                runSpacing: compact ? 12 : 18,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  if (!compact)
                    SizedBox(
                      width: 260,
                      child: _AvatarPreviewCard(
                        hairStyle: hairStyle,
                        clothTone: clothTone,
                        footerText: strings.tr(
                          zh: '你會以 ${appearance.localizedSummaryLabel(strings)} 的模樣進入生活空間。',
                          en: 'You will enter your space as ${appearance.localizedSummaryLabel(strings)}.',
                        ),
                      ),
                    ),
                  SizedBox(
                    width: compact ? double.infinity : 620,
                    child: _ParchmentContractCard(
                      compact: compact,
                      notice: contractNotice,
                      showLegacyContract: showLegacyContract,
                      googleSubmitting: googleSubmitting,
                      appearanceLabel: appearance.localizedSummaryLabel(
                        strings,
                      ),
                      hairStyle: hairStyle,
                      clothTone: clothTone,
                      onGoogleContract: onGoogleContract,
                      onLegacyRegister: onLegacyRegister,
                      onLegacyLogin: onLegacyLogin,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 18),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: compact ? null : 180,
                  child: PixelButton(
                    label: compact
                        ? strings.tr(zh: '回去改造型', en: 'Edit Look')
                        : strings.tr(zh: '回去調整造型', en: 'Back to Styling'),
                    tone: PixelTone.parchment,
                    compact: compact,
                    onPressed: onBack,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final labels = AppStrings.of(context).onboardingSteps;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < labels.length; index++)
          _StepProgressChip(
            index: index + 1,
            label: labels[index],
            active: currentStep == index + 1,
          ),
      ],
    );
  }
}

class _StepProgressChip extends StatelessWidget {
  const _StepProgressChip({
    required this.index,
    required this.label,
    required this.active,
  });

  final int index;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      scale: active ? 1 : 0.98,
      child: PixelPanel(
        tone: active ? PixelTone.gold : PixelTone.wood,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        cut: 10,
        shadowDepth: active ? 4 : 2,
        faceColor: active ? null : const Color(0x663A241A),
        edgeColor: active ? null : const Color(0xFF8C664B),
        showShadow: active,
        shadowColor: const Color(0x7730160F),
        child: Text(
          '$index. $label',
          style: TextStyle(
            color: active ? AppColors.inkBrown : const Color(0xFFF2E0BF),
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
