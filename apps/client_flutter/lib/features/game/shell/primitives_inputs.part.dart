part of '../game_shell_page.dart';

InputDecoration _pixelInputDecoration({
  required String labelText,
  String? hintText,
  bool dense = true,
}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(color: AppColors.woodFrame, width: 2.2),
  );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    isDense: dense,
    filled: true,
    fillColor: const Color(0xFFF2E7CE),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    labelStyle: PixelTypography.style(
      color: AppColors.inkBrown,
      fontWeight: FontWeight.w900,
      fontSize: 12,
      height: 1,
    ),
    hintStyle: PixelTypography.style(
      color: AppColors.inkBrown.withValues(alpha: 0.56),
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColors.navyBlue, width: 2.4),
    ),
    disabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: Color(0xFF9B8B7D), width: 2.2),
    ),
  );
}

class _PixelTextInput extends StatelessWidget {
  const _PixelTextInput({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.hintText,
    this.onSubmitted,
    this.textInputAction,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final String? hintText;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: PixelTypography.style(
        color: AppColors.inkBrown,
        fontWeight: FontWeight.w800,
        fontSize: 13,
        height: 1.08,
      ),
      decoration: _pixelInputDecoration(
        labelText: label,
        hintText: hintText,
        dense: maxLines == 1,
      ),
    );
  }
}

class _PixelDropdownField<T> extends StatelessWidget {
  const _PixelDropdownField({
    required this.label,
    required this.initialValue,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: enabled ? onChanged : null,
      style: PixelTypography.style(
        color: AppColors.inkBrown,
        fontWeight: FontWeight.w800,
        fontSize: 13,
        height: 1.04,
      ),
      dropdownColor: const Color(0xFFF2E7CE),
      iconEnabledColor: AppColors.inkBrown,
      iconDisabledColor: AppColors.inkBrown.withValues(alpha: 0.5),
      decoration: _pixelInputDecoration(labelText: label),
    );
  }
}
