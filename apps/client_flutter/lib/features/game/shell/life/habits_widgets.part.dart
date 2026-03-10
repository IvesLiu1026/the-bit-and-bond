part of '../../game_shell_page.dart';

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    this.cardKey,
    required this.card,
    required this.isMaster,
    required this.apiBaseUrl,
    required this.authToken,
    required this.onSubmitProof,
    required this.onApprove,
    required this.onReject,
  });

  final Key? cardKey;
  final _HabitChallengeCardData card;
  final bool isMaster;
  final String apiBaseUrl;
  final String? authToken;
  final VoidCallback onSubmitProof;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final canSubmitProof =
        !isMaster &&
        (card.proofState == _HabitProofState.pending ||
            card.proofState == _HabitProofState.missed);
    final status = switch (card.proofState) {
      _HabitProofState.done => (
        strings.tr(zh: '完成', en: 'Done'),
        AppColors.stampGreen,
      ),
      _HabitProofState.review => (
        strings.tr(zh: '待審', en: 'Review'),
        const Color(0xFFB26A00),
      ),
      _HabitProofState.pending => (
        strings.tr(zh: '待提交', en: 'Pending'),
        AppColors.apSapphire,
      ),
      _HabitProofState.missed => (
        strings.tr(zh: '漏掉', en: 'Missed'),
        AppColors.hpRuby,
      ),
    };

    return Padding(
      key: cardKey,
      padding: const EdgeInsets.only(bottom: 8),
      child: PixelPanel(
        tone: PixelTone.parchment,
        padding: const EdgeInsets.all(12),
        cut: 12,
        shadowDepth: 3,
        faceColor: Colors.white.withValues(alpha: 0.38),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.title,
                    style: const TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                _StatGemChip(
                  icon: const _PixelLabelGlyph(glyph: 'HB'),
                  label: status.$1,
                  color: status.$2,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatGemChip(
                  icon: const _PixelLabelGlyph(glyph: 'DAY'),
                  label: card.cadence,
                  color: AppColors.navyBlue,
                ),
                _StatGemChip(
                  icon: const _PixelLabelGlyph(glyph: 'STK'),
                  label: strings.tr(
                    zh: '連續 ${card.streak} 天',
                    en: 'Streak ${card.streak}d',
                  ),
                  color: const Color(0xFF7C5FB3),
                ),
                _StatGemChip(
                  icon: const _PixelLabelGlyph(glyph: 'RWD'),
                  label: card.rewardLabel,
                  color: const Color(0xFFB26A00),
                ),
              ],
            ),
            if (card.assignedBy != null) ...[
              const SizedBox(height: 8),
              Text(
                strings.tr(
                  zh: '指派者：${card.assignedBy}',
                  en: 'Assigned by: ${card.assignedBy}',
                ),
                style: TextStyle(
                  color: AppColors.inkBrown.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (card.proofNote != null && card.proofNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                strings.tr(
                  zh: '最近證明：${card.proofNote}',
                  en: 'Latest proof: ${card.proofNote}',
                ),
                style: TextStyle(
                  color: AppColors.inkBrown.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (card.reviewNote != null && card.reviewNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                strings.tr(
                  zh: '審核備註：${card.reviewNote}',
                  en: 'Review note: ${card.reviewNote}',
                ),
                style: TextStyle(
                  color: AppColors.inkBrown.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (card.proofMedia.isNotEmpty) ...[
              const SizedBox(height: 8),
              _QuestProofMediaStrip(
                proofMedia: card.proofMedia,
                apiBaseUrl: apiBaseUrl,
                authToken: authToken,
              ),
            ],
            const SizedBox(height: 10),
            _PixelMeterBar(
              value: card.progress,
              fillColor: status.$2,
              label: strings.tr(
                zh: '${(card.progress * 100).round()}% 已充電',
                en: '${(card.progress * 100).round()}% charged',
              ),
            ),
            const SizedBox(height: 10),
            if (canSubmitProof)
              PixelButton(
                label: card.proofState == _HabitProofState.missed
                    ? strings.tr(zh: '補交完成證明', en: 'Submit Catch-up Proof')
                    : strings.tr(zh: '提交完成證明', en: 'Submit Proof'),
                tone: PixelTone.green,
                onPressed: onSubmitProof,
              ),
            if (isMaster && card.proofState == _HabitProofState.review)
              Row(
                children: [
                  Expanded(
                    child: PixelButton(
                      label: strings.tr(zh: '退回', en: 'Return'),
                      tone: PixelTone.ruby,
                      onPressed: onReject,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PixelButton(
                      label: strings.tr(zh: '核准', en: 'Approve'),
                      tone: PixelTone.green,
                      onPressed: onApprove,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HabitProgressBoard extends StatelessWidget {
  const _HabitProgressBoard({required this.focusCard});

  final _HabitChallengeCardData? focusCard;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final card = focusCard;
    Color tileColor(_HabitProofState state) => switch (state) {
      _HabitProofState.done => AppColors.stampGreen,
      _HabitProofState.review => const Color(0xFFB26A00),
      _HabitProofState.pending => AppColors.apSapphire,
      _HabitProofState.missed => AppColors.hpRuby,
    };
    final days = card == null
        ? const <_HabitProofState>[]
        : _habitProgressTiles(card);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.tr(
            zh: card == null
                ? '先建立或領取一個習慣挑戰，這裡就會開始顯示最近兩週的打卡亮燈。'
                : '聚焦「${card.title}」最近兩週的打卡亮燈。通過審核後，格子會正式亮起來。',
            en: card == null
                ? 'Create or receive a habit challenge and this wall will start filling the last two weeks of charge.'
                : 'Focused on "${card.title}" for the last two weeks of charge. Tiles lock in once proof is approved.',
          ),
          style: const TextStyle(
            color: AppColors.inkBrown,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        if (card != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatGemChip(
                icon: const _PixelLabelGlyph(glyph: 'STK'),
                label: strings.tr(
                  zh: '連續 ${card.streak} 天',
                  en: 'Streak ${card.streak}d',
                ),
                color: const Color(0xFF7C5FB3),
              ),
              _StatGemChip(
                icon: const _PixelLabelGlyph(glyph: 'BST'),
                label: strings.tr(
                  zh: '最佳 ${card.bestStreak} 天',
                  en: 'Best ${card.bestStreak}d',
                ),
                color: AppColors.apSapphire,
              ),
              _StatGemChip(
                icon: const _PixelLabelGlyph(glyph: 'CMP'),
                label: strings.tr(
                  zh: '累積 ${card.completionsCount} 次',
                  en: '${card.completionsCount} Total',
                ),
                color: AppColors.stampGreen,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final tile = math.min(34.0, (constraints.maxWidth - 18) / 7);
            return Wrap(
              spacing: 3,
              runSpacing: 3,
              children: days
                  .map(
                    (state) => PixelPanel(
                      tone: PixelTone.parchment,
                      padding: EdgeInsets.zero,
                      cut: 8,
                      shadowDepth: 1.5,
                      borderWidth: 2,
                      showShadow: false,
                      faceColor: tileColor(state).withValues(alpha: 0.88),
                      edgeColor: const Color(0xFF3D261B),
                      child: SizedBox(width: tile, height: tile),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _PixelMeterBar extends StatelessWidget {
  const _PixelMeterBar({
    required this.value,
    required this.fillColor,
    required this.label,
  });

  final double value;
  final Color fillColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillWidth = width * clamped;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelPanel(
              tone: PixelTone.parchment,
              padding: EdgeInsets.zero,
              cut: 10,
              shadowDepth: 2,
              borderWidth: 2,
              showShadow: false,
              faceColor: const Color(0xFFD8C7A8),
              edgeColor: const Color(0xFF3D261B),
              child: Stack(
                children: [
                  SizedBox(height: 14, width: width),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: PixelPanel(
                      tone: PixelTone.parchment,
                      padding: EdgeInsets.zero,
                      cut: 8,
                      shadowDepth: 0,
                      borderWidth: 0,
                      showShadow: false,
                      faceColor: fillColor.withValues(alpha: 0.9),
                      edgeColor: fillColor.withValues(alpha: 0.9),
                      child: SizedBox(width: fillWidth, height: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.inkBrown,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}
