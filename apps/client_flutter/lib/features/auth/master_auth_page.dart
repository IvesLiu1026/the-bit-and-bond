import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_session.dart';
import '../../core/network/auth_api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../state/providers.dart';

enum _MasterMode { register, login }

class MasterAuthPage extends ConsumerStatefulWidget {
  const MasterAuthPage({super.key});

  @override
  ConsumerState<MasterAuthPage> createState() => _MasterAuthPageState();
}

class _MasterAuthPageState extends ConsumerState<MasterAuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _guildNameController = TextEditingController(text: 'Chen Cozy Guild');
  final _formKey = GlobalKey<FormState>();

  _MasterMode _mode = _MasterMode.register;
  bool _submitting = false;
  String? _errorMessage;
  String? _lastInviteCode;

  @override
  void initState() {
    super.initState();
    _guildNameController.addListener(_onGuildNameChanged);
  }

  @override
  void dispose() {
    _guildNameController.removeListener(_onGuildNameChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _guildNameController.dispose();
    super.dispose();
  }

  void _onGuildNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(authControllerProvider.notifier);
      final AuthSession session;
      if (_mode == _MasterMode.register) {
        session = await auth.registerMaster(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          guildName: _guildNameController.text.trim(),
        );
      } else {
        session = await auth.loginMaster(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) {
        return;
      }

      if (_mode == _MasterMode.register &&
          (session.inviteCode ?? '').isNotEmpty) {
        setState(() {
          _lastInviteCode = session.inviteCode;
        });

        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.parchment,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.woodFrame, width: 3),
              ),
              title: const Text('公會建立完成'),
              content: SelectableText(
                'Invite Code: ${session.inviteCode}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navyBlue,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('進入公會'),
                ),
              ],
            );
          },
        );
      }

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
    final modeLabel = _mode == _MasterMode.register ? '簽署公會契約' : '進入公會控制室';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _MasterBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _BurntParchmentPanel(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '公會創立契約',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.inkBrown,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<_MasterMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: _MasterMode.register,
                              label: Text('註冊'),
                            ),
                            ButtonSegment(
                              value: _MasterMode.login,
                              label: Text('登入'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: _submitting
                              ? null
                              : (selection) {
                                  setState(() {
                                    _mode = selection.first;
                                    _errorMessage = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          modeLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navyBlue,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Form(
                          key: _formKey,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 780;
                              return Flex(
                                direction: wide
                                    ? Axis.horizontal
                                    : Axis.vertical,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      children: [
                                        _StoneInput(
                                          label: 'Email',
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          enabled: !_submitting,
                                          validator: (value) {
                                            if ((value ?? '').trim().isEmpty) {
                                              return '請輸入 email';
                                            }
                                            if (!(value!.contains('@'))) {
                                              return 'email 格式不正確';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        _StoneInput(
                                          label: 'Password',
                                          controller: _passwordController,
                                          obscureText: true,
                                          enabled: !_submitting,
                                          validator: (value) {
                                            if ((value ?? '').length < 8) {
                                              return '密碼至少 8 碼';
                                            }
                                            return null;
                                          },
                                        ),
                                        if (_mode == _MasterMode.register) ...[
                                          const SizedBox(height: 10),
                                          _StoneInput(
                                            label: 'Guild Name',
                                            controller: _guildNameController,
                                            enabled: !_submitting,
                                            validator: (value) {
                                              if ((value ?? '')
                                                  .trim()
                                                  .isEmpty) {
                                                return '請輸入公會名稱';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (wide) const SizedBox(width: 12),
                                  Expanded(
                                    flex: 4,
                                    child: _GuildFlagPreview(
                                      guildName: _guildNameController.text
                                          .trim(),
                                      inviteCode: _lastInviteCode,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.hpRuby.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.hpRuby.withValues(alpha: 0.7),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.hpRuby,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        _ChunkyActionButton(
                          busy: _submitting,
                          onPressed: _submitting ? null : _submit,
                          text: _mode == _MasterMode.register
                              ? '簽署並創立公會'
                              : '進入公會',
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

class _MasterBackground extends StatelessWidget {
  const _MasterBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.grassBase,
      child: CustomPaint(painter: _NoisePainter()),
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1A3E2723);
    for (double y = 0; y < size.height; y += 18) {
      for (double x = 0; x < size.width; x += 18) {
        final radius = ((x.toInt() + y.toInt()) % 7 == 0) ? 1.3 : 0.6;
        canvas.drawCircle(Offset(x + 4, y + 4), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StoneInput extends StatelessWidget {
  const _StoneInput({
    required this.label,
    required this.controller,
    required this.validator,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String? value) validator;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final borderColor = enabled ? AppColors.woodFrame : AppColors.softWood;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 3),
      ),
      child: Stack(
        children: [
          TextFormField(
            controller: controller,
            validator: validator,
            enabled: enabled,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.inkBrown,
            ),
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: const Color(0xFFE7DDC9),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x44000000),
                      Color(0x11000000),
                      Color(0x00000000),
                      Color(0x22000000),
                    ],
                    stops: [0, 0.08, 0.6, 1],
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

class _GuildFlagPreview extends StatelessWidget {
  const _GuildFlagPreview({required this.guildName, required this.inviteCode});

  final String guildName;
  final String? inviteCode;

  @override
  Widget build(BuildContext context) {
    final trimmed = guildName.trim();
    final crest = trimmed.isEmpty
        ? 'CG'
        : trimmed.length >= 2
        ? trimmed.substring(0, 2)
        : trimmed;
    final flagPalette = _flagPaletteForName(trimmed);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9DFC9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.woodFrame, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '公會旗幟預覽',
            style: TextStyle(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [flagPalette.top, flagPalette.bottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: flagPalette.edge, width: 3),
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF7B5A3C),
                      width: 3,
                    ),
                  ),
                  child: Text(
                    crest.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.navyBlue,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  guildName.isEmpty ? 'Chen Cozy Guild' : guildName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF8EED8),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if ((inviteCode ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Invite: $inviteCode',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navyBlue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FlagPalette {
  const _FlagPalette({
    required this.top,
    required this.bottom,
    required this.edge,
  });

  final Color top;
  final Color bottom;
  final Color edge;
}

_FlagPalette _flagPaletteForName(String guildName) {
  final seed = guildName.isEmpty ? 'COZYGUILD' : guildName.toUpperCase();
  final hash = seed.codeUnits.fold<int>(17, (acc, code) => (acc * 37 + code));

  final top = Color.fromRGBO(
    65 + (hash & 0x5F),
    45 + ((hash >> 5) & 0x4F),
    80 + ((hash >> 10) & 0x67),
    1,
  );
  final bottom = Color.fromRGBO(
    ((top.r * 255) * 0.64).round().clamp(0, 255),
    ((top.g * 255) * 0.64).round().clamp(0, 255),
    ((top.b * 255) * 0.64).round().clamp(0, 255),
    1,
  );
  final edge = Color.fromRGBO(
    ((bottom.r * 255) * 0.72).round().clamp(0, 255),
    ((bottom.g * 255) * 0.72).round().clamp(0, 255),
    ((bottom.b * 255) * 0.72).round().clamp(0, 255),
    1,
  );

  return _FlagPalette(top: top, bottom: bottom, edge: edge);
}

class _BurntEdgePainter extends CustomPainter {
  const _BurntEdgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0x663E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final ember = Paint()..color = const Color(0x553E2723);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3),
      const Radius.circular(16),
    );
    canvas.drawRRect(rect, stroke);

    for (double x = 12; x < size.width - 12; x += 20) {
      final notch = (x.toInt() * 17) % 9;
      canvas.drawCircle(
        Offset(x, 2 + notch * 0.3),
        1.2 + (notch * 0.06),
        ember,
      );
      canvas.drawCircle(
        Offset(x, size.height - 2 - notch * 0.2),
        1.1 + (notch * 0.05),
        ember,
      );
    }
    for (double y = 16; y < size.height - 16; y += 22) {
      final notch = (y.toInt() * 11) % 7;
      canvas.drawCircle(
        Offset(2 + notch * 0.2, y),
        1.0 + (notch * 0.05),
        ember,
      );
      canvas.drawCircle(
        Offset(size.width - 2 - notch * 0.2, y),
        1.0 + (notch * 0.05),
        ember,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BurntParchmentPanel extends StatelessWidget {
  const _BurntParchmentPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const _BurntEdgePainter(),
      child: Container(
        padding: const EdgeInsets.all(18),
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
        child: child,
      ),
    );
  }
}

class _ChunkyActionButton extends StatefulWidget {
  const _ChunkyActionButton({
    required this.text,
    required this.onPressed,
    required this.busy,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  State<_ChunkyActionButton> createState() => _ChunkyActionButtonState();
}

class _ChunkyActionButtonState extends State<_ChunkyActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
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
          boxShadow: _pressed
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0xAA1B5E20),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Center(
          child: widget.busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.text,
                  style: const TextStyle(
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
