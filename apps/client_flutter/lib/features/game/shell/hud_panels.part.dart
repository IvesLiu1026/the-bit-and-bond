part of '../game_shell_page.dart';

class _SummonScrollOverlay extends StatefulWidget {
  const _SummonScrollOverlay({
    required this.invite,
    required this.onAccept,
    required this.onReject,
  });

  final GuildInviteInfo invite;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  State<_SummonScrollOverlay> createState() => _SummonScrollOverlayState();
}

class _SummonScrollOverlayState extends State<_SummonScrollOverlay> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _opened = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      offset: _opened ? Offset.zero : const Offset(0.12, -0.18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: _opened ? 1 : 0,
        child: Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8ECD0),
            borderRadius: BorderRadius.circular(14),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  _PixelLabelGlyph(glyph: 'SC'),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '召喚捲軸',
                      style: TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.invite.inviterName}（@${widget.invite.inviterPlayerId}）正在召喚你加入公會。',
                style: const TextStyle(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StampButton(
                      label: '接受召喚',
                      icon: Icons.check_circle_rounded,
                      tone: _StampTone.green,
                      onPressed: widget.onAccept,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StampButton(
                      label: '稍後再說',
                      icon: Icons.close_rounded,
                      tone: _StampTone.ruby,
                      onPressed: widget.onReject,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RealtimeDebugHud extends StatelessWidget {
  const _RealtimeDebugHud({
    required this.connected,
    required this.txPerSec,
    required this.rxPerSec,
    required this.lastInboundAge,
    required this.lastOutboundAge,
    required this.totalActors,
    required this.remoteActors,
  });

  final bool connected;
  final double txPerSec;
  final double rxPerSec;
  final String lastInboundAge;
  final String lastOutboundAge;
  final int totalActors;
  final int remoteActors;

  @override
  Widget build(BuildContext context) {
    final statusColor = connected
        ? const Color(0xFF7BD45E)
        : const Color(0xFFF0625D);
    final cardColor = connected
        ? const Color(0xB83A2A22)
        : const Color(0xB84C2B2B);

    TextStyle labelStyle() => const TextStyle(
      color: Color(0xFFEADBC1),
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    TextStyle valueStyle() => const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w900,
      height: 1.1,
    );

    Widget row(String label, String value) {
      return Row(
        children: [
          Expanded(child: Text(label, style: labelStyle())),
          Text(value, style: valueStyle()),
        ],
      );
    }

    return Container(
      width: 182,
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xB39A7A57), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88311F16),
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                connected ? '連線中' : '重新連線中',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          row('每秒送出', txPerSec.toStringAsFixed(0)),
          const SizedBox(height: 2),
          row('每秒接收', rxPerSec.toStringAsFixed(0)),
          const SizedBox(height: 2),
          row('最近送出', lastOutboundAge),
          const SizedBox(height: 2),
          row('最近接收', lastInboundAge),
          const SizedBox(height: 2),
          row('角色數', '$totalActors（遠端 $remoteActors）'),
        ],
      ),
    );
  }
}

class _AvatarHudButton extends StatefulWidget {
  const _AvatarHudButton({required this.progressionState, required this.onTap});

  final AsyncValue<Progression> progressionState;
  final VoidCallback onTap;

  @override
  State<_AvatarHudButton> createState() => _AvatarHudButtonState();
}

class _AvatarHudButtonState extends State<_AvatarHudButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 80),
        offset: _pressed ? const Offset(0, 0.07) : Offset.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFFECE0C9) : AppColors.parchment,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.woodFrame, width: 3),
            boxShadow: _pressed
                ? const []
                : const [
                    BoxShadow(
                      color: AppColors.shadowHard,
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: widget.progressionState.when(
            data: (p) {
              final xpProgress = (p.xp % 100) / 100.0;
              return Row(
                children: [
                  _AvatarCoin(level: p.level),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lv.${p.level}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.inkBrown,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.hpTrack,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.woodFrame,
                              width: 1.3,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: xpProgress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.apSapphire,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _PixelLabelGlyph(glyph: 'ID'),
                ],
              );
            },
            loading: () => const Row(
              children: [
                _AvatarCoin(level: null),
                SizedBox(width: 10),
                Expanded(
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    color: AppColors.apSapphire,
                    backgroundColor: AppColors.hpTrack,
                  ),
                ),
              ],
            ),
            error: (_, _) => Row(
              children: [
                const _AvatarCoin(level: null),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '通行證',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.inkBrown,
                    ),
                  ),
                ),
                const _PixelLabelGlyph(glyph: 'ID'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarCoin extends StatelessWidget {
  const _AvatarCoin({required this.level});

  final int? level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFCFB38A), Color(0xFF8A6848)],
          center: Alignment(-0.35, -0.35),
          radius: 0.95,
        ),
        border: Border.all(color: AppColors.woodFrame, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x663E2723),
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        level == null ? '?' : '${level!}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 17,
        ),
      ),
    );
  }
}

class _MemberRosterPanel extends StatelessWidget {
  const _MemberRosterPanel({required this.hunters});

  final List<HunterProfile> hunters;

  @override
  Widget build(BuildContext context) {
    if (hunters.isEmpty) {
      return const Text(
        '目前公會尚無成員',
        style: TextStyle(
          color: AppColors.navyBlue,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: hunters
          .map(
            (hunter) => _StatGemChip(
              icon: const _PixelLabelGlyph(glyph: 'MB'),
              label: '${hunter.name} @${hunter.playerId ?? hunter.id}',
              color: AppColors.stampGreen,
              labelColor: AppColors.inkBrown,
            ),
          )
          .toList(growable: false),
    );
  }
}
