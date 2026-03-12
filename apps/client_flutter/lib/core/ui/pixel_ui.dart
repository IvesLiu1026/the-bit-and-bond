import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/pixel_typography.dart';

enum PixelTone { parchment, wood, gold, green, blue, ruby, plum, slate }

const double kPixelButtonCompactWidth = 132;
const double kPixelButtonRegularWidth = 156;

class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.tone = PixelTone.parchment,
    this.cut = 10,
    this.borderWidth = 3,
    this.shadowDepth = 4,
    this.showShadow = true,
    this.faceColor,
    this.edgeColor,
    this.shadowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final PixelTone tone;
  final double cut;
  final double borderWidth;
  final double shadowDepth;
  final bool showShadow;
  final Color? faceColor;
  final Color? edgeColor;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final palette = _pixelPalette(tone);
    final resolvedCut = cut.clamp(4, 18).toDouble();
    final innerCut = math.max(2.0, resolvedCut - borderWidth);

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        if (showShadow)
          Positioned.fill(
            top: shadowDepth,
            child: _PixelShape(
              color: shadowColor ?? palette.shadow,
              cut: resolvedCut,
            ),
          ),
        _PixelShape(
          color: edgeColor ?? palette.edge,
          cut: resolvedCut,
          expandToConstraints: true,
          child: Padding(
            padding: EdgeInsets.all(borderWidth),
            child: _PixelShape(
              color: faceColor ?? palette.face,
              cut: innerCut,
              expandToConstraints: true,
              child: Padding(
                padding: padding,
                child: DefaultTextStyle.merge(
                  style: PixelTypography.style(color: palette.text),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    this.tapTargetKey,
    required this.label,
    required this.onPressed,
    this.leading,
    this.tone = PixelTone.wood,
    this.compact = false,
    this.expand = false,
    this.minWidth,
    this.maxWidth,
  });

  final Key? tapTargetKey;
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final PixelTone tone;
  final bool compact;
  final bool expand;
  final double? minWidth;
  final double? maxWidth;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final palette = _pixelPalette(widget.tone);
    final resolvedFace = enabled
        ? palette.face
        : Color.lerp(palette.face, const Color(0xFF5C5149), 0.35)!;
    final pressedFace = Color.lerp(
      resolvedFace,
      palette.edge,
      enabled ? 0.18 : 0.08,
    )!;

    final contents = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          SizedBox(width: widget.compact ? 8 : 10),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: PixelTypography.style(
              color: enabled
                  ? palette.text
                  : palette.text.withValues(alpha: 0.82),
              fontWeight: FontWeight.w900,
              fontSize: widget.compact ? 12 : 14,
              height: 1.02,
            ),
          ),
        ),
      ],
    );

    final panel = PixelPanel(
      tone: widget.tone,
      faceColor: _pressed ? pressedFace : resolvedFace,
      showShadow: false,
      borderWidth: 2,
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 9 : 12,
        vertical: widget.compact ? 7 : 9,
      ),
      child: contents,
    );

    final constrained = widget.expand
        ? panel
        : LayoutBuilder(
            builder: (context, constraints) {
              final defaultPreferred =
                  widget.maxWidth ??
                  (widget.compact
                      ? kPixelButtonCompactWidth
                      : kPixelButtonRegularWidth);
              final dynamicPreferred =
                  (widget.label.runes.length * (widget.compact ? 7.0 : 8.2)) +
                  (widget.leading == null
                      ? (widget.compact ? 20.0 : 24.0)
                      : (widget.compact ? 44.0 : 52.0));
              var preferredWidth =
                  (widget.minWidth == null && widget.maxWidth == null)
                  ? dynamicPreferred.clamp(
                      widget.compact ? 76.0 : 92.0,
                      defaultPreferred,
                    )
                  : defaultPreferred;
              final maxWidth = widget.maxWidth;
              if (maxWidth != null) {
                preferredWidth = math.min(preferredWidth, maxWidth);
              }
              final minWidth = widget.minWidth;
              if (minWidth != null) {
                preferredWidth = math.max(preferredWidth, minWidth);
              }
              final availableWidth = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : preferredWidth;
              var resolvedWidth = math.min(preferredWidth, availableWidth);
              if (minWidth != null && availableWidth >= minWidth) {
                resolvedWidth = math.max(resolvedWidth, minWidth);
              }
              return Center(
                child: SizedBox(width: resolvedWidth, child: panel),
              );
            },
          );

    return GestureDetector(
      key: widget.tapTargetKey,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 70),
        offset: _pressed ? const Offset(0, 0.03) : Offset.zero,
        child: constrained,
      ),
    );
  }
}

class PixelTag extends StatelessWidget {
  const PixelTag({
    super.key,
    required this.label,
    this.tone = PixelTone.wood,
    this.compact = false,
  });

  final String label;
  final PixelTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = _pixelPalette(tone);
    return PixelPanel(
      tone: tone,
      showShadow: false,
      cut: compact ? 8 : 10,
      borderWidth: 2,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      child: Text(
        label,
        style: PixelTypography.style(
          color: palette.text,
          fontWeight: FontWeight.w900,
          fontSize: compact ? 11 : 12,
          height: 1,
        ),
      ),
    );
  }
}

class PixelToggle extends StatelessWidget {
  const PixelToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final trackTone = value ? PixelTone.green : PixelTone.slate;
    final knobTone = value ? PixelTone.parchment : PixelTone.wood;
    final knobAlignment = value ? Alignment.centerRight : Alignment.centerLeft;

    return GestureDetector(
      onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.7,
        child: SizedBox(
          width: 88,
          height: 40,
          child: PixelPanel(
            tone: trackTone,
            cut: 10,
            borderWidth: 2,
            shadowDepth: 2,
            padding: const EdgeInsets.all(3),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              alignment: knobAlignment,
              child: SizedBox(
                width: 32,
                height: 26,
                child: PixelPanel(
                  tone: knobTone,
                  cut: 8,
                  borderWidth: 2,
                  shadowDepth: 1.5,
                  padding: EdgeInsets.zero,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PixelSlider extends StatelessWidget {
  const PixelSlider({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.divisions,
    this.enabled = true,
    this.activeTone = PixelTone.blue,
    this.inactiveTone = PixelTone.slate,
    this.knobTone = PixelTone.parchment,
  });

  final double min;
  final double max;
  final double value;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final bool enabled;
  final PixelTone activeTone;
  final PixelTone inactiveTone;
  final PixelTone knobTone;

  @override
  Widget build(BuildContext context) {
    final span = max - min;
    final safeSpan = span == 0 ? 1.0 : span;
    final clampedValue = value.clamp(min, max).toDouble();
    final normalized = ((clampedValue - min) / safeSpan).clamp(0.0, 1.0);
    final interactive = enabled && onChanged != null;

    return Opacity(
      opacity: interactive ? 1 : 0.7,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : 240.0;
          const knobWidth = 26.0;
          const knobHeight = 30.0;
          final usableWidth = math.max(1.0, width - knobWidth);
          final knobLeft = usableWidth * normalized;

          double resolveValue(double dx) {
            final ratio = (dx / usableWidth).clamp(0.0, 1.0);
            var next = min + (ratio * span);
            final steps = divisions;
            if (steps != null && steps > 0) {
              final stepSize = span / steps;
              if (stepSize > 0) {
                final snapped = ((next - min) / stepSize).round();
                next = min + (snapped * stepSize);
              }
            }
            return next.clamp(min, max).toDouble();
          }

          void handleLocalDx(double localDx) {
            if (!interactive) {
              return;
            }
            final centered = localDx - (knobWidth / 2);
            onChanged!(resolveValue(centered));
          }

          final tickCount = (divisions ?? 0) + 1;
          final showTicks = tickCount > 1 && tickCount <= 9;

          return SizedBox(
            height: 42,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: interactive
                  ? (details) => handleLocalDx(details.localPosition.dx)
                  : null,
              onHorizontalDragStart: interactive
                  ? (details) => handleLocalDx(details.localPosition.dx)
                  : null,
              onHorizontalDragUpdate: interactive
                  ? (details) => handleLocalDx(details.localPosition.dx)
                  : null,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 12,
                    height: 18,
                    child: PixelPanel(
                      tone: inactiveTone,
                      cut: 8,
                      borderWidth: 2,
                      shadowDepth: 1.5,
                      padding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: normalized,
                              child: SizedBox(
                                height: 18,
                                child: PixelPanel(
                                  tone: activeTone,
                                  cut: 6,
                                  borderWidth: 0,
                                  shadowDepth: 0,
                                  showShadow: false,
                                  padding: EdgeInsets.zero,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                          if (showTicks)
                            IgnorePointer(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List<Widget>.generate(
                                    tickCount,
                                    (_) => DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.38,
                                        ),
                                      ),
                                      child: const SizedBox(
                                        width: 2,
                                        height: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: knobLeft,
                    top: 6,
                    child: SizedBox(
                      width: knobWidth,
                      height: knobHeight,
                      child: PixelPanel(
                        tone: knobTone,
                        cut: 8,
                        borderWidth: 2,
                        shadowDepth: 2,
                        padding: EdgeInsets.zero,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PixelShape extends StatelessWidget {
  const _PixelShape({
    required this.color,
    required this.cut,
    this.child,
    this.expandToConstraints = false,
  });

  final Color color;
  final double cut;
  final Widget? child;
  final bool expandToConstraints;

  @override
  Widget build(BuildContext context) {
    final shaped = ClipPath(
      clipBehavior: Clip.hardEdge,
      clipper: _PixelStepCornersClipper(cut),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color),
        child: child ?? const SizedBox.expand(),
      ),
    );
    if (!expandToConstraints) {
      return shaped;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
          return SizedBox.expand(child: shaped);
        }
        if (constraints.hasBoundedWidth) {
          return SizedBox(width: constraints.maxWidth, child: shaped);
        }
        if (constraints.hasBoundedHeight) {
          return SizedBox(height: constraints.maxHeight, child: shaped);
        }
        return shaped;
      },
    );
  }
}

class _PixelStepCornersClipper extends CustomClipper<Path> {
  const _PixelStepCornersClipper(this.cut);

  final double cut;

  @override
  Path getClip(Size size) {
    final c = math.min(cut, math.min(size.width, size.height) / 2);
    final step = math.max(2.0, (c / 3).floorToDouble());
    final depth = step * 3;
    return Path()
      ..moveTo(depth, 0)
      ..lineTo(size.width - depth, 0)
      ..lineTo(size.width - depth, step)
      ..lineTo(size.width - step * 2, step)
      ..lineTo(size.width - step * 2, step * 2)
      ..lineTo(size.width - step, step * 2)
      ..lineTo(size.width - step, depth)
      ..lineTo(size.width, depth)
      ..lineTo(size.width, size.height - depth)
      ..lineTo(size.width - step, size.height - depth)
      ..lineTo(size.width - step, size.height - step * 2)
      ..lineTo(size.width - step * 2, size.height - step * 2)
      ..lineTo(size.width - step * 2, size.height - step)
      ..lineTo(size.width - depth, size.height - step)
      ..lineTo(size.width - depth, size.height)
      ..lineTo(depth, size.height)
      ..lineTo(depth, size.height - step)
      ..lineTo(step * 2, size.height - step)
      ..lineTo(step * 2, size.height - step * 2)
      ..lineTo(step, size.height - step * 2)
      ..lineTo(step, size.height - depth)
      ..lineTo(0, size.height - depth)
      ..lineTo(0, depth)
      ..lineTo(step, depth)
      ..lineTo(step, step * 2)
      ..lineTo(step * 2, step * 2)
      ..lineTo(step * 2, step)
      ..lineTo(depth, step)
      ..close();
  }

  @override
  bool shouldReclip(covariant _PixelStepCornersClipper oldClipper) {
    return oldClipper.cut != cut;
  }
}

class _PixelPalette {
  const _PixelPalette({
    required this.face,
    required this.edge,
    required this.shadow,
    required this.text,
  });

  final Color face;
  final Color edge;
  final Color shadow;
  final Color text;
}

_PixelPalette _pixelPalette(PixelTone tone) {
  return switch (tone) {
    PixelTone.parchment => const _PixelPalette(
      face: Color(0xFFF3E8CC),
      edge: Color(0xFF7A5A3B),
      shadow: Color(0xAA3B2419),
      text: AppColors.inkBrown,
    ),
    PixelTone.wood => const _PixelPalette(
      face: Color(0xFFC6A180),
      edge: Color(0xFF2F1B12),
      shadow: Color(0xAA1E120C),
      text: AppColors.inkBrown,
    ),
    PixelTone.gold => const _PixelPalette(
      face: Color(0xFFE6C16E),
      edge: Color(0xFF6A4A16),
      shadow: Color(0xAA412A0C),
      text: AppColors.inkBrown,
    ),
    PixelTone.green => const _PixelPalette(
      face: Color(0xFFA7D18D),
      edge: Color(0xFF214B26),
      shadow: Color(0xAA102613),
      text: AppColors.inkBrown,
    ),
    PixelTone.blue => const _PixelPalette(
      face: Color(0xFFA9BEE6),
      edge: Color(0xFF243963),
      shadow: Color(0xAA161E34),
      text: AppColors.inkBrown,
    ),
    PixelTone.ruby => const _PixelPalette(
      face: Color(0xFFE0A2A0),
      edge: Color(0xFF5A1E20),
      shadow: Color(0xAA2A1111),
      text: AppColors.inkBrown,
    ),
    PixelTone.plum => const _PixelPalette(
      face: Color(0xFFC4B0E2),
      edge: Color(0xFF382154),
      shadow: Color(0xAA20122E),
      text: AppColors.inkBrown,
    ),
    PixelTone.slate => const _PixelPalette(
      face: Color(0xFFC0B7AE),
      edge: Color(0xFF37474F),
      shadow: Color(0xAA1E272C),
      text: AppColors.inkBrown,
    ),
  };
}
