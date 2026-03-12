part of '../../game_shell_page.dart';

class _PhotoModeSwitcher extends StatelessWidget {
  const _PhotoModeSwitcher({required this.mode, required this.onChanged});

  final _PhotoMode mode;
  final ValueChanged<_PhotoMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Row(
      children: [
        Expanded(
          child: PixelButton(
            label: strings.photoVault,
            tone: mode == _PhotoMode.vault ? PixelTone.green : PixelTone.slate,
            compact: true,
            onPressed: () => onChanged(_PhotoMode.vault),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PixelButton(
            label: strings.photoOneTime,
            tone: mode == _PhotoMode.once ? PixelTone.gold : PixelTone.slate,
            compact: true,
            onPressed: () => onChanged(_PhotoMode.once),
          ),
        ),
      ],
    );
  }
}

class _PhotoErrorState extends StatelessWidget {
  const _PhotoErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PixelPanel(
        tone: PixelTone.ruby,
        padding: const EdgeInsets.all(12),
        cut: 10,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: PixelTypography.style(
            color: AppColors.inkBrown,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _VaultMediaCard extends ConsumerWidget {
  const _VaultMediaCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MediaAssetItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final imageUrl = api.resolveMediaUrl(item.contentPath);
    final headers = api.mediaHeaders();

    return GestureDetector(
      onTap: onTap,
      child: PixelPanel(
        tone: selected ? PixelTone.gold : PixelTone.parchment,
        padding: const EdgeInsets.all(8),
        cut: 10,
        shadowDepth: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRect(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  headers: headers,
                  errorBuilder: (_, _, _) => const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFFE7D9BC)),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: AppColors.woodFrame,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.caption?.trim().isNotEmpty == true
                  ? item.caption!
                  : (item.originalFilename ?? item.id.substring(0, 8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PixelTypography.style(
                color: AppColors.inkBrown,
                fontWeight: FontWeight.w800,
                fontSize: 11.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OneTimeViewerDialog extends StatefulWidget {
  const _OneTimeViewerDialog({required this.imageBytes});

  final List<int> imageBytes;

  @override
  State<_OneTimeViewerDialog> createState() => _OneTimeViewerDialogState();
}

class _OneTimeViewerDialogState extends State<_OneTimeViewerDialog> {
  static const int _initialSeconds = 8;
  Timer? _timer;
  int _secondsLeft = _initialSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        Navigator.of(context).pop();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Dialog.fullscreen(
      key: AppTestIds.dmOneTimeViewerDialogKey,
      backgroundColor: const Color(0xFF19130E),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Center(
                child: Image.memory(
                  Uint8List.fromList(widget.imageBytes),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text(
                    strings.photoDumpOpenExpired,
                    style: PixelTypography.style(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 14,
            right: 14,
            child: Row(
              children: [
                Expanded(
                  child: PixelPanel(
                    tone: PixelTone.parchment,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    cut: 10,
                    shadowDepth: 2,
                    child: Text(
                      '${strings.photoDumpViewCountdown} $_secondsLeft',
                      style: PixelTypography.style(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PixelButton(
                  tapTargetKey: AppTestIds.dmOneTimeViewerCloseButtonKey,
                  label: strings.closeMenu,
                  tone: PixelTone.ruby,
                  compact: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
