part of '../game_shell_page.dart';

class _HudOverlay extends StatelessWidget {
  const _HudOverlay({required this.progressionState, required this.onRefresh});

  final AsyncValue<Progression> progressionState;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _PixelLabelGlyph(glyph: 'BOX'),
            const SizedBox(width: 6),
            Text(
              strings.tr(zh: '冒險儲物箱', en: 'Adventure Cache'),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.inkBrown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        progressionState.when(
          data: (p) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.tr(
                    zh: '玩家 等級 ${p.level}',
                    en: 'Player Lv.${p.level}',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppColors.inkBrown,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatGemChip(
                      icon: const _PixelLabelGlyph(glyph: 'XP'),
                      label: '${p.xp} XP',
                      color: AppColors.apSapphire,
                    ),
                    _StatGemChip(
                      icon: const _PixelLabelGlyph(glyph: 'CO'),
                      label: strings.tr(
                        zh: '${p.coins} 金幣',
                        en: '${p.coins} Coins',
                      ),
                      color: const Color(0xFFB26A00),
                    ),
                    _StatGemChip(
                      icon: const _PixelLabelGlyph(glyph: 'Q'),
                      label: strings.tr(
                        zh: '${p.availableQuests} 任務',
                        en: '${p.availableQuests} Quests',
                      ),
                      color: AppColors.stampGreen,
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 68,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.8)),
          ),
          error: (err, _) => Text(
            strings.tr(zh: '狀態讀取錯誤：$err', en: 'Status load failed: $err'),
            style: const TextStyle(
              color: AppColors.hpRuby,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _StampButton(
          label: strings.tr(zh: '刷新狀態', en: 'Refresh'),
          icon: Icons.refresh,
          tone: _StampTone.wood,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}
