part of '../unified_auth_page.dart';

class UnifiedAuthForm extends ConsumerStatefulWidget {
  const UnifiedAuthForm({
    super.key,
    this.avatarType,
    this.initialMode = UnifiedAuthMode.login,
    this.showModeSwitch = true,
    this.footerText,
    this.onAuthenticated,
  });

  final String? avatarType;
  final UnifiedAuthMode initialMode;
  final bool showModeSwitch;
  final String? footerText;
  final VoidCallback? onAuthenticated;

  @override
  ConsumerState<UnifiedAuthForm> createState() => _UnifiedAuthFormState();
}

class _UnifiedAuthFormState extends ConsumerState<UnifiedAuthForm> {
  final _accountController = TextEditingController();
  final _secretController = TextEditingController();
  final _displayNameController = TextEditingController();
  late UnifiedAuthMode _mode;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _secretController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final accountRaw = _accountController.text.trim();
    final account = accountRaw.toLowerCase();
    final secret = _secretController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (account.isEmpty) {
      _showError(
        AppStrings.of(context).tr(
          zh: '請輸入帳號（玩家ID或Email）',
          en: 'Enter your account (Player ID or Email).',
        ),
      );
      return;
    }
    if (secret.isEmpty) {
      _showError(
        AppStrings.of(
          context,
        ).tr(zh: '請輸入密鑰（PIN 或密碼）', en: 'Enter your secret (PIN or password).'),
      );
      return;
    }
    if (_mode == UnifiedAuthMode.login &&
        !account.contains('@') &&
        (secret.length != 4 || int.tryParse(secret) == null)) {
      _showError(
        AppStrings.of(context).tr(
          zh: '玩家ID登入需使用 4 位 PIN；若要用密碼登入，請改用 Email 帳號',
          en: 'Player ID sign-in needs a 4-digit PIN. Use an Email account if you want password sign-in.',
        ),
      );
      return;
    }
    if (_mode == UnifiedAuthMode.register) {
      if (displayName.isEmpty) {
        _showError(
          AppStrings.of(
            context,
          ).tr(zh: '註冊時請輸入暱稱', en: 'Enter a display name for registration.'),
        );
        return;
      }
      if (account.contains('@')) {
        _showError(
          AppStrings.of(context).tr(
            zh: '註冊請使用玩家 ID，不要使用 Email',
            en: 'Use a Player ID for registration, not an Email address.',
          ),
        );
        return;
      }
      if (secret.length != 4 || int.tryParse(secret) == null) {
        _showError(
          AppStrings.of(context).tr(
            zh: '註冊時密鑰需為 4 位數字 PIN',
            en: 'Registration needs a 4-digit PIN.',
          ),
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final analytics = ref.read(productAnalyticsProvider);
    final accountKind = account.contains('@') ? 'email' : 'player_id';
    analytics.track(
      'auth.submit.attempt',
      allowPublic: true,
      properties: <String, dynamic>{
        'mode': _mode.name,
        'account_kind': accountKind,
      },
    );
    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (_mode == UnifiedAuthMode.login) {
        await auth.loginPlayer(playerId: account, pinCode: secret);
      } else {
        await auth.registerPlayer(
          playerId: account,
          pinCode: secret,
          displayName: displayName,
          avatarType: widget.avatarType,
        );
      }
      analytics.track(
        _mode == UnifiedAuthMode.login
            ? 'auth.login.success'
            : 'auth.register.success',
        properties: <String, dynamic>{'account_kind': accountKind},
      );
      widget.onAuthenticated?.call();
    } on AuthApiException catch (error) {
      analytics.track(
        _mode == UnifiedAuthMode.login
            ? 'auth.login.failed'
            : 'auth.register.failed',
        status: 'error',
        allowPublic: true,
        properties: <String, dynamic>{
          'account_kind': accountKind,
          'status_code': error.statusCode,
        },
      );
      _showError(error.message);
    } catch (error) {
      analytics.track(
        _mode == UnifiedAuthMode.login
            ? 'auth.login.failed'
            : 'auth.register.failed',
        status: 'error',
        allowPublic: true,
        properties: <String, dynamic>{'account_kind': accountKind},
      );
      _showError('$error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final compact = MediaQuery.of(context).size.width < 560;
    final cta = _mode == UnifiedAuthMode.login
        ? strings.tr(zh: '登入遊戲', en: 'Enter Space')
        : strings.tr(zh: '註冊並開始', en: 'Create & Start');
    final footerText =
        widget.footerText ??
        strings.tr(
          zh: '登入可用：玩家 ID + PIN，或 Email + 密碼',
          en: 'Sign in with Player ID + PIN, or Email + password.',
        );

    InputDecoration deco(String label) => InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(
        color: Color(0xFF8A7761),
        fontWeight: FontWeight.w800,
      ),
      filled: true,
      fillColor: const Color(0xFFE7DDC9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.woodFrame, width: 3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.woodFrame, width: 3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.navyBlue, width: 3),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showModeSwitch) ...[
          _PixelModeSwitch(
            selected: _mode,
            onChanged: (value) {
              setState(() => _mode = value);
            },
          ),
          const SizedBox(height: 14),
        ],
        _PixelFieldFrame(
          label: _mode == UnifiedAuthMode.login
              ? strings.tr(zh: '帳號', en: 'Account')
              : strings.tr(zh: '玩家 ID', en: 'Player ID'),
          child: TextField(
            controller: _accountController,
            enabled: !_submitting,
            decoration: deco(
              _mode == UnifiedAuthMode.login
                  ? strings.tr(zh: '玩家 ID 或 Email', en: 'Player ID or Email')
                  : strings.tr(
                      zh: '4~24 字元，英數與底線',
                      en: '4-24 chars, letters, numbers, underscore',
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _PixelFieldFrame(
          label: _mode == UnifiedAuthMode.login
              ? strings.tr(zh: '密鑰', en: 'Secret')
              : 'PIN',
          child: TextField(
            controller: _secretController,
            enabled: !_submitting,
            obscureText: true,
            keyboardType: _mode == UnifiedAuthMode.register
                ? TextInputType.number
                : TextInputType.text,
            decoration: deco(
              _mode == UnifiedAuthMode.login
                  ? strings.tr(zh: 'PIN 或密碼', en: 'PIN or password')
                  : strings.tr(zh: '4 位數字', en: '4 digits'),
            ),
          ),
        ),
        if (_mode == UnifiedAuthMode.register) ...[
          const SizedBox(height: 10),
          _PixelFieldFrame(
            label: strings.tr(zh: '稱號', en: 'Name'),
            child: TextField(
              controller: _displayNameController,
              enabled: !_submitting,
              decoration: deco(strings.tr(zh: '顯示名稱', en: 'Display name')),
            ),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF7E2F21),
              border: Border.all(color: const Color(0xFFE57373), width: 3),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFFFE3DE),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _PixelAuthButton(
          onPressed: _submitting ? null : _submit,
          label: _submitting ? strings.tr(zh: '處理中...', en: 'Working...') : cta,
        ),
        const SizedBox(height: 10),
        Text(
          footerText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.inkBrown,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 12 : 12.5,
          ),
        ),
      ],
    );
  }
}
