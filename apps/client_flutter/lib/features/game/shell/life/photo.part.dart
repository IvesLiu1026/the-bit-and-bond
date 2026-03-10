part of '../../game_shell_page.dart';

enum _PhotoMode { vault, once }

class _PhotoDumpPanel extends ConsumerStatefulWidget {
  const _PhotoDumpPanel();

  @override
  ConsumerState<_PhotoDumpPanel> createState() => _PhotoDumpPanelState();
}

class _PhotoDumpPanelState extends ConsumerState<_PhotoDumpPanel> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final Map<String, String> _recipientHunterIdByPlayerId = <String, String>{};

  _PhotoMode _mode = _PhotoMode.vault;
  bool _loading = true;
  bool _working = false;
  String? _errorMessage;
  String? _statusMessage;
  PixelTone _statusTone = PixelTone.slate;
  Timer? _statusTimer;

  List<MediaAssetItem> _vaultItems = const [];
  List<MediaOnceDelivery> _onceInbox = const [];
  List<PhotoDumpExportItem> _exports = const [];
  final Set<String> _selectedVaultIds = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_refreshAll(showLoading: true));
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _statusTimer = null;
    _captionController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  void _applyPhotoState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  void _setStatus(
    String message, {
    PixelTone tone = PixelTone.slate,
    Duration? autoClear = const Duration(seconds: 3),
  }) {
    _statusTimer?.cancel();
    _applyPhotoState(() {
      _statusMessage = message;
      _statusTone = tone;
    });
    if (autoClear == null) {
      return;
    }
    _statusTimer = Timer(autoClear, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = null;
        _statusTone = PixelTone.slate;
      });
    });
  }

  Future<void> _refreshAll({required bool showLoading}) async {
    final strings = ref.read(appStringsProvider);
    if (showLoading) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait<dynamic>([
        api.listVaultMedia(limit: 80),
        api.listOnceInbox(limit: 80),
        api.listPhotoDumpExports(limit: 24),
      ]);
      if (!mounted) {
        return;
      }
      final nextVault = results[0] as List<MediaAssetItem>;
      final nextInbox = results[1] as List<MediaOnceDelivery>;
      final nextExports = results[2] as List<PhotoDumpExportItem>;

      setState(() {
        _vaultItems = nextVault;
        _onceInbox = nextInbox;
        _exports = nextExports;
        _selectedVaultIds.removeWhere(
          (id) => !nextVault.any((item) => item.id == id),
        );
        _loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      await _handleSessionExpiryIfNeeded(ref, error);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = _friendlyShellErrorMessage(
          strings: strings,
          error: error,
          prefix: strings.photoDumpLoadFailed,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.photoDump,
                style: const TextStyle(
                  color: AppColors.inkBrown,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            PixelButton(
              label: strings.photoDumpRefresh,
              tone: PixelTone.slate,
              compact: true,
              onPressed: _working
                  ? null
                  : () => _refreshAll(showLoading: false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PhotoModeSwitcher(
          mode: _mode,
          onChanged: (mode) => setState(() => _mode = mode),
        ),
        const SizedBox(height: 10),
        Text(
          _mode == _PhotoMode.vault
              ? strings.photoDumpExportHint
              : strings.photoDumpOneTimeRule,
          style: TextStyle(
            color: AppColors.inkBrown.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 8),
          PixelPanel(
            tone: _statusTone,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            cut: 10,
            shadowDepth: 2,
            showShadow: false,
            child: Text(
              _statusMessage!,
              style: PixelTypography.style(
                color: AppColors.inkBrown,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1.1,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _errorMessage != null
              ? _PhotoErrorState(message: _errorMessage!)
              : _mode == _PhotoMode.vault
              ? _buildVaultTab(strings)
              : _buildOneTimeTab(strings),
        ),
      ],
    );
  }
}
