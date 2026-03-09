import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/google_federated_auth_service.dart';
import '../../core/audio/sfx_player.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/auth_api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/pixel_ui.dart';
import '../../features/avatar/avatar_appearance.dart';
import '../../state/providers.dart';
import 'unified_auth_page.dart';

part 'onboarding/contract.part.dart';
part 'onboarding/customization.part.dart';
part 'onboarding/steps.part.dart';
part 'onboarding/visuals.part.dart';

enum _OnboardingStep { greeting, customization, contract }

typedef _AvatarHairStyle = AvatarHairStyle;
typedef _AvatarClothTone = AvatarClothTone;

class ImmersiveOnboardingPage extends ConsumerStatefulWidget {
  const ImmersiveOnboardingPage({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  ConsumerState<ImmersiveOnboardingPage> createState() =>
      _ImmersiveOnboardingPageState();
}

class _ImmersiveOnboardingPageState
    extends ConsumerState<ImmersiveOnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  _OnboardingStep _step = _OnboardingStep.greeting;
  _AvatarHairStyle _hairStyle = _AvatarHairStyle.crop;
  _AvatarClothTone _clothTone = _AvatarClothTone.ember;
  bool _showLegacyContract = false;
  bool _googleSubmitting = false;
  String? _contractNotice;

  String get _avatarType => AvatarAppearance(
    hairStyle: _hairStyle,
    clothTone: _clothTone,
  ).toAvatarType();

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _enterTavern() async {
    if (_step != _OnboardingStep.greeting) {
      return;
    }
    HapticFeedback.lightImpact();
    unawaited(SfxPlayer.instance.playDoorOpen());
    if (!mounted) {
      return;
    }
    setState(() {
      _step = _OnboardingStep.customization;
    });
  }

  void _continueToContract() {
    HapticFeedback.selectionClick();
    unawaited(SfxPlayer.instance.playUseSuccess());
    setState(() {
      _step = _OnboardingStep.contract;
    });
  }

  void _returnToGreeting() {
    HapticFeedback.selectionClick();
    setState(() {
      _step = _OnboardingStep.greeting;
    });
  }

  void _returnToCustomization() {
    HapticFeedback.selectionClick();
    setState(() {
      _step = _OnboardingStep.customization;
    });
  }

  void _revealLegacyContract() {
    final strings = AppStrings.of(context);
    HapticFeedback.selectionClick();
    unawaited(SfxPlayer.instance.playCoin());
    setState(() {
      _showLegacyContract = true;
      _contractNotice ??= strings.tr(
        zh: '不想用 Google 也沒關係，玩家印記契約一樣可以啟用你的生活空間。',
        en: 'No need to use Google if you do not want to. The player seal contract can still open your life space.',
      );
    });
    unawaited(_openLegacyContractSheet(UnifiedAuthMode.register));
  }

  void _openLegacyLoginContract() {
    final strings = AppStrings.of(context);
    HapticFeedback.selectionClick();
    unawaited(SfxPlayer.instance.playCoin());
    setState(() {
      _showLegacyContract = true;
      _contractNotice ??= strings.tr(
        zh: '如果你本來就有角色，也可以直接用玩家 ID 契約登入。',
        en: 'If you already have a character, you can also sign in directly with your Player ID contract.',
      );
    });
    unawaited(_openLegacyContractSheet(UnifiedAuthMode.login));
  }

  Future<void> _openLegacyContractSheet(UnifiedAuthMode mode) async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final strings = AppStrings.of(sheetContext);
        final footer = mode == UnifiedAuthMode.register
            ? strings.tr(
                zh: '註冊時會把你剛剛挑好的造型一起綁進角色資料。',
                en: 'Registration will bind the look you just picked into your character data.',
              )
            : strings.tr(
                zh: '如果你已經有角色，可以直接用玩家 ID + PIN 回到自己的空間。',
                en: 'If you already have a character, return with your Player ID + PIN.',
              );
        return _LegacyContractSheet(
          mode: mode,
          avatarType: _avatarType,
          footerText: footer,
          onAuthenticated: () {
            Navigator.of(sheetContext).maybePop();
          },
        );
      },
    );
  }

  Widget _buildStepTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0.2, end: 1).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.03, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }

  Future<void> _handleGoogleContract() async {
    final strings = AppStrings.of(context);
    if (_googleSubmitting) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _googleSubmitting = true;
      _contractNotice = strings.tr(
        zh: '正在替你展開 Google 印記契約...',
        en: 'Opening your Google seal contract...',
      );
    });

    try {
      final identity = await ref
          .read(googleFederatedAuthServiceProvider)
          .signIn();
      await ref
          .read(authControllerProvider.notifier)
          .loginWithFirebaseIdToken(
            idToken: identity.firebaseIdToken,
            displayName: identity.displayName,
            avatarType: _avatarType,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _contractNotice = strings.tr(
          zh: '核章完成，正在把你的 Bibon 帶進生活空間...',
          en: 'Seal approved. Bringing your Bibon into the space...',
        );
        _showLegacyContract = false;
      });
      HapticFeedback.heavyImpact();
      unawaited(SfxPlayer.instance.playUseSuccess());
    } on FederatedAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _contractNotice = error.message;
        _showLegacyContract = error.shouldShowFallbackForm;
      });
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _contractNotice = error.message;
        _showLegacyContract = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _contractNotice = strings.tr(
          zh: '契約印章失敗：$error',
          en: 'Contract seal failed: $error',
        );
        _showLegacyContract = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _googleSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final media = MediaQuery.of(context);
    final compact = media.size.width < 560;

    return Scaffold(
      body: Container(
        color: const Color(0xFF3D261B),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _PixelWoodBackdrop()),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: _buildStepTransition,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [...previousChildren, ?currentChild],
                  );
                },
                child: switch (_step) {
                  _OnboardingStep.greeting => _GreetingStep(
                    key: const ValueKey('greeting'),
                    blink: _blinkController,
                    compact: compact,
                    onTap: _enterTavern,
                  ),
                  _OnboardingStep.customization => _CustomizationStep(
                    key: const ValueKey('customization'),
                    hairStyle: _hairStyle,
                    clothTone: _clothTone,
                    compact: compact,
                    onHairSelected: (value) {
                      HapticFeedback.selectionClick();
                      unawaited(SfxPlayer.instance.playCoin());
                      setState(() => _hairStyle = value);
                    },
                    onClothSelected: (value) {
                      HapticFeedback.selectionClick();
                      unawaited(SfxPlayer.instance.playCoin());
                      setState(() => _clothTone = value);
                    },
                    onBack: _returnToGreeting,
                    onContinue: _continueToContract,
                  ),
                  _OnboardingStep.contract => _ContractStep(
                    key: const ValueKey('contract'),
                    compact: compact,
                    hairStyle: _hairStyle,
                    clothTone: _clothTone,
                    showLegacyContract: _showLegacyContract,
                    googleSubmitting: _googleSubmitting,
                    contractNotice: _contractNotice,
                    onBack: _returnToCustomization,
                    onGoogleContract: () {
                      unawaited(_handleGoogleContract());
                    },
                    onLegacyRegister: _revealLegacyContract,
                    onLegacyLogin: _openLegacyLoginContract,
                  ),
                },
              ),
              if (widget.errorMessage != null)
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Material(
                    color: Colors.transparent,
                    child: PixelPanel(
                      tone: PixelTone.ruby,
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        strings.tr(
                          zh: '登入錯誤：${widget.errorMessage}',
                          en: 'Sign-in error: ${widget.errorMessage}',
                        ),
                        style: const TextStyle(
                          color: Color(0xFFFFF1EE),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
