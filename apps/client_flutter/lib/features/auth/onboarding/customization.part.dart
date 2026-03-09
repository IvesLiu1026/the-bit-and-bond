part of '../immersive_onboarding_page.dart';

class _AvatarPreviewCard extends StatelessWidget {
  const _AvatarPreviewCard({
    required this.hairStyle,
    required this.clothTone,
    this.footerText,
    this.dense = false,
  });

  final _AvatarHairStyle hairStyle;
  final _AvatarClothTone clothTone;
  final String? footerText;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final appearance = AvatarAppearance(
      hairStyle: hairStyle,
      clothTone: clothTone,
    );
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: EdgeInsets.all(dense ? 12 : 16),
      cut: dense ? 10 : 14,
      shadowDepth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.tr(zh: 'Bibon 鏡面', en: 'Bibon Mirror'),
            style: TextStyle(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w900,
              fontSize: dense ? 18 : 22,
            ),
          ),
          SizedBox(height: dense ? 8 : 12),
          AspectRatio(
            aspectRatio: dense ? 1.45 : 1,
            child: PixelPanel(
              tone: PixelTone.wood,
              padding: const EdgeInsets.all(12),
              cut: 12,
              shadowDepth: 0,
              showShadow: false,
              faceColor: const Color(0xFF8B5A3C),
              child: Center(child: PixelAvatarPreview(appearance: appearance)),
            ),
          ),
          SizedBox(height: dense ? 8 : 12),
          Text(
            appearance.localizedSummaryLabel(strings),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navyBlue,
              fontWeight: FontWeight.w900,
              fontSize: dense ? 13 : 15,
            ),
          ),
          if (footerText != null) ...[
            SizedBox(height: dense ? 6 : 8),
            Text(
              footerText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inkBrown.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
                fontSize: dense ? 11 : 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionPanel<T> extends StatelessWidget {
  const _SelectionPanel({
    required this.badge,
    required this.title,
    required this.items,
    required this.selected,
    required this.itemLabel,
    required this.itemBuilder,
    required this.onSelected,
    this.dense = false,
  });

  final String badge;
  final String title;
  final List<T> items;
  final T selected;
  final String Function(T item) itemLabel;
  final Widget Function(T item, bool active) itemBuilder;
  final ValueChanged<T> onSelected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: EdgeInsets.all(dense ? 12 : 16),
      cut: dense ? 10 : 12,
      shadowDepth: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PixelTag(label: badge, tone: PixelTone.wood, compact: dense),
              SizedBox(width: dense ? 8 : 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.inkBrown,
                    fontWeight: FontWeight.w900,
                    fontSize: dense ? 18 : 22,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 10 : 14),
          Wrap(
            spacing: dense ? 8 : 10,
            runSpacing: dense ? 8 : 10,
            children: [
              for (final item in items)
                Semantics(
                  button: true,
                  label: itemLabel(item),
                  child: GestureDetector(
                    onTap: () => onSelected(item),
                    child: itemBuilder(item, item == selected),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HairStyleChip extends StatelessWidget {
  const _HairStyleChip({
    required this.style,
    required this.active,
    this.compact = false,
  });

  final _AvatarHairStyle style;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: active ? 1 : 0.98,
      child: SizedBox(
        width: compact ? 100 : 152,
        child: PixelPanel(
          tone: active ? PixelTone.blue : PixelTone.parchment,
          faceColor: active ? const Color(0xFFEAD9B2) : const Color(0xFFF8F0E0),
          edgeColor: active ? AppColors.navyBlue : AppColors.woodFrame,
          shadowColor: active ? const Color(0x553862AA) : null,
          padding: EdgeInsets.all(compact ? 8 : 10),
          shadowDepth: active ? 4 : 2,
          child: Column(
            children: [
              SizedBox(
                width: compact ? 38 : 54,
                height: compact ? 38 : 54,
                child: PixelAvatarPreview(
                  appearance: AvatarAppearance(
                    hairStyle: style,
                    clothTone: AvatarClothTone.ember,
                  ),
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                style.localizedLabel(strings),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 11.5 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorToneChip extends StatelessWidget {
  const _ColorToneChip({
    required this.tone,
    required this.active,
    this.compact = false,
  });

  final _AvatarClothTone tone;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: active ? 1 : 0.98,
      child: SizedBox(
        width: compact ? 92 : 132,
        child: PixelPanel(
          tone: active ? PixelTone.blue : PixelTone.parchment,
          faceColor: active ? const Color(0xFFEAD9B2) : const Color(0xFFF8F0E0),
          edgeColor: active ? AppColors.navyBlue : AppColors.woodFrame,
          padding: EdgeInsets.all(compact ? 8 : 10),
          shadowDepth: active ? 4 : 2,
          child: Column(
            children: [
              PixelPanel(
                tone: PixelTone.wood,
                padding: EdgeInsets.all(compact ? 3 : 4),
                cut: 8,
                shadowDepth: 0,
                showShadow: false,
                faceColor: tone.color,
                child: SizedBox(
                  width: compact ? 28 : 46,
                  height: compact ? 28 : 46,
                ),
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                tone.localizedLabel(strings),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 11.5 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
