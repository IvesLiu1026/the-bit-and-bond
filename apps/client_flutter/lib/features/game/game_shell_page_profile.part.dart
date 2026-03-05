part of 'game_shell_page.dart';

class _PlayerProfileDialog extends StatefulWidget {
  const _PlayerProfileDialog({
    required this.socialState,
    required this.progressionState,
    required this.statsState,
    required this.onlineHunterIds,
    required this.onSaveMotto,
  });

  final AsyncValue<SocialSnapshot> socialState;
  final AsyncValue<Progression> progressionState;
  final AsyncValue<HunterStatsSummary?> statsState;
  final Set<String> onlineHunterIds;
  final Future<void> Function(String motto) onSaveMotto;

  @override
  State<_PlayerProfileDialog> createState() => _PlayerProfileDialogState();
}

class _PlayerProfileDialogState extends State<_PlayerProfileDialog> {
  final TextEditingController _mottoController = TextEditingController();
  bool _savingMotto = false;
  String? _mottoSeed;

  @override
  void dispose() {
    _mottoController.dispose();
    super.dispose();
  }

  void _syncMottoFromProfile(SocialProfile? profile) {
    final source = profile?.motto ?? '';
    if (_mottoSeed == source) {
      return;
    }
    _mottoSeed = source;
    _mottoController.text = source;
  }

  Future<void> _submitMotto() async {
    if (_savingMotto) {
      return;
    }
    final motto = _mottoController.text.trim();
    setState(() {
      _savingMotto = true;
    });
    try {
      await widget.onSaveMotto(motto);
    } finally {
      if (mounted) {
        setState(() {
          _savingMotto = false;
          _mottoSeed = motto;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialState = widget.socialState;
    final profile = socialState.maybeWhen(
      data: (s) => s.profile,
      orElse: () => null,
    );
    _syncMottoFromProfile(profile);

    final progression = widget.progressionState.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );
    final hunterStats = widget.statsState.maybeWhen(
      data: (stats) => stats,
      orElse: () => null,
    );
    final friends = socialState.maybeWhen(
      data: (s) => s.friends,
      orElse: () => const <FriendProfile>[],
    );
    final tag = profile?.hunterTag ?? 'ID-UNKNOWN';
    final level = profile?.level ?? progression?.level ?? 1;
    final xp = profile?.xp ?? progression?.xp ?? 0;
    final coins = profile?.coins ?? progression?.coins ?? 0;

    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              _PixelLabelGlyph(glyph: 'ID'),
              SizedBox(width: 8),
              Text(
                '玩家通行證',
                style: TextStyle(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE7DDC9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.woodFrame, width: 2.2),
            ),
            child: const TabBar(
              indicatorColor: AppColors.navyBlue,
              labelColor: AppColors.navyBlue,
              unselectedLabelColor: AppColors.inkBrown,
              labelStyle: TextStyle(fontWeight: FontWeight.w900),
              tabs: [
                Tab(text: '通行證'),
                Tab(text: '夥伴'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 470,
            child: TabBarView(
              children: [
                ListView(
                  children: [
                    Text(
                      '${profile?.displayName ?? '目前玩家'}  #$tag',
                      style: const TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '公會：${profile?.guildName ?? '-'}｜稱號：${profile?.roleTitle ?? '成員'}',
                      style: const TextStyle(
                        color: AppColors.navyBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(title: '等級', value: '$level'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(title: 'XP', value: '$xp'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(title: '金幣', value: '$coins'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _HunterRadarPanel(
                      statsState: widget.statsState,
                      stats: hunterStats,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8EED7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.woodFrame,
                          width: 2,
                        ),
                      ),
                      child: CustomPaint(
                        size: const Size(168, 168),
                        painter: _PseudoQrPainter(seed: tag),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mottoController,
                      maxLength: 40,
                      decoration: InputDecoration(
                        labelText: '個人格言',
                        hintText: '例如：每天前進一小步',
                        filled: true,
                        fillColor: const Color(0xFFE7DDC9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.woodFrame,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    _StampButton(
                      label: _savingMotto ? '儲存中...' : '儲存格言',
                      icon: Icons.bookmark_add_rounded,
                      tone: _StampTone.blue,
                      onPressed: _savingMotto ? null : _submitMotto,
                    ),
                  ],
                ),
                ListView(
                  children: [
                    Text(
                      '夥伴 ${friends.length} 位',
                      style: const TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      const Text(
                        '目前沒有夥伴，先輸入玩家 ID 發送好友請求吧。',
                        style: TextStyle(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      ...friends.map((friend) {
                        final isOnline = widget.onlineHunterIds.contains(
                          friend.id,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8EED7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.woodFrame,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF9E9E9E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${friend.name} (@${friend.playerId})',
                                      style: const TextStyle(
                                        color: AppColors.inkBrown,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isOnline
                                          ? '在線中'
                                          : '最近成就：Lv.${friend.level} · ${friend.xp} XP',
                                      style: TextStyle(
                                        color: isOnline
                                            ? AppColors.stampGreen
                                            : AppColors.navyBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HunterRadarPanel extends StatefulWidget {
  const _HunterRadarPanel({required this.statsState, required this.stats});

  final AsyncValue<HunterStatsSummary?> statsState;
  final HunterStatsSummary? stats;

  @override
  State<_HunterRadarPanel> createState() => _HunterRadarPanelState();
}

class _HunterRadarPanelState extends State<_HunterRadarPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _strTween;
  late Animation<double> _intTween;
  late Animation<double> _agiTween;
  late Animation<double> _chaTween;
  late Animation<double> _vitTween;
  List<double> _display = const [0, 0, 0, 0, 0];
  List<double> _target = const [0, 0, 0, 0, 0];
  int _maxScale = 100;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addListener(() {
          if (!mounted) {
            return;
          }
          setState(() {
            _display = [
              _strTween.value,
              _intTween.value,
              _agiTween.value,
              _chaTween.value,
              _vitTween.value,
            ];
          });
        });
    _resetTweens(animate: false);
  }

  @override
  void didUpdateWidget(covariant _HunterRadarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _toValues(widget.stats);
    final changed = next.asMap().entries.any(
      (entry) => entry.value != _target[entry.key],
    );
    if (changed) {
      _resetTweens(animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<double> _toValues(HunterStatsSummary? stats) {
    final raw = stats?.radarValues ?? const [0, 0, 0, 0, 0];
    return raw.map((value) => value.toDouble()).toList(growable: false);
  }

  void _resetTweens({required bool animate}) {
    _target = _toValues(widget.stats);
    _maxScale = math.max<int>(
      100,
      _target.fold<int>(0, (acc, value) => math.max(acc, value.round())),
    );
    final begin = List<double>.from(_display);
    if (!animate) {
      _display = List<double>.from(_target);
    }
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _strTween = Tween<double>(begin: begin[0], end: _target[0]).animate(curve);
    _intTween = Tween<double>(begin: begin[1], end: _target[1]).animate(curve);
    _agiTween = Tween<double>(begin: begin[2], end: _target[2]).animate(curve);
    _chaTween = Tween<double>(begin: begin[3], end: _target[3]).animate(curve);
    _vitTween = Tween<double>(begin: begin[4], end: _target[4]).animate(curve);
    if (animate) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F2A),
        border: Border.all(color: const Color(0xFF8B6F54), width: 2.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0xB3261811),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '能力分析',
            style: TextStyle(
              color: Color(0xFFF8EBD2),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.statsState.isLoading)
            const SizedBox(
              height: 180,
              child: Center(child: _PixelLoadingBar()),
            )
          else
            SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _HunterRadarPainter(
                  animatedValues: _display,
                  maxScale: _maxScale,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatGemChip(
                icon: const _PixelStatIcon(
                  category: QuestStatCategory.strength,
                  size: 14,
                  withFrame: false,
                ),
                label: 'STR ${widget.stats?.strXp ?? 0}',
                color: _statCategoryColor(QuestStatCategory.strength),
              ),
              _StatGemChip(
                icon: const _PixelStatIcon(
                  category: QuestStatCategory.intelligence,
                  size: 14,
                  withFrame: false,
                ),
                label: 'INT ${widget.stats?.intXp ?? 0}',
                color: _statCategoryColor(QuestStatCategory.intelligence),
              ),
              _StatGemChip(
                icon: const _PixelStatIcon(
                  category: QuestStatCategory.agility,
                  size: 14,
                  withFrame: false,
                ),
                label: 'AGI ${widget.stats?.agiXp ?? 0}',
                color: _statCategoryColor(QuestStatCategory.agility),
              ),
              _StatGemChip(
                icon: const _PixelStatIcon(
                  category: QuestStatCategory.charisma,
                  size: 14,
                  withFrame: false,
                ),
                label: 'CHA ${widget.stats?.chaXp ?? 0}',
                color: _statCategoryColor(QuestStatCategory.charisma),
              ),
              _StatGemChip(
                icon: const _PixelStatIcon(
                  category: QuestStatCategory.vitality,
                  size: 14,
                  withFrame: false,
                ),
                label: 'VIT ${widget.stats?.vitXp ?? 0}',
                color: _statCategoryColor(QuestStatCategory.vitality),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HunterRadarPainter extends CustomPainter {
  const _HunterRadarPainter({
    required this.animatedValues,
    required this.maxScale,
  });

  final List<double> animatedValues;
  final int maxScale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final maxValue = math.max(100, maxScale).toDouble();

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFF5B4A6A);
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xFF78658D);

    List<Offset> points(double factor) {
      return List<Offset>.generate(5, (index) {
        final angle = (-math.pi / 2) + (index * (math.pi * 2 / 5));
        return Offset(
          center.dx + (math.cos(angle) * radius * factor),
          center.dy + (math.sin(angle) * radius * factor),
        );
      });
    }

    for (var level = 1; level <= 4; level++) {
      final factor = level / 4;
      final ring = points(factor);
      final path = Path()..addPolygon(ring, true);
      canvas.drawPath(path, gridPaint);
      final scale = ((maxValue * factor).round()).toString();
      final scaleTp = TextPainter(
        text: TextSpan(
          text: scale,
          style: const TextStyle(
            color: Color(0xFFE7D7B8),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final scaleDx = (center.dx - radius - scaleTp.width - 8).clamp(
        2.0,
        size.width - scaleTp.width - 2.0,
      );
      final scaleDy = (center.dy + 2 - (radius * factor)).clamp(
        2.0,
        size.height - scaleTp.height - 2.0,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          scaleDx - 2,
          scaleDy - 1,
          scaleTp.width + 4,
          scaleTp.height + 2,
        ),
        Paint()..color = const Color(0xA8241923),
      );
      scaleTp.paint(canvas, Offset(scaleDx, scaleDy));
    }

    final outer = points(1);
    for (final point in outer) {
      canvas.drawLine(center, point, axisPaint);
    }

    final dataPoints = List<Offset>.generate(5, (index) {
      final value = index < animatedValues.length ? animatedValues[index] : 0.0;
      final ratio = (value / maxValue).clamp(0.0, 1.0);
      final angle = (-math.pi / 2) + (index * (math.pi * 2 / 5));
      return Offset(
        center.dx + (math.cos(angle) * radius * ratio),
        center.dy + (math.sin(angle) * radius * ratio),
      );
    });
    final dataPath = Path()..addPolygon(dataPoints, true);
    canvas.drawPath(dataPath, Paint()..color = const Color(0xAA64B5F6));
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFF90CAF9),
    );

    const labels = ['STR', 'INT', 'AGI', 'CHA', 'VIT'];
    for (var index = 0; index < labels.length; index++) {
      final anchor = outer[index];
      final tp = TextPainter(
        text: TextSpan(
          text: labels[index],
          style: const TextStyle(
            color: Color(0xFFF4ECE1),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (anchor.dx - (tp.width / 2)).clamp(
        2.0,
        size.width - tp.width - 2.0,
      );
      final dy = (anchor.dy - (tp.height / 2)).clamp(
        2.0,
        size.height - tp.height - 2.0,
      );
      canvas.drawRect(
        Rect.fromLTWH(dx - 3, dy - 1, tp.width + 6, tp.height + 2),
        Paint()..color = const Color(0x8A241923),
      );
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _HunterRadarPainter oldDelegate) {
    if (oldDelegate.maxScale != maxScale) {
      return true;
    }
    if (oldDelegate.animatedValues.length != animatedValues.length) {
      return true;
    }
    for (var i = 0; i < animatedValues.length; i++) {
      if (oldDelegate.animatedValues[i] != animatedValues[i]) {
        return true;
      }
    }
    return false;
  }
}

class _PseudoQrPainter extends CustomPainter {
  const _PseudoQrPainter({required this.seed});

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white;
    final dot = Paint()..color = AppColors.inkBrown;
    canvas.drawRect(Offset.zero & size, bg);

    const cells = 29;
    final cell = size.width / cells;
    final bits = seed.codeUnits.fold<int>(0, (sum, c) => sum * 31 + c);

    bool isFinder(int x, int y) {
      final topLeft = x < 7 && y < 7;
      final topRight = x >= cells - 7 && y < 7;
      final bottomLeft = x < 7 && y >= cells - 7;
      return topLeft || topRight || bottomLeft;
    }

    void paintFinder(int startX, int startY) {
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 7; x++) {
          final border = x == 0 || y == 0 || x == 6 || y == 6;
          final core = x >= 2 && x <= 4 && y >= 2 && y <= 4;
          if (!border && !core) {
            continue;
          }
          canvas.drawRect(
            Rect.fromLTWH((startX + x) * cell, (startY + y) * cell, cell, cell),
            dot,
          );
        }
      }
    }

    paintFinder(0, 0);
    paintFinder(cells - 7, 0);
    paintFinder(0, cells - 7);

    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        if (isFinder(x, y)) {
          continue;
        }
        final v = ((x * 13) ^ (y * 7) ^ bits) & 1;
        if (v == 0) {
          continue;
        }
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PseudoQrPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}
