part of '../game_shell_page.dart';

class _HabitProofDialog extends StatefulWidget {
  const _HabitProofDialog({
    required this.card,
    required this.imagePicker,
    required this.apiBaseUrl,
    required this.authToken,
    required this.onSubmitHabit,
  });

  final _HabitChallengeCardData card;
  final ImagePicker imagePicker;
  final String apiBaseUrl;
  final String? authToken;
  final Future<void> Function(
    String questId, {
    String? proofNote,
    QuestProofUpload? proofMedia,
  })
  onSubmitHabit;

  @override
  State<_HabitProofDialog> createState() => _HabitProofDialogState();
}

class _HabitProofDialogState extends State<_HabitProofDialog> {
  late final TextEditingController _controller;
  QuestProofUpload? _selectedUpload;
  Uint8List? _selectedPreviewBytes;
  bool _sending = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.card.proofNote ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_picking || _sending) {
      return;
    }
    setState(() => _picking = true);
    try {
      final picked = await widget.imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 92,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedUpload = QuestProofUpload(
          filename: picked.name.isEmpty ? 'habit-proof.jpg' : picked.name,
          bytes: bytes,
        );
        _selectedPreviewBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('選圖失敗：$error'),
          backgroundColor: AppColors.hpRuby,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.onSubmitHabit(
        widget.card.questId,
        proofNote: _controller.text,
        proofMedia: _selectedUpload,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      content: PixelPanel(
        tone: PixelTone.parchment,
        cut: 14,
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.tr(zh: '提交習慣證明', en: 'Submit Proof'),
                style: const TextStyle(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.tr(
                  zh: '先附上一張今天的照片，再補一小段說明。家人或朋友核准後，就會更新 streak 與獎勵。',
                  en: 'Add a photo from today, then write a short note. Once approved, streaks and rewards update here.',
                ),
                style: TextStyle(
                  color: AppColors.inkBrown.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedPreviewBytes != null) ...[
                _HabitProofSelectedPreview(bytes: _selectedPreviewBytes!),
                const SizedBox(height: 10),
              ] else if (widget.card.proofMedia.isNotEmpty) ...[
                _QuestProofMediaStrip(
                  proofMedia: widget.card.proofMedia,
                  apiBaseUrl: widget.apiBaseUrl,
                  authToken: widget.authToken,
                  height: 92,
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: PixelButton(
                      label: _picking
                          ? strings.tr(zh: '載入中...', en: 'Picking...')
                          : strings.tr(zh: '選擇照片', en: 'Choose Photo'),
                      tone: PixelTone.blue,
                      onPressed: _picking || _sending ? null : _pickPhoto,
                    ),
                  ),
                  if (_selectedUpload != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: PixelButton(
                        label: strings.tr(zh: '移除照片', en: 'Remove'),
                        tone: PixelTone.slate,
                        onPressed: _sending
                            ? null
                            : () => setState(() {
                                _selectedUpload = null;
                                _selectedPreviewBytes = null;
                              }),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: strings.tr(
                    zh: '例如：我把今天的水壺喝完了，附上桌上的照片。',
                    en: 'Example: Finished my water bottle today and attached the desk photo.',
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF0E5CF),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PixelButton(
                      label: strings.tr(zh: '取消', en: 'Cancel'),
                      tone: PixelTone.slate,
                      onPressed: _sending
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PixelButton(
                      label: _sending
                          ? strings.tr(zh: '送審中...', en: 'Sending...')
                          : strings.tr(zh: '送審', en: 'Send'),
                      tone: PixelTone.green,
                      onPressed: _sending ? null : _submit,
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

class _HabitProofSelectedPreview extends StatelessWidget {
  const _HabitProofSelectedPreview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: const EdgeInsets.all(6),
      cut: 10,
      shadowDepth: 2,
      faceColor: const Color(0xFFF4E7CA),
      child: ClipRect(
        child: AspectRatio(
          aspectRatio: 1.5,
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _QuestProofMediaStrip extends StatelessWidget {
  const _QuestProofMediaStrip({
    required this.proofMedia,
    required this.apiBaseUrl,
    required this.authToken,
    this.height = 82,
  });

  final List<QuestProofMedia> proofMedia;
  final String apiBaseUrl;
  final String? authToken;
  final double height;

  @override
  Widget build(BuildContext context) {
    final headers = <String, String>{'ngrok-skip-browser-warning': 'true'};
    final token = authToken?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: proofMedia.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final media = proofMedia[index];
          final imageUrl = Uri.parse(
            apiBaseUrl,
          ).resolve(media.contentPath).toString();
          return PixelPanel(
            tone: PixelTone.parchment,
            padding: const EdgeInsets.all(4),
            cut: 10,
            shadowDepth: 2,
            faceColor: const Color(0xFFF4E7CA),
            child: SizedBox(
              width: height,
              height: height,
              child: Image.network(
                imageUrl,
                headers: headers,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    AppStrings.of(context).tr(zh: '讀圖失敗', en: 'No Preview'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
