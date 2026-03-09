part of '../unified_auth_page.dart';

class _PixelModeSwitch extends StatelessWidget {
  const _PixelModeSwitch({required this.selected, required this.onChanged});

  final UnifiedAuthMode selected;
  final ValueChanged<UnifiedAuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE7DDC9),
        border: Border.all(color: AppColors.woodFrame, width: 3),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PixelModeTab(
              label: strings.tr(zh: '登入', en: 'Sign In'),
              active: selected == UnifiedAuthMode.login,
              onTap: () => onChanged(UnifiedAuthMode.login),
            ),
          ),
          Expanded(
            child: _PixelModeTab(
              label: strings.tr(zh: '註冊', en: 'Register'),
              active: selected == UnifiedAuthMode.register,
              onTap: () => onChanged(UnifiedAuthMode.register),
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
    final strings = AppStrings.of(context);
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
              color: label == strings.tr(zh: '登入', en: 'Sign In')
                  ? AppColors.woodFrame
                  : Colors.transparent,
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
