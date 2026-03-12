part of '../immersive_onboarding_page.dart';

class _ParchmentContractCard extends StatelessWidget {
  const _ParchmentContractCard({
    required this.compact,
    required this.notice,
    required this.showLegacyContract,
    required this.googleSubmitting,
    required this.appearanceLabel,
    required this.hairStyle,
    required this.clothTone,
    required this.onGoogleContract,
    required this.onLegacyRegister,
    required this.onLegacyLogin,
  });

  final bool compact;
  final String? notice;
  final bool showLegacyContract;
  final bool googleSubmitting;
  final String appearanceLabel;
  final _AvatarHairStyle hairStyle;
  final _AvatarClothTone clothTone;
  final VoidCallback onGoogleContract;
  final VoidCallback onLegacyRegister;
  final VoidCallback onLegacyLogin;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: EdgeInsets.all(compact ? 16 : 20),
      cut: compact ? 12 : 16,
      shadowDepth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.tr(zh: '生活契約', en: 'Life Contract'),
            style: TextStyle(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 28 : 34,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.tr(
              zh: '先把印記蓋在羊皮紙上，之後你的進度、空間互動和家庭身分都會跟著這台 Bibon 一起保存。Google 印記成功後，會直接把你剛才設定好的機體外觀綁進帳號。',
              en: 'Seal the parchment first. Your progress, space interactions, and family role will stay with this Bibon. If Google succeeds, the appearance you just picked is bound to the account right away.',
            ),
            style: TextStyle(
              color: AppColors.inkBrown.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13.5 : 15,
              height: 1.45,
            ),
          ),
          SizedBox(height: compact ? 12 : 18),
          if (compact) ...[
            PixelPanel(
              tone: PixelTone.parchment,
              padding: const EdgeInsets.all(10),
              cut: 10,
              shadowDepth: 3,
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: PixelAvatarPreview(
                      appearance: AvatarAppearance(
                        hairStyle: hairStyle,
                        clothTone: clothTone,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.tr(
                        zh: '你的 Bibon 外觀：$appearanceLabel',
                        en: 'Your Bibon look: $appearanceLabel',
                      ),
                      style: const TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          PixelPanel(
            tone: PixelTone.gold,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            cut: 10,
            shadowDepth: 3,
            child: Text(
              strings.tr(
                zh: '本次契約機體：$appearanceLabel',
                en: 'Current contract build: $appearanceLabel',
              ),
              style: const TextStyle(
                color: AppColors.inkBrown,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _GoogleCrestButton(
            onTap: googleSubmitting ? null : onGoogleContract,
            label: googleSubmitting
                ? strings.tr(zh: '[ 正在核章中... ]', en: '[ Sealing... ]')
                : strings.tr(
                    zh: '[ 以 Google 紋章簽署 ]',
                    en: '[ Sign with Google ]',
                  ),
          ),
          SizedBox(height: compact ? 8 : 10),
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelButton(
                  tapTargetKey: AppTestIds.onboardingManualRegisterButtonKey,
                  label: strings.tr(zh: '手動註冊新角色', en: 'Register Manually'),
                  tone: PixelTone.parchment,
                  compact: true,
                  expand: true,
                  onPressed: onLegacyRegister,
                ),
                const SizedBox(height: 8),
                PixelButton(
                  tapTargetKey: AppTestIds.onboardingManualLoginButtonKey,
                  label: strings.tr(
                    zh: '已有角色，用玩家 ID 登入',
                    en: 'Use Player ID to Sign In',
                  ),
                  tone: PixelTone.wood,
                  compact: true,
                  expand: true,
                  onPressed: onLegacyLogin,
                ),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 200,
                  child: PixelButton(
                    tapTargetKey: AppTestIds.onboardingManualRegisterButtonKey,
                    label: strings.tr(zh: '手動註冊新角色', en: 'Register Manually'),
                    tone: PixelTone.parchment,
                    onPressed: onLegacyRegister,
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: PixelButton(
                    tapTargetKey: AppTestIds.onboardingManualLoginButtonKey,
                    label: strings.tr(
                      zh: '已有角色，用玩家 ID 登入',
                      en: 'Use Player ID to Sign In',
                    ),
                    tone: PixelTone.wood,
                    onPressed: onLegacyLogin,
                  ),
                ),
              ],
            ),
          if (notice != null) ...[
            const SizedBox(height: 12),
            PixelPanel(
              tone: PixelTone.gold,
              padding: const EdgeInsets.all(12),
              cut: 10,
              shadowDepth: 3,
              faceColor: const Color(0xFFFDECC8),
              child: Text(
                notice!,
                style: const TextStyle(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (showLegacyContract) ...[
            const SizedBox(height: 14),
            PixelPanel(
              tone: PixelTone.gold,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              cut: 10,
              shadowDepth: 3,
              faceColor: const Color(0xFFF7E5B8),
              child: Text(
                strings.tr(
                  zh: '手動契約已準備好。點上面的按鈕，就能用玩家 ID 建立或登入角色。',
                  en: 'The manual contract is ready. Use the buttons above to create or enter a Player ID.',
                ),
                style: const TextStyle(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegacyContractSheet extends StatelessWidget {
  const _LegacyContractSheet({
    required this.mode,
    required this.avatarType,
    required this.footerText,
    required this.onAuthenticated,
  });

  final UnifiedAuthMode mode;
  final String avatarType;
  final String footerText;
  final VoidCallback onAuthenticated;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          media.viewInsets.bottom > 0 ? 14 : 32,
          14,
          media.viewInsets.bottom + 14,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: PixelPanel(
              tone: PixelTone.parchment,
              padding: const EdgeInsets.all(16),
              cut: 14,
              shadowDepth: 8,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      mode == UnifiedAuthMode.register
                          ? strings.tr(zh: '玩家印記註冊', en: 'Player Seal Register')
                          : strings.tr(zh: '玩家印記登入', en: 'Player Seal Sign In'),
                      style: const TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mode == UnifiedAuthMode.register
                          ? strings.tr(
                              zh: '不想用 Google 也沒關係，這張契約會直接替你建立角色。',
                              en: 'Google is optional. This contract can create your character directly.',
                            )
                          : strings.tr(
                              zh: '輸入你原本的玩家 ID 與 PIN，就能回到生活空間裡。',
                              en: 'Enter your Player ID and PIN to return to your space.',
                            ),
                      style: TextStyle(
                        color: AppColors.inkBrown.withValues(alpha: 0.84),
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    UnifiedAuthForm(
                      avatarType: avatarType,
                      initialMode: mode,
                      showModeSwitch: false,
                      footerText: footerText,
                      onAuthenticated: onAuthenticated,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleCrestButton extends StatefulWidget {
  const _GoogleCrestButton({required this.onTap, required this.label});

  final VoidCallback? onTap;
  final String label;

  @override
  State<_GoogleCrestButton> createState() => _GoogleCrestButtonState();
}

class _GoogleCrestButtonState extends State<_GoogleCrestButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 80),
        offset: _pressed ? const Offset(0, 0.04) : Offset.zero,
        child: PixelPanel(
          tone: PixelTone.parchment,
          cut: 14,
          shadowDepth: _pressed ? 1.5 : 6,
          faceColor: enabled
              ? const Color(0xFFF6EFE0)
              : const Color(0xFFE2D5C2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              PixelPanel(
                tone: PixelTone.parchment,
                cut: 10,
                shadowDepth: 0,
                showShadow: false,
                faceColor: const Color(0xFFE4D6BB),
                padding: EdgeInsets.zero,
                child: const SizedBox(
                  width: 50,
                  height: 50,
                  child: Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF2B61D1),
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: enabled
                        ? AppColors.inkBrown
                        : AppColors.inkBrown.withValues(alpha: 0.56),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
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
