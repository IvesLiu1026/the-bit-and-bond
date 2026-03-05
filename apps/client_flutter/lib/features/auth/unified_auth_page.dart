import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/auth_api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../state/providers.dart';

enum _UnifiedAuthMode { login, register }

class UnifiedAuthPage extends ConsumerStatefulWidget {
  const UnifiedAuthPage({super.key});

  @override
  ConsumerState<UnifiedAuthPage> createState() => _UnifiedAuthPageState();
}

class _UnifiedAuthPageState extends ConsumerState<UnifiedAuthPage> {
  final _accountController = TextEditingController();
  final _secretController = TextEditingController();
  final _displayNameController = TextEditingController();
  _UnifiedAuthMode _mode = _UnifiedAuthMode.login;
  bool _submitting = false;
  String? _errorMessage;

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
    final account = _accountController.text.trim();
    final secret = _secretController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (account.isEmpty) {
      _showError('請輸入帳號（玩家ID或Email）');
      return;
    }
    if (secret.isEmpty) {
      _showError('請輸入密鑰（PIN 或密碼）');
      return;
    }
    if (_mode == _UnifiedAuthMode.register) {
      if (displayName.isEmpty) {
        _showError('註冊時請輸入暱稱');
        return;
      }
      if (account.contains('@')) {
        _showError('註冊請使用玩家 ID，不要使用 Email');
        return;
      }
      if (secret.length != 4 || int.tryParse(secret) == null) {
        _showError('註冊時密鑰需為 4 位數字 PIN');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (_mode == _UnifiedAuthMode.login) {
        await auth.loginPlayer(playerId: account, pinCode: secret);
      } else {
        await auth.registerPlayer(
          playerId: account,
          pinCode: secret,
          displayName: displayName,
        );
      }
    } on AuthApiException catch (error) {
      _showError(error.message);
    } catch (error) {
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
    final title = _mode == _UnifiedAuthMode.login ? '玩家登入' : '建立新玩家';
    final cta = _mode == _UnifiedAuthMode.login ? '登入遊戲' : '註冊並開始';

    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.inkBrown,
        fontWeight: FontWeight.w800,
      ),
      filled: true,
      fillColor: const Color(0xFFE7DDC9),
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7CB342), Color(0xFF689F38)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.parchment,
                    border: Border.all(color: AppColors.woodFrame, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowHard,
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '諶家公會',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.inkBrown,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PixelModeSwitch(
                        selected: _mode,
                        onChanged: (value) {
                          setState(() => _mode = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _accountController,
                        enabled: !_submitting,
                        decoration: deco(
                          _mode == _UnifiedAuthMode.login
                              ? '帳號（玩家ID 或 Email）'
                              : '玩家 ID（4~24，英數底線）',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _secretController,
                        enabled: !_submitting,
                        obscureText: true,
                        keyboardType: _mode == _UnifiedAuthMode.register
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: deco(
                          _mode == _UnifiedAuthMode.login
                              ? '密鑰（PIN 或密碼）'
                              : 'PIN 碼（4 位數字）',
                        ),
                      ),
                      if (_mode == _UnifiedAuthMode.register) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _displayNameController,
                          enabled: !_submitting,
                          decoration: deco('顯示名稱'),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            border: Border.all(
                              color: AppColors.hpRuby,
                              width: 2.6,
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.hpRuby,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _PixelAuthButton(
                        onPressed: _submitting ? null : _submit,
                        label: _submitting ? '處理中...' : cta,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '單一登入入口：玩家ID+PIN 或 Email+密碼。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.inkBrown,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelModeSwitch extends StatelessWidget {
  const _PixelModeSwitch({required this.selected, required this.onChanged});

  final _UnifiedAuthMode selected;
  final ValueChanged<_UnifiedAuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE7DDC9),
        border: Border.all(color: AppColors.woodFrame, width: 3),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PixelModeTab(
              label: '登入',
              active: selected == _UnifiedAuthMode.login,
              onTap: () => onChanged(_UnifiedAuthMode.login),
            ),
          ),
          Expanded(
            child: _PixelModeTab(
              label: '註冊',
              active: selected == _UnifiedAuthMode.register,
              onTap: () => onChanged(_UnifiedAuthMode.register),
            ),
          ),
        ],
      ),
    );
  }
}

class _PixelModeTab extends StatelessWidget {
  const _PixelModeTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8D6E63) : const Color(0xFFE7DDC9),
          border: Border(
            right: BorderSide(
              color: label == '登入' ? AppColors.woodFrame : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : AppColors.inkBrown,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PixelAuthButton extends StatefulWidget {
  const _PixelAuthButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  State<_PixelAuthButton> createState() => _PixelAuthButtonState();
}

class _PixelAuthButtonState extends State<_PixelAuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 80),
        offset: _pressed ? const Offset(0, 0.05) : Offset.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled
                ? AppColors.submitGreen.withValues(alpha: 0.5)
                : AppColors.submitGreen,
            border: Border(
              left: const BorderSide(
                color: AppColors.submitGreenEdge,
                width: 3,
              ),
              top: const BorderSide(color: AppColors.submitGreenEdge, width: 3),
              right: const BorderSide(
                color: AppColors.submitGreenEdge,
                width: 3,
              ),
              bottom: BorderSide(
                color: AppColors.submitGreenEdge,
                width: _pressed ? 1.2 : 5,
              ),
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
