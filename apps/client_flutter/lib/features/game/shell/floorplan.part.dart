part of '../game_shell_page.dart';

class _SandboxFloorplanOverlay extends StatelessWidget {
  const _SandboxFloorplanOverlay({
    required this.rooms,
    required this.currentRoomIndex,
    required this.compact,
    required this.onClose,
  });

  final List<SandboxRoomSnapshot> rooms;
  final int currentRoomIndex;
  final bool compact;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currentRoom = rooms[currentRoomIndex];
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 780),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        final liftProgress = Curves.easeOutCubic.transform(
          _transitionPhase(progress, 0, 0.42),
        );
        final flattenProgress = Curves.easeOutCubic.transform(
          _transitionPhase(progress, 0.12, 0.62),
        );
        final roomRevealProgress = Curves.easeOutCubic.transform(
          _transitionPhase(progress, 0.32, 0.86),
        );
        final markerProgress = Curves.easeOutBack.transform(
          _transitionPhase(progress, 0.58, 1),
        );
        final backgroundAlpha = 0.18 + (progress * 0.8);
        final mapScale = 1.18 - (liftProgress * 0.18);
        final mapOffsetY = 86 * (1 - liftProgress);

        return ColoredBox(
          color: const Color(0xFF15100D).withValues(alpha: backgroundAlpha),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 18,
                compact ? 14 : 18,
                compact ? 14 : 18,
                compact ? 18 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Opacity(
                    opacity: roomRevealProgress.clamp(0.0, 1.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.tr(zh: '空間平面圖', en: 'Space Map'),
                                style: TextStyle(
                                  color: AppColors.parchment,
                                  fontSize: compact ? 24 : 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                strings.tr(
                                  zh: '俯視模式：目前停在 ${currentRoom.label}',
                                  en: 'Top-down mode: currently in ${currentRoom.label}',
                                ),
                                style: TextStyle(
                                  color: AppColors.parchment.withValues(
                                    alpha: 0.82,
                                  ),
                                  fontSize: compact ? 12.5 : 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _FloorplanCloseButton(onPressed: onClose),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, mapOffsetY),
                        child: Transform.scale(
                          scale: mapScale,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (var i = 0; i < rooms.length; i++) ...[
                                  Opacity(
                                    opacity: i == currentRoomIndex
                                        ? 1
                                        : roomRevealProgress,
                                    child: Transform.translate(
                                      offset: Offset(
                                        i == currentRoomIndex
                                            ? 0
                                            : (1 - roomRevealProgress) * 28,
                                        0,
                                      ),
                                      child: _FloorplanRoomViewport(
                                        room: rooms[i],
                                        width: compact ? 196 : 232,
                                        compact: compact,
                                        flattenProgress: flattenProgress,
                                        markerRevealProgress: markerProgress,
                                        primary: i == currentRoomIndex,
                                      ),
                                    ),
                                  ),
                                  if (i < rooms.length - 1)
                                    Opacity(
                                      opacity: roomRevealProgress,
                                      child: Container(
                                        width: compact ? 28 : 36,
                                        height: 8,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.parchment.withValues(
                                            alpha: 0.42,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: roomRevealProgress.clamp(0.0, 1.0),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _FloorplanLegendChip(
                          color: Colors.white,
                          label: strings.tr(zh: '你的位置', en: 'You'),
                          circular: true,
                        ),
                        _FloorplanLegendChip(
                          color: AppColors.submitGreen,
                          label: strings.tr(zh: '測試 Bibon', en: 'Test Bibon'),
                          circular: false,
                        ),
                        _FloorplanLegendChip(
                          color: const Color(0xFF9FE7FF),
                          label: 'Portal',
                          circular: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

double _transitionPhase(double progress, double start, double end) {
  if (end <= start) {
    return progress >= end ? 1 : 0;
  }
  return ((progress - start) / (end - start)).clamp(0.0, 1.0).toDouble();
}

class _FloorplanRoomViewport extends StatelessWidget {
  const _FloorplanRoomViewport({
    required this.room,
    required this.width,
    required this.compact,
    required this.flattenProgress,
    required this.markerRevealProgress,
    required this.primary,
  });

  final SandboxRoomSnapshot room;
  final double width;
  final bool compact;
  final double flattenProgress;
  final double markerRevealProgress;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final active = room.isCurrent;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width,
            height: width,
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              color: room.accentColor.withValues(alpha: active ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: active ? room.accentColor : AppColors.parchment,
                width: active ? 4 : 2.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? room.accentColor.withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: 0.14),
                  blurRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _FloorplanRoomPainter(
                room: room,
                flattenProgress: flattenProgress,
                markerRevealProgress: markerRevealProgress,
                primary: primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            room.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.parchment,
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloorplanRoomPainter extends CustomPainter {
  const _FloorplanRoomPainter({
    required this.room,
    required this.flattenProgress,
    required this.markerRevealProgress,
    required this.primary,
  });

  final SandboxRoomSnapshot room;
  final double flattenProgress;
  final double markerRevealProgress;
  final bool primary;

  @override
  void paint(Canvas canvas, Size size) {
    final roomRect = Offset.zero & size;
    final wallPaint = Paint()..color = room.wallColor;
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final innerInset = size.width * 0.12;
    final floorRect = Rect.fromLTWH(
      innerInset,
      innerInset,
      size.width - (innerInset * 2),
      size.height - (innerInset * 2),
    );
    final floorPaint = Paint()..color = room.floorColor;
    final floorAltPaint = Paint()
      ..color =
          Color.lerp(room.floorColor, const Color(0xFF000000), 0.12) ??
          room.floorColor;
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..strokeWidth = 1.4;
    final roomLiftShadow = Paint()
      ..color = Colors.black.withValues(alpha: primary ? 0.18 : 0.12);
    final trapezoidTopInset = size.width * (0.28 - (0.16 * flattenProgress));
    final trapezoidTopY = size.height * (0.27 - (0.15 * flattenProgress));
    final trapezoidBottomInset = size.width * (0.06 + (0.06 * flattenProgress));
    final trapezoidBottomY = size.height * 0.84;
    final floorPath = Path()
      ..moveTo(trapezoidTopInset, trapezoidTopY)
      ..lineTo(size.width - trapezoidTopInset, trapezoidTopY)
      ..lineTo(size.width - trapezoidBottomInset, trapezoidBottomY)
      ..lineTo(trapezoidBottomInset, trapezoidBottomY)
      ..close();

    canvas.drawRRect(
      RRect.fromRectAndRadius(roomRect, const Radius.circular(24)),
      wallPaint,
    );
    canvas.drawShadow(floorPath, roomLiftShadow.color, 10, false);
    canvas.drawPath(floorPath, floorPaint);

    const tile = 22.0;
    canvas.save();
    canvas.clipPath(
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(floorRect, const Radius.circular(18)),
        )
        ..addPath(floorPath, Offset.zero),
      doAntiAlias: false,
    );
    for (var y = floorRect.top; y < floorRect.bottom; y += tile) {
      for (var x = floorRect.left; x < floorRect.right; x += tile) {
        final rect = Rect.fromLTWH(
          x,
          y,
          math.min(tile, floorRect.right - x),
          math.min(tile, floorRect.bottom - y),
        );
        final row = ((y - floorRect.top) / tile).floor();
        final col = ((x - floorRect.left) / tile).floor();
        final tileProgress = flattenProgress.clamp(0.0, 1.0);
        final blendedRect = Rect.lerp(
          Rect.fromLTWH(
            x + ((size.width * 0.5 - x) * (1 - tileProgress) * 0.18),
            y + ((floorRect.top - y) * (1 - tileProgress) * 0.16),
            rect.width,
            rect.height,
          ),
          rect,
          tileProgress,
        )!;
        canvas.drawRect(
          blendedRect,
          (row + col).isEven ? floorPaint : floorAltPaint,
        );
      }
    }
    final gridOpacity = flattenProgress.clamp(0.0, 1.0);
    final activeGrid = Paint()
      ..color = gridPaint.color.withValues(alpha: 0.16 * gridOpacity)
      ..strokeWidth = gridPaint.strokeWidth;
    for (var x = floorRect.left; x <= floorRect.right; x += tile) {
      canvas.drawLine(
        Offset(x, floorRect.top),
        Offset(x, floorRect.bottom),
        activeGrid,
      );
    }
    for (var y = floorRect.top; y <= floorRect.bottom; y += tile) {
      canvas.drawLine(
        Offset(floorRect.left, y),
        Offset(floorRect.right, y),
        activeGrid,
      );
    }
    canvas.restore();

    _paintPortal(canvas, roomRect, left: true, opacity: flattenProgress);
    _paintPortal(canvas, roomRect, left: false, opacity: flattenProgress);

    if (room.dummyMarker != null) {
      _paintMarker(
        canvas,
        marker: room.dummyMarker!,
        floorRect: floorRect,
        color: AppColors.submitGreen,
        square: true,
        revealProgress: markerRevealProgress,
      );
    }
    if (room.playerMarker != null) {
      _paintMarker(
        canvas,
        marker: room.playerMarker!,
        floorRect: floorRect,
        color: Colors.white,
        square: false,
        revealProgress: markerRevealProgress,
      );
    }
    if (room.isCurrent) {
      final focusPaint = Paint()
        ..color = room.accentColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          floorRect.inflate(6),
          const Radius.circular(22),
        ),
        focusPaint,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(roomRect, const Radius.circular(24)),
      borderPaint,
    );
  }

  void _paintPortal(
    Canvas canvas,
    Rect roomRect, {
    required bool left,
    required double opacity,
  }) {
    final enabled = left ? room.hasLeftPortal : room.hasRightPortal;
    if (!enabled) {
      return;
    }
    final portalRect = Rect.fromCenter(
      center: Offset(
        left ? roomRect.left + 8 : roomRect.right - 8,
        roomRect.center.dy,
      ),
      width: 14,
      height: roomRect.height * 0.24,
    );
    final portalPaint = Paint()
      ..color = const Color(0xFF9FE7FF).withValues(alpha: 0.82 * opacity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(portalRect, const Radius.circular(10)),
      portalPaint,
    );
  }

  void _paintMarker(
    Canvas canvas, {
    required Offset marker,
    required Rect floorRect,
    required Color color,
    required bool square,
    required double revealProgress,
  }) {
    final clampedReveal = revealProgress.clamp(0.0, 1.0);
    final center = Offset(
      floorRect.left + (floorRect.width * marker.dx),
      floorRect.top +
          (floorRect.height * marker.dy) +
          ((1 - clampedReveal) * 18),
    );
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25 * clampedReveal);
    final fillPaint = Paint()..color = color.withValues(alpha: clampedReveal);
    final strokePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.78 * clampedReveal)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (square) {
      final rect = Rect.fromCenter(center: center, width: 14, height: 14);
      canvas.drawRect(rect.shift(const Offset(0, 2)), shadowPaint);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, strokePaint);
      return;
    }

    canvas.drawCircle(center.translate(0, 2), 7, shadowPaint);
    canvas.drawCircle(center, 7, fillPaint);
    canvas.drawCircle(center, 7, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _FloorplanRoomPainter oldDelegate) {
    return oldDelegate.room != room ||
        oldDelegate.flattenProgress != flattenProgress ||
        oldDelegate.markerRevealProgress != markerRevealProgress ||
        oldDelegate.primary != primary;
  }
}

class _FloorplanCloseButton extends StatelessWidget {
  const _FloorplanCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: PixelButton(
        label: AppStrings.of(context).tr(zh: '返回場景', en: 'Back to Room'),
        tone: PixelTone.parchment,
        compact: true,
        onPressed: onPressed,
      ),
    );
  }
}

class _FloorplanLegendChip extends StatelessWidget {
  const _FloorplanLegendChip({
    required this.color,
    required this.label,
    required this.circular,
  });

  final Color color;
  final String label;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: circular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circular ? null : BorderRadius.circular(3),
              border: Border.all(color: Colors.black.withValues(alpha: 0.72)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.parchment,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
