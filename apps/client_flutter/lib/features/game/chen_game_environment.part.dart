part of 'chen_game.dart';

class _TavernEnvironmentLayer extends Component
    with HasGameReference<TheBitAndBondGame> {
  _TavernEnvironmentLayer({
    required TavernVisualTheme theme,
    this.tavernBackdropImage,
  }) : _theme = theme;

  static const double _floorTile = 64;
  static const double _torchSpacing = 128;
  static const double _wallHeight = TheBitAndBondGame._baseTopWallHeight;
  ui.Picture? _cachedBase;
  Size _cachedSize = Size.zero;
  double _elapsed = 0;
  TavernVisualTheme _theme;
  final ui.Image? tavernBackdropImage;

  void setTheme(TavernVisualTheme theme) {
    if (_theme == theme) {
      return;
    }
    _theme = theme;
    markDirty();
  }

  void markDirty() {
    _cachedBase = null;
    _cachedSize = Size.zero;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final width = game.worldSize.x.floorToDouble();
    final height = game.worldSize.y.floorToDouble();
    if (width <= 0 || height <= 0) {
      return;
    }

    final targetSize = Size(width, height);
    final base = _ensureBasePicture(targetSize);
    if (base != null) {
      canvas.drawPicture(base);
    }
  }

  ui.Picture? _ensureBasePicture(Size size) {
    if (_cachedBase != null && _cachedSize == size) {
      return _cachedBase;
    }
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    _paintBase(c, width: size.width, height: size.height);
    _cachedBase = recorder.endRecording();
    _cachedSize = size;
    return _cachedBase;
  }

  void _paintBase(
    Canvas canvas, {
    required double width,
    required double height,
  }) {
    if (_theme == TavernVisualTheme.cozyWood && tavernBackdropImage != null) {
      _paintCozyBackdrop(
        canvas,
        width: width,
        height: height,
        image: tavernBackdropImage!,
      );
      return;
    }

    final (
      floorDarkColor,
      floorAltColor,
      boardLineColor,
      wallBaseColor,
      wallBrickColor,
      wallJointColor,
      carpetCoreColor,
      carpetBorderColor,
      tableColor,
      chairColor,
      shelfColor,
      flagColor,
      torchGlowColor,
      torchCoreColor,
      torchStickColor,
    ) = switch (_theme) {
      TavernVisualTheme.cozyWood => (
        const Color(0xFF5D4037),
        const Color(0xFF6D4C41),
        const Color(0x55251310),
        const Color(0xFF6E6E72),
        const Color(0xFF7B7B80),
        const Color(0x55333336),
        AppColors.hpRuby,
        const Color(0xFFD4AF37),
        const Color(0xFF7B5234),
        const Color(0xFF6A452E),
        const Color(0xFF5B3A2A),
        const Color(0xFF2E7D32),
        const Color(0xCCFFCC66),
        const Color(0xFFFFA726),
        const Color(0xFF4E342E),
      ),
      TavernVisualTheme.technoMinimal => (
        const Color(0xFF1A2330),
        const Color(0xFF243447),
        const Color(0x664A657A),
        const Color(0xFF2C3640),
        const Color(0xFF35424D),
        const Color(0x664A657A),
        const Color(0xFF3949AB),
        const Color(0xFF00ACC1),
        const Color(0xFF37474F),
        const Color(0xFF2A3942),
        const Color(0xFF263238),
        const Color(0xFF00BCD4),
        const Color(0xAA80DEEA),
        const Color(0xFF26C6DA),
        const Color(0xFF455A64),
      ),
      TavernVisualTheme.hotbloodAdventure => (
        const Color(0xFF4A261D),
        const Color(0xFF5A3125),
        const Color(0x66512720),
        const Color(0xFF5C4A45),
        const Color(0xFF6A554D),
        const Color(0x66402A24),
        const Color(0xFFC62828),
        const Color(0xFFFFD54F),
        const Color(0xFF8D4E2C),
        const Color(0xFF7A3F23),
        const Color(0xFF6B3A22),
        const Color(0xFFD32F2F),
        const Color(0xCCFFB74D),
        const Color(0xFFFF7043),
        const Color(0xFF5D4037),
      ),
    };

    final woodDark = Paint()..color = floorDarkColor;
    final woodAlt = Paint()..color = floorAltColor;
    final boardLine = Paint()
      ..color = boardLineColor
      ..strokeWidth = 1.2;
    final wallBase = Paint()..color = wallBaseColor;
    final wallBrick = Paint()..color = wallBrickColor;
    final wallJoint = Paint()
      ..color = wallJointColor
      ..strokeWidth = 1;
    final carpetCore = Paint()..color = carpetCoreColor;
    final carpetBorder = Paint()..color = carpetBorderColor;

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), woodDark);

    final rows = (height / _floorTile).ceil();
    final cols = (width / _floorTile).ceil();
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final rect = Rect.fromLTWH(
          col * _floorTile,
          row * _floorTile,
          _floorTile,
          _floorTile,
        );
        final paint = (row + col).isEven ? woodDark : woodAlt;
        canvas.drawRect(rect, paint);
        canvas.drawLine(
          Offset(rect.left, rect.top + (_floorTile * 0.5)),
          Offset(rect.right, rect.top + (_floorTile * 0.5)),
          boardLine,
        );
      }
    }

    final wallRect = Rect.fromLTWH(0, 0, width, _wallHeight);
    canvas.drawRect(wallRect, wallBase);
    final brickW = 48.0;
    final brickH = 24.0;
    final brickRows = (_wallHeight / brickH).ceil();
    final brickCols = (width / brickW).ceil() + 1;
    for (var row = 0; row < brickRows; row++) {
      final xShift = row.isOdd ? brickW / 2 : 0;
      for (var col = -1; col < brickCols; col++) {
        final rect = Rect.fromLTWH(
          (col * brickW) + xShift,
          row * brickH,
          brickW - 2,
          brickH - 2,
        );
        canvas.drawRect(rect, wallBrick);
      }
    }
    for (var y = 0.0; y <= _wallHeight; y += brickH) {
      canvas.drawLine(Offset(0, y), Offset(width, y), wallJoint);
    }

    final carpetWidth = math.max(240, width * 0.34).toDouble();
    final carpetHeight = math.max(180, height * 0.32).toDouble();
    final carpetRect = Rect.fromCenter(
      center: Offset(width / 2, height / 2 + 48),
      width: carpetWidth,
      height: carpetHeight,
    );
    final carpetOuter = carpetRect.inflate(8);
    final carpetShade = Paint()
      ..color = carpetCoreColor.withValues(alpha: 0.28);
    final carpetHighlight = Paint()
      ..color = carpetBorderColor.withValues(alpha: 0.35);
    canvas.drawRect(carpetOuter, carpetBorder);
    canvas.drawRect(carpetRect, carpetCore);
    canvas.drawRect(
      Rect.fromLTWH(
        carpetRect.left + 6,
        carpetRect.top + 6,
        carpetRect.width - 12,
        5,
      ),
      carpetHighlight,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        carpetRect.left + 6,
        carpetRect.bottom - 12,
        carpetRect.width - 12,
        6,
      ),
      carpetShade,
    );

    _paintCenterFurniture(
      canvas,
      tableColor: tableColor,
      chairColor: chairColor,
      tableRect: game._centerTableRect(),
    );
    _paintCornerDecor(
      canvas,
      width: width,
      shelfColor: shelfColor,
      flagColor: flagColor,
    );
    _paintTorches(
      canvas,
      width: width,
      glowColor: torchGlowColor,
      flameColor: torchCoreColor,
      stickColor: torchStickColor,
    );
  }

  void _paintCozyBackdrop(
    Canvas canvas, {
    required double width,
    required double height,
    required ui.Image image,
  }) {
    final sourceSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final targetRect = Rect.fromLTWH(0, 0, width, height);
    final sourceRect = _coverSourceRect(sourceSize, targetRect.size);
    canvas.drawImageRect(image, sourceRect, targetRect, Paint());

    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(width / 2, height * 0.55),
        math.max(width, height) * 0.72,
        const [
          Color(0x00000000),
          Color(0x2A140D08),
          Color(0x55140D08),
        ],
        const [0.0, 0.68, 1.0],
      );
    canvas.drawRect(targetRect, vignette);

    final topShade = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, height * 0.26),
        const [
          Color(0x661A0F09),
          Color(0x221A0F09),
          Color(0x001A0F09),
        ],
        const [0.0, 0.48, 1.0],
      );
    canvas.drawRect(targetRect, topShade);
  }

  Rect _coverSourceRect(Size sourceSize, Size destinationSize) {
    final sourceRatio = sourceSize.width / sourceSize.height;
    final destinationRatio = destinationSize.width / destinationSize.height;
    if ((sourceRatio - destinationRatio).abs() < 0.0001) {
      return Offset.zero & sourceSize;
    }
    if (sourceRatio > destinationRatio) {
      final cropWidth = sourceSize.height * destinationRatio;
      final dx = (sourceSize.width - cropWidth) / 2;
      return Rect.fromLTWH(dx, 0, cropWidth, sourceSize.height);
    }
    final cropHeight = sourceSize.width / destinationRatio;
    final dy = (sourceSize.height - cropHeight) / 2;
    return Rect.fromLTWH(0, dy, sourceSize.width, cropHeight);
  }

  void _paintTorches(
    Canvas canvas, {
    required double width,
    required Color glowColor,
    required Color flameColor,
    required Color stickColor,
  }) {
    final count = (width / _torchSpacing).floor() + 1;
    final t = (_elapsed * (1000 / 900)) % 1;
    for (var i = 0; i < count; i++) {
      final x = 24 + (i * _torchSpacing);
      final flicker =
          0.6 + (0.4 * (0.5 + 0.5 * math.sin((t + i) * math.pi * 2)));
      final glow = Paint()
        ..shader = ui.Gradient.radial(
          Offset(x.toDouble(), _wallHeight - 26),
          24,
          [
            glowColor.withValues(alpha: flicker),
            glowColor.withValues(alpha: 0),
          ],
        );
      final stick = Paint()..color = stickColor;
      final flame = Paint()..color = flameColor;
      canvas.drawCircle(Offset(x.toDouble(), _wallHeight - 26), 24, glow);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x.toDouble(), _wallHeight - 14),
          width: 5,
          height: 18,
        ),
        stick,
      );
      canvas.drawCircle(Offset(x.toDouble(), _wallHeight - 24), 7, flame);
    }
  }

  void _paintCenterFurniture(
    Canvas canvas, {
    required Color tableColor,
    required Color chairColor,
    required Rect tableRect,
  }) {
    final table = Paint()..color = tableColor;
    final chair = Paint()..color = chairColor;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF2E1B15);
    final shadow = Paint()..color = const Color(0x6620120C);
    final highlight = Paint()..color = const Color(0x33F6E2C3);

    canvas.drawRect(tableRect.shift(const Offset(0, 4)), shadow);
    canvas.drawRect(tableRect, table);
    canvas.drawRect(tableRect, border);
    canvas.drawRect(
      Rect.fromLTWH(
        tableRect.left + 4,
        tableRect.top + 4,
        tableRect.width - 8,
        4,
      ),
      highlight,
    );

    final leftChair = Rect.fromLTWH(
      tableRect.left - 42,
      tableRect.center.dy - 20,
      32,
      40,
    );
    final rightChair = Rect.fromLTWH(
      tableRect.right + 10,
      tableRect.center.dy - 20,
      32,
      40,
    );
    for (final rect in [leftChair, rightChair]) {
      canvas.drawRect(rect.shift(const Offset(0, 3)), shadow);
      canvas.drawRect(rect, chair);
      canvas.drawRect(rect, border);
      canvas.drawRect(
        Rect.fromLTWH(rect.left + 3, rect.top + 3, rect.width - 6, 3),
        highlight,
      );
    }
  }

  void _paintCornerDecor(
    Canvas canvas, {
    required double width,
    required Color shelfColor,
    required Color flagColor,
  }) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..color = const Color(0xFF2E1B15);
    final shelf = Paint()..color = shelfColor;
    final shelfRect = Rect.fromLTWH(width - 98, _wallHeight + 8, 66, 72);
    canvas.drawRect(shelfRect, shelf);
    canvas.drawRect(shelfRect, border);
    final books = Paint()..color = const Color(0xFFCFB53B);
    for (var i = 0; i < 4; i++) {
      final x = shelfRect.left + 8 + (i * 13);
      canvas.drawRect(
        Rect.fromLTWH(x, shelfRect.top + 10, 8, shelfRect.height - 20),
        books,
      );
    }

    final pole = Paint()..color = const Color(0xFF5D4037);
    final flag = Paint()..color = flagColor;
    canvas.drawRect(Rect.fromLTWH(12, _wallHeight + 6, 4, 78), pole);
    final path = Path()
      ..moveTo(16, _wallHeight + 10)
      ..lineTo(70, _wallHeight + 22)
      ..lineTo(16, _wallHeight + 34)
      ..close();
    canvas.drawPath(path, flag);
    canvas.drawPath(path, border);
  }

  @override
  void onRemove() {
    _cachedBase = null;
    _cachedSize = Size.zero;
    super.onRemove();
  }
}
