import 'package:flutter/widgets.dart';

import '../../core/l10n/app_strings.dart';

enum AvatarHairStyle {
  crop('雙叉頭'),
  windswept('斜叉頭'),
  ponytail('磁吸頭');

  const AvatarHairStyle(this.label);

  final String label;

  String localizedLabel(AppStrings strings) {
    return switch (this) {
      AvatarHairStyle.crop => strings.tr(zh: '雙叉頭', en: 'Twin Plug'),
      AvatarHairStyle.windswept => strings.tr(zh: '斜叉頭', en: 'Tilt Plug'),
      AvatarHairStyle.ponytail => strings.tr(zh: '磁吸頭', en: 'Mag Plug'),
    };
  }
}

enum AvatarClothTone {
  ember('琥珀外殼', Color(0xFFE1A155)),
  moss('苔銅外殼', Color(0xFFB39A57)),
  sapphire('湖藍外殼', Color(0xFF6EAFC0)),
  plum('暮紫外殼', Color(0xFFB08BB6));

  const AvatarClothTone(this.label, this.color);

  final String label;
  final Color color;

  String localizedLabel(AppStrings strings) {
    return switch (this) {
      AvatarClothTone.ember => strings.tr(zh: '琥珀外殼', en: 'Amber Shell'),
      AvatarClothTone.moss => strings.tr(zh: '苔銅外殼', en: 'Moss Brass'),
      AvatarClothTone.sapphire => strings.tr(zh: '湖藍外殼', en: 'Lake Blue'),
      AvatarClothTone.plum => strings.tr(zh: '暮紫外殼', en: 'Plum Shell'),
    };
  }
}

enum AvatarFacing { down, up, left, right }

class AvatarAppearance {
  const AvatarAppearance({required this.hairStyle, required this.clothTone});

  final AvatarHairStyle hairStyle;
  final AvatarClothTone clothTone;

  String toAvatarType() => 'hair:${hairStyle.name}|cloth:${clothTone.name}';

  String get summaryLabel => '${hairStyle.label} / ${clothTone.label}';

  String localizedSummaryLabel(AppStrings strings) =>
      '${hairStyle.localizedLabel(strings)} / ${clothTone.localizedLabel(strings)}';

  static const AvatarAppearance novice = AvatarAppearance(
    hairStyle: AvatarHairStyle.crop,
    clothTone: AvatarClothTone.ember,
  );

  factory AvatarAppearance.fromAvatarType(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return novice;
    }

    final legacy = _legacyAvatarMap[normalized];
    if (legacy != null) {
      return legacy;
    }

    AvatarHairStyle hair = novice.hairStyle;
    AvatarClothTone cloth = novice.clothTone;

    for (final segment in normalized.split('|')) {
      final parts = segment.split(':');
      if (parts.length != 2) {
        continue;
      }
      final key = parts.first.trim();
      final value = parts.last.trim();
      if (key == 'hair') {
        hair = AvatarHairStyle.values.firstWhere(
          (candidate) => candidate.name == value,
          orElse: () => hair,
        );
      } else if (key == 'cloth') {
        cloth = AvatarClothTone.values.firstWhere(
          (candidate) => candidate.name == value,
          orElse: () => cloth,
        );
      }
    }
    return AvatarAppearance(hairStyle: hair, clothTone: cloth);
  }

  static const Map<String, AvatarAppearance> _legacyAvatarMap =
      <String, AvatarAppearance>{
        'novice': novice,
        'default': novice,
        'rookie': AvatarAppearance(
          hairStyle: AvatarHairStyle.crop,
          clothTone: AvatarClothTone.moss,
        ),
        'master': AvatarAppearance(
          hairStyle: AvatarHairStyle.ponytail,
          clothTone: AvatarClothTone.sapphire,
        ),
        'mage': AvatarAppearance(
          hairStyle: AvatarHairStyle.windswept,
          clothTone: AvatarClothTone.plum,
        ),
        'warrior': AvatarAppearance(
          hairStyle: AvatarHairStyle.crop,
          clothTone: AvatarClothTone.ember,
        ),
        'archer': AvatarAppearance(
          hairStyle: AvatarHairStyle.windswept,
          clothTone: AvatarClothTone.moss,
        ),
        'rogue': AvatarAppearance(
          hairStyle: AvatarHairStyle.crop,
          clothTone: AvatarClothTone.plum,
        ),
      };
}

class PixelAvatarPreview extends StatelessWidget {
  const PixelAvatarPreview({
    super.key,
    required this.appearance,
    this.facing = AvatarFacing.down,
    this.walkFrame = 0,
  });

  final AvatarAppearance appearance;
  final AvatarFacing facing;
  final int walkFrame;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 128,
          height: 128,
          child: CustomPaint(
            painter: _PixelAvatarPreviewPainter(
              appearance: appearance,
              facing: facing,
              walkFrame: walkFrame,
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelAvatarPreviewPainter extends CustomPainter {
  const _PixelAvatarPreviewPainter({
    required this.appearance,
    required this.facing,
    required this.walkFrame,
  });

  final AvatarAppearance appearance;
  final AvatarFacing facing;
  final int walkFrame;

  @override
  void paint(Canvas canvas, Size size) {
    AvatarPixelRenderer.paint(
      canvas,
      appearance: appearance,
      facing: facing,
      walkFrame: walkFrame,
      pixelSize: size.shortestSide / AvatarPixelRenderer.logicalSize,
    );
  }

  @override
  bool shouldRepaint(covariant _PixelAvatarPreviewPainter oldDelegate) {
    return appearance != oldDelegate.appearance ||
        facing != oldDelegate.facing ||
        walkFrame != oldDelegate.walkFrame;
  }
}

class AvatarPixelRenderer {
  static const double logicalSize = 32;

  static void paint(
    Canvas canvas, {
    required AvatarAppearance appearance,
    required AvatarFacing facing,
    required int walkFrame,
    required double pixelSize,
    double connectionStrength = 0,
    bool energizeLeftSocket = false,
    bool energizeRightPlug = false,
  }) {
    final mirrored = facing == AvatarFacing.right;
    final effectiveFacing = mirrored ? AvatarFacing.left : facing;
    final rearView = effectiveFacing == AvatarFacing.up;
    final sideView = effectiveFacing == AvatarFacing.left;
    final shellColor = const Color(0xFFF5F3F5);
    final shellShade = const Color(0xFFD9D6DB);
    final outlineColor = const Color(0xFF111111);
    final bodyColor = const Color(0xFFEDEBED);
    final bodyShade = const Color(0xFFD5D3D8);
    final accentColor = appearance.clothTone.color;
    final screenColor =
        Color.lerp(const Color(0xFF9EBDE7), accentColor, 0.16) ??
        const Color(0xFF9EBDE7);
    final screenShade =
        Color.lerp(screenColor, const Color(0xFF6F88AB), 0.34) ??
        const Color(0xFF6F88AB);
    final glowColor = const Color(
      0xFF9DEFFF,
    ).withValues(alpha: 0.34 + (connectionStrength * 0.26));
    final glowCore = const Color(
      0xFFD8FFFF,
    ).withValues(alpha: 0.72 + (connectionStrength * 0.2));
    const wireColor = Color(0xFF1A1514);

    canvas.save();
    if (mirrored) {
      canvas.translate(logicalSize * pixelSize, 0);
      canvas.scale(-1, 1);
    }

    final screenOutline = sideView
        ? const <Rect>[Rect.fromLTWH(11, 5, 11, 10)]
        : const <Rect>[Rect.fromLTWH(9, 5, 14, 10)];
    final screenFill = sideView
        ? const <Rect>[Rect.fromLTWH(12, 6, 9, 8)]
        : const <Rect>[Rect.fromLTWH(10, 6, 12, 8)];
    final screenShadeBand = sideView
        ? const <Rect>[Rect.fromLTWH(12, 11, 9, 3)]
        : const <Rect>[Rect.fromLTWH(10, 11, 12, 3)];

    _drawRects(
      canvas,
      _tailOutlineRects(sideView: sideView, walkFrame: walkFrame),
      outlineColor,
      pixelSize,
    );
    _drawRects(
      canvas,
      _tailCableRects(sideView: sideView, walkFrame: walkFrame),
      wireColor,
      pixelSize,
    );
    _drawRects(
      canvas,
      _tailTipRects(sideView: sideView, walkFrame: walkFrame),
      accentColor,
      pixelSize,
    );

    _drawRects(canvas, _headOutlineRects, outlineColor, pixelSize);
    _drawRects(canvas, _headFillRects, shellColor, pixelSize);
    _drawRects(canvas, _headShadeRects, shellShade, pixelSize);
    _drawRects(canvas, _headGlossRects, const Color(0xFFFFFFFF), pixelSize);
    _drawRects(
      canvas,
      _topPlugOutlineRects(appearance.hairStyle, sideView: sideView),
      outlineColor,
      pixelSize,
    );
    _drawRects(
      canvas,
      _topPlugFillRects(appearance.hairStyle, sideView: sideView),
      accentColor,
      pixelSize,
    );

    _drawRects(canvas, screenOutline, outlineColor, pixelSize);
    _drawRects(canvas, screenFill, screenColor, pixelSize);
    _drawRects(canvas, screenShadeBand, screenShade, pixelSize);
    _drawRects(
      canvas,
      sideView
          ? const <Rect>[Rect.fromLTWH(13, 7, 3, 2)]
          : const <Rect>[Rect.fromLTWH(11, 7, 4, 2)],
      const Color(0x44FFFFFF),
      pixelSize,
    );

    if (rearView) {
      _drawRects(
        canvas,
        const <Rect>[Rect.fromLTWH(12, 8, 8, 4), Rect.fromLTWH(14, 13, 4, 1)],
        const Color(0xFF232327),
        pixelSize,
      );
      _drawRects(
        canvas,
        const <Rect>[Rect.fromLTWH(13, 9, 1, 1), Rect.fromLTWH(18, 9, 1, 1)],
        accentColor,
        pixelSize,
      );
    } else {
      _drawRects(
        canvas,
        sideView
            ? const <Rect>[Rect.fromLTWH(18, 9, 1, 2)]
            : const <Rect>[
                Rect.fromLTWH(13, 9, 1, 2),
                Rect.fromLTWH(18, 9, 1, 2),
              ],
        outlineColor,
        pixelSize,
      );
      _drawRects(
        canvas,
        sideView
            ? const <Rect>[Rect.fromLTWH(18, 9, 1, 1)]
            : const <Rect>[
                Rect.fromLTWH(13, 9, 1, 1),
                Rect.fromLTWH(18, 9, 1, 1),
              ],
        const Color(0xFFEAF8FF),
        pixelSize,
      );
      _drawRects(
        canvas,
        sideView
            ? const <Rect>[Rect.fromLTWH(16, 12, 3, 1)]
            : const <Rect>[Rect.fromLTWH(14, 12, 4, 1)],
        outlineColor,
        pixelSize,
      );
      if (!sideView) {
        _drawRects(
          canvas,
          const <Rect>[
            Rect.fromLTWH(11, 12, 1, 1),
            Rect.fromLTWH(20, 12, 1, 1),
          ],
          accentColor.withValues(alpha: 0.26),
          pixelSize,
        );
      }
    }

    _drawRects(canvas, _bodyOutlineRects, outlineColor, pixelSize);
    _drawRects(canvas, _bodyFillRects, bodyColor, pixelSize);
    _drawRects(canvas, _bodyShadeRects, bodyShade, pixelSize);
    _drawRects(
      canvas,
      const <Rect>[Rect.fromLTWH(12, 20, 3, 3)],
      accentColor,
      pixelSize,
    );
    _drawRects(
      canvas,
      const <Rect>[Rect.fromLTWH(17, 21, 2, 1), Rect.fromLTWH(20, 21, 1, 1)],
      outlineColor,
      pixelSize,
    );

    _drawRects(
      canvas,
      _armOutlineRects(sideView: sideView),
      outlineColor,
      pixelSize,
    );
    _drawRects(
      canvas,
      _armFillRects(sideView: sideView),
      shellColor,
      pixelSize,
    );
    _drawRects(canvas, _leftSocketOutlineRects, outlineColor, pixelSize);
    _drawRects(canvas, _leftSocketFillRects, shellColor, pixelSize);
    _drawRects(canvas, _leftSocketHoleRects, outlineColor, pixelSize);
    _drawRects(canvas, _rightPlugOutlineRects, outlineColor, pixelSize);
    _drawRects(canvas, _rightPlugFillRects, shellColor, pixelSize);

    if (energizeLeftSocket) {
      _drawRects(
        canvas,
        _leftConnectionGlowRects(connectionStrength),
        glowColor,
        pixelSize,
      );
      _drawRects(
        canvas,
        _leftConnectionCoreRects(connectionStrength),
        glowCore,
        pixelSize,
      );
    }
    if (energizeRightPlug) {
      _drawRects(
        canvas,
        _rightConnectionGlowRects(connectionStrength),
        glowColor,
        pixelSize,
      );
      _drawRects(
        canvas,
        _rightConnectionCoreRects(connectionStrength),
        glowCore,
        pixelSize,
      );
    }

    _drawRects(
      canvas,
      _legOutlineRects(left: true, walkFrame: walkFrame),
      outlineColor,
      pixelSize,
    );
    _drawRects(
      canvas,
      _legOutlineRects(left: false, walkFrame: walkFrame),
      outlineColor,
      pixelSize,
    );
    _drawRects(
      canvas,
      _legFillRects(left: true, walkFrame: walkFrame),
      shellColor,
      pixelSize,
    );
    _drawRects(
      canvas,
      _legFillRects(left: false, walkFrame: walkFrame),
      shellColor,
      pixelSize,
    );
    _drawRects(
      canvas,
      _footOutlineRects(left: true, walkFrame: walkFrame),
      outlineColor,
      pixelSize,
    );
    _drawRects(
      canvas,
      _footOutlineRects(left: false, walkFrame: walkFrame),
      outlineColor,
      pixelSize,
    );

    canvas.restore();
  }

  static void _drawRects(
    Canvas canvas,
    Iterable<Rect> rects,
    Color color,
    double pixelSize,
  ) {
    if (rects.isEmpty) {
      return;
    }
    final paint = Paint()..color = color;
    for (final rect in rects) {
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left * pixelSize,
          rect.top * pixelSize,
          rect.width * pixelSize,
          rect.height * pixelSize,
        ),
        paint,
      );
    }
  }

  static const List<Rect> _headOutlineRects = <Rect>[
    Rect.fromLTWH(8, 2, 16, 1),
    Rect.fromLTWH(7, 3, 18, 12),
    Rect.fromLTWH(8, 15, 16, 2),
  ];

  static const List<Rect> _headFillRects = <Rect>[
    Rect.fromLTWH(9, 3, 14, 1),
    Rect.fromLTWH(8, 4, 16, 11),
    Rect.fromLTWH(9, 15, 14, 1),
  ];

  static const List<Rect> _headShadeRects = <Rect>[
    Rect.fromLTWH(22, 4, 1, 11),
    Rect.fromLTWH(10, 14, 12, 1),
  ];

  static const List<Rect> _headGlossRects = <Rect>[
    Rect.fromLTWH(10, 4, 4, 1),
    Rect.fromLTWH(9, 5, 2, 1),
  ];

  static const List<Rect> _bodyOutlineRects = <Rect>[
    Rect.fromLTWH(10, 18, 12, 8),
  ];

  static const List<Rect> _bodyFillRects = <Rect>[Rect.fromLTWH(11, 19, 10, 6)];

  static const List<Rect> _bodyShadeRects = <Rect>[
    Rect.fromLTWH(19, 19, 1, 6),
    Rect.fromLTWH(12, 24, 7, 1),
  ];

  static List<Rect> _topPlugOutlineRects(
    AvatarHairStyle style, {
    required bool sideView,
  }) {
    return switch (style) {
      AvatarHairStyle.crop =>
        sideView
            ? const <Rect>[Rect.fromLTWH(17, 0, 3, 2)]
            : const <Rect>[
                Rect.fromLTWH(11, 0, 3, 2),
                Rect.fromLTWH(18, 0, 3, 2),
              ],
      AvatarHairStyle.windswept =>
        sideView
            ? const <Rect>[
                Rect.fromLTWH(16, 0, 4, 2),
                Rect.fromLTWH(19, 1, 2, 1),
              ]
            : const <Rect>[
                Rect.fromLTWH(17, 0, 3, 2),
                Rect.fromLTWH(20, 1, 2, 1),
              ],
      AvatarHairStyle.ponytail =>
        sideView
            ? const <Rect>[
                Rect.fromLTWH(11, 0, 2, 1),
                Rect.fromLTWH(10, 1, 2, 2),
                Rect.fromLTWH(17, 0, 3, 2),
              ]
            : const <Rect>[
                Rect.fromLTWH(10, 0, 2, 1),
                Rect.fromLTWH(9, 1, 2, 2),
                Rect.fromLTWH(18, 0, 3, 2),
              ],
    };
  }

  static List<Rect> _topPlugFillRects(
    AvatarHairStyle style, {
    required bool sideView,
  }) {
    return switch (style) {
      AvatarHairStyle.crop =>
        sideView
            ? const <Rect>[Rect.fromLTWH(18, 0, 1, 2)]
            : const <Rect>[
                Rect.fromLTWH(12, 0, 1, 2),
                Rect.fromLTWH(19, 0, 1, 2),
              ],
      AvatarHairStyle.windswept =>
        sideView
            ? const <Rect>[
                Rect.fromLTWH(17, 0, 2, 1),
                Rect.fromLTWH(19, 1, 1, 1),
              ]
            : const <Rect>[
                Rect.fromLTWH(18, 0, 1, 2),
                Rect.fromLTWH(20, 1, 1, 1),
              ],
      AvatarHairStyle.ponytail =>
        sideView
            ? const <Rect>[
                Rect.fromLTWH(11, 1, 1, 1),
                Rect.fromLTWH(18, 0, 1, 2),
              ]
            : const <Rect>[
                Rect.fromLTWH(10, 1, 1, 1),
                Rect.fromLTWH(19, 0, 1, 2),
              ],
    };
  }

  static List<Rect> _armOutlineRects({required bool sideView}) {
    if (sideView) {
      return const <Rect>[
        Rect.fromLTWH(4, 19, 3, 3),
        Rect.fromLTWH(24, 19, 4, 3),
      ];
    }
    return const <Rect>[
      Rect.fromLTWH(4, 19, 4, 3),
      Rect.fromLTWH(24, 19, 4, 3),
    ];
  }

  static List<Rect> _armFillRects({required bool sideView}) {
    if (sideView) {
      return const <Rect>[
        Rect.fromLTWH(5, 20, 1, 1),
        Rect.fromLTWH(25, 20, 2, 1),
      ];
    }
    return const <Rect>[
      Rect.fromLTWH(5, 20, 2, 1),
      Rect.fromLTWH(25, 20, 2, 1),
    ];
  }

  static const List<Rect> _leftSocketOutlineRects = <Rect>[
    Rect.fromLTWH(1, 18, 4, 5),
  ];

  static const List<Rect> _leftSocketFillRects = <Rect>[
    Rect.fromLTWH(2, 19, 2, 3),
  ];

  static const List<Rect> _leftSocketHoleRects = <Rect>[
    Rect.fromLTWH(2, 20, 1, 1),
    Rect.fromLTWH(3, 20, 1, 1),
  ];

  static const List<Rect> _rightPlugOutlineRects = <Rect>[
    Rect.fromLTWH(24, 19, 4, 3),
    Rect.fromLTWH(28, 19, 2, 1),
    Rect.fromLTWH(28, 21, 2, 1),
  ];

  static const List<Rect> _rightPlugFillRects = <Rect>[
    Rect.fromLTWH(25, 20, 3, 1),
  ];

  static List<Rect> _leftConnectionGlowRects(double strength) {
    final length = strength < 0.38 ? 2.0 : (strength < 0.68 ? 3.0 : 4.0);
    return <Rect>[
      Rect.fromLTWH(0, 18, length + 1, 5),
      Rect.fromLTWH(0, 19, length + 2, 3),
    ];
  }

  static List<Rect> _leftConnectionCoreRects(double strength) {
    final length = strength < 0.38 ? 1.0 : (strength < 0.68 ? 2.0 : 3.0);
    return <Rect>[
      Rect.fromLTWH(0, 20, length, 1),
      Rect.fromLTWH(length, 19, 1, 3),
    ];
  }

  static List<Rect> _rightConnectionGlowRects(double strength) {
    final length = strength < 0.38 ? 2.0 : (strength < 0.68 ? 3.0 : 4.0);
    return <Rect>[
      Rect.fromLTWH(26, 18, length + 2, 5),
      Rect.fromLTWH(27, 19, length + 1, 3),
    ];
  }

  static List<Rect> _rightConnectionCoreRects(double strength) {
    final length = strength < 0.38 ? 1.0 : (strength < 0.68 ? 2.0 : 3.0);
    return <Rect>[
      Rect.fromLTWH(28, 20, length + 1, 1),
      Rect.fromLTWH(29 + length, 19, 1, 1),
      Rect.fromLTWH(29 + length, 21, 1, 1),
    ];
  }

  static List<Rect> _legOutlineRects({
    required bool left,
    required int walkFrame,
  }) {
    final stride = _legStride(left, walkFrame);
    final x = left ? 12.0 : 18.0;
    return <Rect>[Rect.fromLTWH(x, 26 + stride, 3, 5 - stride)];
  }

  static List<Rect> _legFillRects({
    required bool left,
    required int walkFrame,
  }) {
    final stride = _legStride(left, walkFrame);
    final x = left ? 13.0 : 19.0;
    return <Rect>[Rect.fromLTWH(x, 27 + stride, 1, 3 - stride)];
  }

  static List<Rect> _footOutlineRects({
    required bool left,
    required int walkFrame,
  }) {
    final stride = _legStride(left, walkFrame);
    final x = left ? 11.0 : 17.0;
    return <Rect>[Rect.fromLTWH(x, 30 + stride, 4, 2)];
  }

  static double _legStride(bool left, int walkFrame) {
    if (left) {
      return (walkFrame == 1 || walkFrame == 2) ? -1 : 0;
    }
    return (walkFrame == 0 || walkFrame == 3) ? -1 : 0;
  }

  static List<Rect> _tailOutlineRects({
    required bool sideView,
    required int walkFrame,
  }) {
    final sway = walkFrame.isOdd ? -1.0 : 0.0;
    return sideView
        ? <Rect>[
            Rect.fromLTWH(22, 23 + sway, 5, 2),
            Rect.fromLTWH(26, 22 + sway, 2, 4),
          ]
        : <Rect>[
            Rect.fromLTWH(21, 23 + sway, 5, 2),
            Rect.fromLTWH(25, 22 + sway, 2, 4),
          ];
  }

  static List<Rect> _tailCableRects({
    required bool sideView,
    required int walkFrame,
  }) {
    final sway = walkFrame.isOdd ? -1.0 : 0.0;
    return sideView
        ? <Rect>[
            Rect.fromLTWH(23, 24 + sway, 3, 1),
            Rect.fromLTWH(26, 23 + sway, 1, 2),
          ]
        : <Rect>[
            Rect.fromLTWH(22, 24 + sway, 3, 1),
            Rect.fromLTWH(25, 23 + sway, 1, 2),
          ];
  }

  static List<Rect> _tailTipRects({
    required bool sideView,
    required int walkFrame,
  }) {
    final sway = walkFrame.isOdd ? -1.0 : 0.0;
    return sideView
        ? <Rect>[Rect.fromLTWH(27, 24 + sway, 1, 1)]
        : <Rect>[Rect.fromLTWH(26, 24 + sway, 1, 1)];
  }
}
