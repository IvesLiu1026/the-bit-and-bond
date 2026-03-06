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
    final accountRaw = _accountController.text.trim();
    final account = accountRaw.toLowerCase();
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
    if (_mode == _UnifiedAuthMode.login &&
        !account.contains('@') &&
        (secret.length != 4 || int.tryParse(secret) == null)) {
      _showError('玩家ID登入需使用 4 位 PIN；若要用密碼登入，請改用 Email 帳號');
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
    final media = MediaQuery.of(context);
    final compact = media.size.width < 560;

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

    return Scaffold(
      body: Container(
        color: const Color(0xFF6E9A39),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _PixelAuthBackdrop()),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4ECE1),
                        border: Border.all(
                          color: const Color(0xFF5D4037),
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowHard,
                            offset: Offset(0, 6),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 14 : 18,
                              compact ? 14 : 18,
                              compact ? 14 : 18,
                              12,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFE8D8B0), Color(0xFFD6BE8F)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.woodFrame,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                const _PixelTavernCrest(),
                                const SizedBox(height: 10),
                                Text(
                                  '旅人酒館',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.inkBrown,
                                    fontWeight: FontWeight.w900,
                                    fontSize: compact ? 28 : 34,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4E342E),
                                    border: Border.all(
                                      color: const Color(0xFF2F1E18),
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFFDF1D8),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(compact ? 14 : 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _PixelFlavorStrip(
                                  text: '玩家 ID、PIN、Email 都從這裡進入',
                                ),
                                const SizedBox(height: 12),
                                _PixelModeSwitch(
                                  selected: _mode,
                                  onChanged: (value) {
                                    setState(() => _mode = value);
                                  },
                                ),
                                const SizedBox(height: 14),
                                _PixelFieldFrame(
                                  label: _mode == _UnifiedAuthMode.login
                                      ? '帳號'
                                      : '玩家 ID',
                                  child: TextField(
                                    controller: _accountController,
                                    enabled: !_submitting,
                                    decoration: deco(
                                      _mode == _UnifiedAuthMode.login
                                          ? '玩家ID 或 Email'
                                          : '4~24 字元，英數與底線',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _PixelFieldFrame(
                                  label: _mode == _UnifiedAuthMode.login
                                      ? '密鑰'
                                      : 'PIN',
                                  child: TextField(
                                    controller: _secretController,
                                    enabled: !_submitting,
                                    obscureText: true,
                                    keyboardType: _mode ==
                                            _UnifiedAuthMode.register
                                        ? TextInputType.number
                                        : TextInputType.text,
                                    decoration: deco(
                                      _mode == _UnifiedAuthMode.login
                                          ? 'PIN 或密碼'
                                          : '4 位數字',
                                    ),
                                  ),
                                ),
                                if (_mode == _UnifiedAuthMode.register) ...[
                                  const SizedBox(height: 10),
                                  _PixelFieldFrame(
                                    label: '稱號',
                                    child: TextField(
                                      controller: _displayNameController,
                                      enabled: !_submitting,
                                      decoration: deco('顯示名稱'),
                                    ),
                                  ),
                                ],
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7E2F21),
                                      border: Border.all(
                                        color: const Color(0xFFE57373),
                                        width: 3,
                                      ),
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
                                  label: _submitting ? '處理中...' : cta,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  '登入可用：玩家ID + PIN，或 Email + 密碼',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.inkBrown,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

class _PixelAuthBackdrop extends StatelessWidget {
  const _PixelAuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PixelAuthBackdropPainter(),
    );
  }
}

class _PixelAuthBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..color = const Color(0xFF7DAF45);
    final skyAlt = Paint()..color = const Color(0xFF6D9C3C);
    final floorDark = Paint()..color = const Color(0xFF4E342E);
    final floorAlt = Paint()..color = const Color(0xFF5D4037);
    final wood = Paint()..color = const Color(0xFF6D4C41);
    final torch = Paint()..color = const Color(0xFFFFA726);
    final glow = Paint()..color = const Color(0x55FFD54F);

    canvas.drawRect(Offset.zero & size, sky);
    final tile = 48.0;
    for (var y = 0.0; y < size.height; y += tile) {
      for (var x = 0.0; x < size.width; x += tile) {
        final rect = Rect.fromLTWH(x, y, tile, tile);
        canvas.drawRect(rect, ((x ~/ tile) + (y ~/ tile)).isEven ? sky : skyAlt);
      }
    }

    final wallHeight = size.height * 0.24;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, wallHeight), wood);
    for (var y = 0.0; y < wallHeight; y += 24) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0x553A221A)
          ..strokeWidth = 1.2,
      );
    }

    final floorTop = size.height * 0.72;
    for (var y = floorTop; y < size.height; y += 56) {
      for (var x = 0.0; x < size.width; x += 56) {
        final rect = Rect.fromLTWH(x, y, 56, 56);
        canvas.drawRect(
          rect,
          ((x ~/ 56) + (y ~/ 56)).isEven ? floorDark : floorAlt,
        );
      }
    }

    final bannerRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.66),
      width: size.width * 0.44,
      height: 96,
    );
    canvas.drawRect(
      bannerRect.inflate(8),
      Paint()..color = const Color(0xFFD4AF37),
    );
    canvas.drawRect(bannerRect, Paint()..color = const Color(0xFFC5372F));

    for (final dx in <double>[size.width * 0.18, size.width * 0.82]) {
      canvas.drawCircle(Offset(dx, wallHeight - 18), 22, glow);
      canvas.drawCircle(Offset(dx, wallHeight - 18), 11, torch);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(dx, wallHeight - 2), width: 7, height: 28),
        Paint()..color = const Color(0xFF4E342E),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PixelTavernCrest extends StatelessWidget {
  const _PixelTavernCrest();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF4E342E),
          border: Border.all(color: const Color(0xFF2F1E18), width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x663E2723),
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'IN',
            style: TextStyle(
              color: Color(0xFFFDF1D8),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelFlavorStrip extends StatelessWidget {
  const _PixelFlavorStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF5D4037),
        border: Border.all(color: const Color(0xFF2F1E18), width: 3),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFF9E5C4),
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _PixelFieldFrame extends StatelessWidget {
  const _PixelFieldFrame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4E342E),
                border: Border.all(color: const Color(0xFF2F1E18), width: 2),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFFDF1D8),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        child,
      ],
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
