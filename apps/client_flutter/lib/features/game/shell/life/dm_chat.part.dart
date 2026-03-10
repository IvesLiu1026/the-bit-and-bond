part of '../../game_shell_page.dart';

@immutable
class _DirectMessageConversationSnapshot {
  const _DirectMessageConversationSnapshot({
    required this.selectedCounterpartId,
    required this.messages,
    required this.loading,
    required this.refreshing,
    required this.sending,
    required this.errorMessage,
    required this.security,
    required this.thread,
  });

  factory _DirectMessageConversationSnapshot.fromState(
    DirectMessagesState state,
    String counterpartId,
  ) {
    return _DirectMessageConversationSnapshot(
      selectedCounterpartId: state.selectedCounterpartId,
      messages: state.messages,
      loading: state.loading,
      refreshing: state.refreshing,
      sending: state.sending,
      errorMessage: state.errorMessage,
      security: state.threadSecurityByCounterpart[counterpartId],
      thread: _findDirectMessageThread(state.threads, counterpartId),
    );
  }

  final String? selectedCounterpartId;
  final List<DirectMessage> messages;
  final bool loading;
  final bool refreshing;
  final bool sending;
  final String? errorMessage;
  final DmThreadSecuritySnapshot? security;
  final DirectMessageThread? thread;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _DirectMessageConversationSnapshot &&
            selectedCounterpartId == other.selectedCounterpartId &&
            loading == other.loading &&
            refreshing == other.refreshing &&
            sending == other.sending &&
            errorMessage == other.errorMessage &&
            identical(messages, other.messages) &&
            identical(security, other.security) &&
            identical(thread, other.thread);
  }

  @override
  int get hashCode => Object.hash(
    selectedCounterpartId,
    loading,
    refreshing,
    sending,
    errorMessage,
    identityHashCode(messages),
    identityHashCode(security),
    identityHashCode(thread),
  );
}

CupertinoPageRoute<void> _buildDirectMessageConversationRoute({
  required String counterpartId,
  required String counterpartName,
  required String counterpartPlayerId,
}) {
  return CupertinoPageRoute<void>(
    builder: (context) {
      return _DirectMessageConversationPage(
        counterpartId: counterpartId,
        counterpartName: counterpartName,
        counterpartPlayerId: counterpartPlayerId,
      );
    },
  );
}

class _DirectMessageConversationPage extends ConsumerStatefulWidget {
  const _DirectMessageConversationPage({
    required this.counterpartId,
    required this.counterpartName,
    required this.counterpartPlayerId,
  });

  final String counterpartId;
  final String counterpartName;
  final String counterpartPlayerId;

  @override
  ConsumerState<_DirectMessageConversationPage> createState() =>
      _DirectMessageConversationPageState();
}

class _DirectMessageConversationPageState
    extends ConsumerState<_DirectMessageConversationPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _viewedOneTimeDeliveryIds = <String>{};
  final Set<String> _openingOneTimeDeliveryIds = <String>{};
  Set<String> _openableOneTimeDeliveryIds = const <String>{};
  bool _sendingImage = false;
  bool _sendingOneTimeImage = false;
  String? _mediaStatusMessage;
  PixelTone _mediaStatusTone = PixelTone.slate;
  Timer? _mediaStatusTimer;
  ProviderSubscription<int>? _messageCountSubscription;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref
          .read(directMessagesControllerProvider.notifier)
          .selectCounterpart(widget.counterpartId);
      await _refreshOpenableOneTimeDeliveries();
      if (!mounted) {
        return;
      }
    });
    _messageCountSubscription = ref.listenManual<int>(
      directMessagesControllerProvider.select((state) => state.messages.length),
      (previous, next) {
        if (next <= (previous ?? 0)) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) {
            return;
          }
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _mediaStatusTimer?.cancel();
    _mediaStatusTimer = null;
    _messageCountSubscription?.close();
    _messageCountSubscription = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setMediaStatus(
    String message, {
    PixelTone tone = PixelTone.slate,
    Duration? autoClear = const Duration(seconds: 3),
  }) {
    _mediaStatusTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _mediaStatusMessage = message;
      _mediaStatusTone = tone;
    });
    if (autoClear == null) {
      return;
    }
    _mediaStatusTimer = Timer(autoClear, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaStatusMessage = null;
        _mediaStatusTone = PixelTone.slate;
      });
    });
  }

  Future<void> _refreshOpenableOneTimeDeliveries() async {
    try {
      final inbox = await ref.read(apiClientProvider).listOnceInbox(limit: 120);
      final next = inbox.map((item) => item.id).toSet();
      if (!mounted) {
        return;
      }
      setState(() {
        _openableOneTimeDeliveryIds = next;
      });
    } catch (_) {
      // Keep the current cache if refresh fails.
    }
  }

  bool _isConsumedOrExpiredOnceError(Object error) {
    if (error is! ApiException) {
      return false;
    }
    final message = error.message.toLowerCase();
    if (error.statusCode == 409 && message.contains('already been opened')) {
      return true;
    }
    if (error.statusCode == 400 && message.contains('expired')) {
      return true;
    }
    return false;
  }

  Future<void> _openOneTimePhoto({
    required String deliveryId,
    required String senderHunterId,
  }) async {
    if (_viewedOneTimeDeliveryIds.contains(deliveryId) ||
        _openingOneTimeDeliveryIds.contains(deliveryId)) {
      return;
    }
    setState(() {
      _openingOneTimeDeliveryIds.add(deliveryId);
    });

    final strings = ref.read(appStringsProvider);
    final session = ref.read(authSessionProvider);
    if (session == null || senderHunterId == session.hunterId) {
      if (mounted) {
        setState(() {
          _openingOneTimeDeliveryIds.remove(deliveryId);
        });
      }
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      Future<(MediaOnceOpenResult, List<int>)> openAndFetch() async {
        final open = await api.openOnceMedia(deliveryId: deliveryId);
        final bytes = await api.fetchMediaBytes(contentPath: open.contentPath);
        return (open, bytes);
      }

      final payload = await openAndFetch();
      final open = payload.$1;
      final bytes = payload.$2;

      List<int> displayBytes = bytes;
      if (open.encryption.isEncrypted) {
        final e2ee = ref.read(dmE2eeServiceProvider);
        final security = await e2ee.resolveThreadSecurity(
          session: session,
          counterpartHunterId: senderHunterId,
          threadMode: DmE2eeService.encryptedMode,
          forceRefresh: true,
        );
        displayBytes = await e2ee.decryptMediaBytes(
          security: security,
          encryption: open.encryption,
          cipherBytes: bytes,
        );
      }
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) =>
            _OneTimeViewerDialog(imageBytes: displayBytes),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _viewedOneTimeDeliveryIds.add(deliveryId);
        _openableOneTimeDeliveryIds = {..._openableOneTimeDeliveryIds}
          ..remove(deliveryId);
      });
    } catch (error) {
      await _handleSessionExpiryIfNeeded(ref, error);
      if (!mounted) {
        return;
      }
      if (_isConsumedOrExpiredOnceError(error)) {
        setState(() {
          _viewedOneTimeDeliveryIds.add(deliveryId);
          _openableOneTimeDeliveryIds = {..._openableOneTimeDeliveryIds}
            ..remove(deliveryId);
        });
        _setMediaStatus(strings.dmOneTimeViewed, tone: PixelTone.slate);
        return;
      }
      _setMediaStatus(
        _friendlyShellErrorMessage(
          strings: strings,
          error: error,
          prefix: strings.dmImageOpenFailed,
        ),
        tone: PixelTone.ruby,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyShellErrorMessage(
              strings: strings,
              error: error,
              prefix: strings.dmImageOpenFailed,
            ),
          ),
          backgroundColor: AppColors.hpRuby,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingOneTimeDeliveryIds.remove(deliveryId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(
      directMessagesControllerProvider.select(
        (state) => _DirectMessageConversationSnapshot.fromState(
          state,
          widget.counterpartId,
        ),
      ),
    );
    final selfHunterId = ref.watch(
      authSessionProvider.select((s) => s?.hunterId),
    );
    final secureOneTimeReady =
        snapshot.security?.canEncryptNewMessages ?? false;

    Future<void> send() async {
      final text = _messageController.text.trim();
      if (text.isEmpty) {
        return;
      }
      _messageController.clear();
      await ref
          .read(directMessagesControllerProvider.notifier)
          .sendMessage(text);
    }

    Future<void> resend() async {
      await ref
          .read(directMessagesControllerProvider.notifier)
          .selectCounterpart(widget.counterpartId);
      await _refreshOpenableOneTimeDeliveries();
    }

    Future<MediaUpload?> pickDmUpload() async {
      final strings = ref.read(appStringsProvider);
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(strings.photoDumpCamera),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                title: Text(strings.photoDumpGallery),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) {
        return null;
      }
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) {
        return null;
      }
      final bytes = await picked.readAsBytes();
      return MediaUpload(
        filename: picked.name.isEmpty ? 'photo.jpg' : picked.name,
        bytes: bytes,
      );
    }

    Future<void> sendRegularImage() async {
      if (_sendingImage || _sendingOneTimeImage) {
        return;
      }
      final strings = ref.read(appStringsProvider);
      setState(() {
        _sendingImage = true;
      });
      _setMediaStatus(
        strings.dmImageUploading,
        tone: PixelTone.blue,
        autoClear: null,
      );
      try {
        await ref.read(apiClientProvider).ensureAuthorizedSession();
        final upload = await pickDmUpload();
        if (upload == null) {
          if (!context.mounted) {
            return;
          }
          _setMediaStatus(strings.dmImagePickCanceled, tone: PixelTone.slate);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(strings.dmImagePickCanceled)));
          return;
        }
        final asset = await ref
            .read(apiClientProvider)
            .uploadVaultMedia(upload: upload);
        await ref
            .read(directMessagesControllerProvider.notifier)
            .sendMessage(_buildDmImageMarker(asset.contentPath));
        if (!context.mounted) {
          return;
        }
        _setMediaStatus(strings.dmImageSent, tone: PixelTone.green);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.dmImageSent)));
      } catch (error) {
        await _handleSessionExpiryIfNeeded(ref, error);
        if (!context.mounted) {
          return;
        }
        _setMediaStatus(
          _friendlyShellErrorMessage(
            strings: strings,
            error: error,
            prefix: strings.dmImageSendFailed,
          ),
          tone: PixelTone.ruby,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyShellErrorMessage(
                strings: strings,
                error: error,
                prefix: strings.dmImageSendFailed,
              ),
            ),
            backgroundColor: AppColors.hpRuby,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _sendingImage = false;
          });
        }
      }
    }

    Future<void> sendOneTimeImage() async {
      if (_sendingImage || _sendingOneTimeImage) {
        return;
      }
      final strings = ref.read(appStringsProvider);
      if (!secureOneTimeReady) {
        _setMediaStatus(strings.dmOneTimeRequiresSecure, tone: PixelTone.ruby);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.dmOneTimeRequiresSecure)),
        );
        return;
      }
      setState(() {
        _sendingOneTimeImage = true;
      });
      _setMediaStatus(
        strings.dmOneTimeImageUploading,
        tone: PixelTone.plum,
        autoClear: null,
      );
      try {
        await ref.read(apiClientProvider).ensureAuthorizedSession();
        final upload = await pickDmUpload();
        if (upload == null) {
          if (!context.mounted) {
            return;
          }
          _setMediaStatus(strings.dmImagePickCanceled, tone: PixelTone.slate);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(strings.dmImagePickCanceled)));
          return;
        }
        final session = ref.read(authSessionProvider);
        if (session == null) {
          throw StateError(strings.photoDumpAuthRequired);
        }
        if (widget.counterpartPlayerId.trim().isEmpty) {
          throw StateError(strings.photoDumpNeedRecipient);
        }

        final e2ee = ref.read(dmE2eeServiceProvider);
        final security = await e2ee.resolveThreadSecurity(
          session: session,
          counterpartHunterId: widget.counterpartId,
          threadMode: DmE2eeService.encryptedMode,
          forceRefresh: true,
        );
        if (!security.canEncryptNewMessages) {
          throw StateError(strings.dmOneTimeRequiresSecure);
        }
        final encrypted = await e2ee.encryptMediaBytes(
          security: security,
          plaintextBytes: upload.bytes,
        );
        final delivery = await ref
            .read(apiClientProvider)
            .sendOnceMedia(
              recipientPlayerId: widget.counterpartPlayerId,
              upload: MediaUpload(
                filename: upload.filename,
                bytes: encrypted.cipherBytes,
                mimeType: upload.mimeType,
              ),
              encryption: encrypted.encryption,
            );
        await ref
            .read(directMessagesControllerProvider.notifier)
            .sendMessage(_buildDmOnceMarker(delivery.id));
        if (!context.mounted) {
          return;
        }
        _setMediaStatus(strings.dmOneTimeImageSent, tone: PixelTone.green);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.dmOneTimeImageSent)));
      } catch (error) {
        await _handleSessionExpiryIfNeeded(ref, error);
        if (!context.mounted) {
          return;
        }
        _setMediaStatus(
          _friendlyShellErrorMessage(
            strings: strings,
            error: error,
            prefix: strings.dmImageSendFailed,
          ),
          tone: PixelTone.ruby,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyShellErrorMessage(
                strings: strings,
                error: error,
                prefix: strings.dmImageSendFailed,
              ),
            ),
            backgroundColor: AppColors.hpRuby,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _sendingOneTimeImage = false;
          });
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF20130F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: _DirectMessageConversation(
            counterpartName: widget.counterpartName,
            counterpartPlayerId: widget.counterpartPlayerId,
            security: snapshot.security,
            serverThreadMode: snapshot.thread?.encryptionMode,
            selectedCounterpartId: snapshot.selectedCounterpartId,
            messages: snapshot.messages,
            selfHunterId: selfHunterId,
            loading: snapshot.loading || snapshot.refreshing,
            sending: snapshot.sending,
            errorMessage: snapshot.errorMessage,
            messageController: _messageController,
            scrollController: _scrollController,
            onBack: () => Navigator.of(context).pop(),
            onRetry: resend,
            onSendImage: sendRegularImage,
            onSendOneTimeImage: sendOneTimeImage,
            sendingImage: _sendingImage,
            sendingOneTimeImage: _sendingOneTimeImage,
            mediaStatusMessage: _mediaStatusMessage,
            mediaStatusTone: _mediaStatusTone,
            oneTimeSendEnabled: secureOneTimeReady,
            viewedOneTimeDeliveryIds: _viewedOneTimeDeliveryIds,
            openingOneTimeDeliveryIds: _openingOneTimeDeliveryIds,
            openableOneTimeDeliveryIds: _openableOneTimeDeliveryIds,
            onOpenOneTimePhoto: _openOneTimePhoto,
            onSend: send,
          ),
        ),
      ),
    );
  }
}
