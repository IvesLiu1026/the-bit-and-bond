import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/auth_api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../state/providers.dart';

enum _InputTarget { invite, pin }

class HunterLoginPage extends ConsumerStatefulWidget {
  const HunterLoginPage({super.key});

  @override
  ConsumerState<HunterLoginPage> createState() => _HunterLoginPageState();
}

class _HunterLoginPageState extends ConsumerState<HunterLoginPage> {
  String _inviteCode = '';
  String _pinCode = '';
  _InputTarget _target = _InputTarget.invite;
  bool _submitting = false;
  String? _errorMessage;

  bool get _canSubmit => _inviteCode.length == 6 && _pinCode.length == 4;

  void _appendCharacter(String char) {
    if (_target == _InputTarget.invite) {
      if (_inviteCode.length >= 6) {
        return;
      }
      setState(() {
        _inviteCode += char;
      });
      return;
    }

    if (_pinCode.length >= 4) {
      return;
    }
    setState(() {
      _pinCode += char;
    });
  }

  void _backspace() {
    if (_target == _InputTarget.invite) {
      if (_inviteCode.isEmpty) {
        return;
      }
      setState(() {
        _inviteCode = _inviteCode.substring(0, _inviteCode.length - 1);
      });
      return;
    }

    if (_pinCode.isEmpty) {
      return;
    }
    setState(() {
      _pinCode = _pinCode.substring(0, _pinCode.length - 1);
    });
  }

  Future<void> _loginHunter() async {
    if (!_canSubmit || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .loginHunter(inviteCode: _inviteCode, pinCode: _pinCode);

      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _HunterBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 940),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.parchment,
                      borderRadius: BorderRadius.circular(16),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                '獵人證綁定',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.inkBrown,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _CodePanel(
                          label: 'Invite Code',
                          code: _inviteCode,
                          length: 6,
                          focused: _target == _InputTarget.invite,
                          slotColor: const Color(0xFFD6B25F),
                          onTap: () =>
                              setState(() => _target = _InputTarget.invite),
                        ),
                        const SizedBox(height: 10),
                        _CodePanel(
                          label: 'PIN',
                          code: _pinCode,
                          length: 4,
                          focused: _target == _InputTarget.pin,
                          slotColor: AppColors.apSapphire,
                          mask: true,
                          onTap: () =>
                              setState(() => _target = _InputTarget.pin),
                        ),
                        const SizedBox(height: 12),
                        _target == _InputTarget.pin
                            ? _GemstoneNumpad(onDigit: _appendCharacter)
                            : _InvitePad(onKey: _appendCharacter),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionKeyButton(
                                label: 'Back',
                                icon: Icons.backspace,
                                tone: const Color(0xFF6D4C41),
                                onTap: _backspace,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ActionKeyButton(
                                label: 'Clear',
                                icon: Icons.close,
                                tone: const Color(0xFF8E0000),
                                onTap: () {
                                  setState(() {
                                    if (_target == _InputTarget.invite) {
                                      _inviteCode = '';
                                    } else {
                                      _pinCode = '';
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ActionKeyButton(
                                label: _target == _InputTarget.invite
                                    ? 'To PIN'
                                    : 'To Invite',
                                icon: Icons.swap_horiz,
                                tone: AppColors.apSapphire,
                                onTap: () {
                                  setState(() {
                                    _target = _target == _InputTarget.invite
                                        ? _InputTarget.pin
                                        : _InputTarget.invite;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.hpRuby,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _HunterEnterButton(
                          enabled: _canSubmit && !_submitting,
                          busy: _submitting,
                          onTap: _loginHunter,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HunterBackground extends StatelessWidget {
  const _HunterBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.grassBase,
      child: CustomPaint(painter: _HunterNoisePainter()),
    );
  }
}

class _HunterNoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x1A3E2723);
    for (double y = 4; y < size.height; y += 20) {
      for (double x = 4; x < size.width; x += 20) {
        if ((x.toInt() + y.toInt()) % 40 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CodePanel extends StatelessWidget {
  const _CodePanel({
    required this.label,
    required this.code,
    required this.length,
    required this.focused,
    required this.slotColor,
    required this.onTap,
    this.mask = false,
  });

  final String label;
  final String code;
  final int length;
  final bool focused;
  final Color slotColor;
  final VoidCallback onTap;
  final bool mask;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1E7D2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focused ? AppColors.navyBlue : AppColors.woodFrame,
            width: 3,
          ),
          boxShadow: focused
              ? const [
                  BoxShadow(
                    color: Color(0x553F51B5),
                    offset: Offset(0, 0),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.inkBrown,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(length, (index) {
                final filled = index < code.length;
                final char = filled ? code[index] : '';
                return Expanded(
                  child: Container(
                    height: 44,
                    margin: EdgeInsets.only(right: index == length - 1 ? 0 : 6),
                    alignment: Alignment.center,
                    decoration: _slotDecoration(
                      filled: filled,
                      mask: mask,
                      slotColor: slotColor,
                    ),
                    child: mask
                        ? (filled
                              ? _PinGemIndicator(color: slotColor)
                              : const SizedBox.shrink())
                        : Text(
                            filled ? char : '',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              color: slotColor,
                            ),
                          ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _slotDecoration({
    required bool filled,
    required bool mask,
    required Color slotColor,
  }) {
    if (!mask) {
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7E2A8), Color(0xFFD6B25F)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7B5A3C), width: 2.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55FFF3C7),
            offset: Offset(0, -1),
            blurRadius: 0,
          ),
        ],
      );
    }

    return BoxDecoration(
      color: const Color(0xFFE3ECF8),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: filled ? slotColor : slotColor.withValues(alpha: 0.45),
        width: 2.6,
      ),
      boxShadow: filled
          ? [
              BoxShadow(
                color: slotColor.withValues(alpha: 0.45),
                offset: const Offset(0, 0),
                blurRadius: 9,
                spreadRadius: 0.7,
              ),
            ]
          : const [],
    );
  }
}

class _PinGemIndicator extends StatelessWidget {
  const _PinGemIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [AppColors.joystickGemLight, color],
          center: const Alignment(-0.35, -0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 8,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.3, -0.3),
        child: Container(
          width: 4.5,
          height: 4.5,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _InvitePad extends StatelessWidget {
  const _InvitePad({required this.onKey});

  final void Function(String key) onKey;

  @override
  Widget build(BuildContext context) {
    const keys = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE9DFC9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.woodFrame, width: 3),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: keys
            .split('')
            .map((key) => _SmallKeyButton(label: key, onTap: () => onKey(key)))
            .toList(growable: false),
      ),
    );
  }
}

class _GemstoneNumpad extends StatelessWidget {
  const _GemstoneNumpad({required this.onDigit});

  final void Function(String digit) onDigit;

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE9DFC9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.woodFrame, width: 3),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: digits
            .map(
              (digit) => _GemstoneDigitButton(
                digit: digit,
                onTap: () => onDigit(digit),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _SmallKeyButton extends StatefulWidget {
  const _SmallKeyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SmallKeyButton> createState() => _SmallKeyButtonState();
}

class _SmallKeyButtonState extends State<_SmallKeyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: 42,
        height: 42,
        alignment: Alignment.center,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFD6B25F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF7B5A3C), width: 2.5),
          boxShadow: _pressed
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x994E342E),
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.inkBrown,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _GemstoneDigitButton extends StatefulWidget {
  const _GemstoneDigitButton({required this.digit, required this.onTap});

  final String digit;
  final VoidCallback onTap;

  @override
  State<_GemstoneDigitButton> createState() => _GemstoneDigitButtonState();
}

class _GemstoneDigitButtonState extends State<_GemstoneDigitButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: 62,
        height: 62,
        alignment: Alignment.center,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [AppColors.joystickGemLight, AppColors.joystickGem],
            center: Alignment(-0.35, -0.35),
          ),
          border: Border.all(color: const Color(0xFF0D3A62), width: 3),
          boxShadow: _pressed
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x993E2723),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              widget.digit,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            Positioned(
              top: 13,
              left: 17,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xCCFFFFFF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionKeyButton extends StatefulWidget {
  const _ActionKeyButton({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  State<_ActionKeyButton> createState() => _ActionKeyButtonState();
}

class _ActionKeyButtonState extends State<_ActionKeyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: widget.tone,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2F201A), width: 2.4),
          boxShadow: _pressed
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x993E2723),
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 17, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HunterEnterButton extends StatefulWidget {
  const _HunterEnterButton({
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_HunterEnterButton> createState() => _HunterEnterButtonState();
}

class _HunterEnterButtonState extends State<_HunterEnterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !widget.busy;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.submitGreen
              : AppColors.submitGreen.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            top: const BorderSide(color: AppColors.submitGreenEdge, width: 2.4),
            left: const BorderSide(
              color: AppColors.submitGreenEdge,
              width: 2.4,
            ),
            right: const BorderSide(
              color: AppColors.submitGreenEdge,
              width: 2.4,
            ),
            bottom: BorderSide(
              color: AppColors.submitGreenEdge,
              width: _pressed ? 1.5 : 5,
            ),
          ),
        ),
        child: Center(
          child: widget.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '進入冒險',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
        ),
      ),
    );
  }
}
