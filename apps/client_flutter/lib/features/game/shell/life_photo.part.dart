part of '../game_shell_page.dart';

class _PhotoDumpCardData {
  const _PhotoDumpCardData({
    required this.title,
    required this.caption,
    required this.stamp,
    required this.palette,
  });

  final String title;
  final String caption;
  final String stamp;
  final List<Color> palette;
}

class _PhotoDumpPanel extends StatelessWidget {
  const _PhotoDumpPanel();

  static const List<_PhotoDumpCardData> _cards = <_PhotoDumpCardData>[
    _PhotoDumpCardData(
      title: 'After School',
      caption: 'Tiny wins from today.',
      stamp: 'FAM',
      palette: <Color>[Color(0xFFF2D6A2), Color(0xFFB67C57), Color(0xFF6C8DAA)],
    ),
    _PhotoDumpCardData(
      title: 'Night Walk',
      caption: 'Charged the streak with Avery.',
      stamp: 'FRD',
      palette: <Color>[Color(0xFFCEE5D0), Color(0xFF79A28B), Color(0xFF385A59)],
    ),
    _PhotoDumpCardData(
      title: 'Desk Reset',
      caption: 'Room tidy proof, then reward coins.',
      stamp: 'SELF',
      palette: <Color>[Color(0xFFF8E4E2), Color(0xFFD18B81), Color(0xFF6E4A47)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.photoDump,
          style: const TextStyle(
            color: AppColors.inkBrown,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          strings.tr(
            zh: '把今天的照片丟進自己的像素相框裡。之後這裡會接上拍照、儲存與分享範圍設定。',
            en: 'Drop today into your own pixel frames. Camera, storage, and share scopes land here next.',
          ),
          style: TextStyle(
            color: AppColors.inkBrown.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.84,
            ),
            itemCount: _cards.length,
            itemBuilder: (context, index) {
              final card = _cards[index];
              return PixelPanel(
                tone: PixelTone.parchment,
                padding: const EdgeInsets.all(10),
                cut: 12,
                shadowDepth: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _PixelLabelGlyph(glyph: card.stamp),
                        const Spacer(),
                        PixelTag(
                          label: strings.tr(zh: '樣張', en: 'Mock'),
                          tone: PixelTone.wood,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: PixelPanel(
                        tone: PixelTone.parchment,
                        padding: const EdgeInsets.all(8),
                        cut: 12,
                        shadowDepth: 2,
                        faceColor: const Color(0xFFEEE0C5),
                        child: Column(
                          children: [
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: card.palette,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.photo_camera_back_rounded,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    size: 34,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 18,
                              color: const Color(0xFFF9F0DD),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      card.title,
                      style: const TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.inkBrown.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
