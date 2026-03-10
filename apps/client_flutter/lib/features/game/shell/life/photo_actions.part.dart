part of '../../game_shell_page.dart';

extension _PhotoDumpPanelActions on _PhotoDumpPanelState {
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

  Future<MediaUpload?> _pickUpload(ImageSource source) async {
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

  Future<void> _uploadToVault(ImageSource source) async {
    if (_working) {
      return;
    }
    final strings = ref.read(appStringsProvider);
    final upload = await _pickUpload(source);
    if (upload == null) {
      return;
    }
    _setStatus(
      strings.photoDumpVaultUploading,
      tone: PixelTone.blue,
      autoClear: null,
    );
    _applyPhotoState(() => _working = true);
    try {
      await ref.read(apiClientProvider).ensureAuthorizedSession();
      await ref
          .read(apiClientProvider)
          .uploadVaultMedia(upload: upload, caption: _captionController.text);
      _captionController.clear();
      if (mounted) {
        _setStatus(strings.photoDumpUploadSuccess, tone: PixelTone.green);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.photoDumpUploadSuccess)));
      }
      await _refreshAll(showLoading: false);
    } catch (error) {
      await _handleSessionExpiryIfNeeded(ref, error);
      if (mounted) {
        _setStatus(
          _friendlyShellErrorMessage(
            strings: strings,
            error: error,
            prefix: strings.photoDumpLoadFailed,
          ),
          tone: PixelTone.ruby,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyShellErrorMessage(
                strings: strings,
                error: error,
                prefix: strings.photoDumpLoadFailed,
              ),
            ),
            backgroundColor: AppColors.hpRuby,
          ),
        );
      }
    } finally {
      _applyPhotoState(() => _working = false);
    }
  }

  Future<void> _sendOneTime(ImageSource source) async {
    if (_working) {
      return;
    }
    final strings = ref.read(appStringsProvider);
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      _setStatus(strings.photoDumpNeedRecipient, tone: PixelTone.ruby);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.photoDumpNeedRecipient)));
      return;
    }
    final upload = await _pickUpload(source);
    if (upload == null) {
      return;
    }

    _setStatus(
      strings.photoDumpOneTimeSending,
      tone: PixelTone.plum,
      autoClear: null,
    );
    _applyPhotoState(() => _working = true);
    try {
      await ref.read(apiClientProvider).ensureAuthorizedSession();
      final session = ref.read(authSessionProvider);
      if (session == null) {
        throw StateError(strings.photoDumpAuthRequired);
      }
      final recipientHunterId = await _resolveRecipientHunterId(recipient);
      if (recipientHunterId == null) {
        throw StateError(strings.photoDumpNeedFriendForSecureSend);
      }

      final e2ee = ref.read(dmE2eeServiceProvider);
      final security = await e2ee.resolveThreadSecurity(
        session: session,
        counterpartHunterId: recipientHunterId,
        threadMode: DmE2eeService.encryptedMode,
        forceRefresh: true,
      );
      if (!security.canEncryptNewMessages) {
        throw StateError(strings.photoDumpE2eeUnavailable);
      }
      final encrypted = await e2ee.encryptMediaBytes(
        security: security,
        plaintextBytes: upload.bytes,
      );

      await ref
          .read(apiClientProvider)
          .sendOnceMedia(
            recipientPlayerId: recipient,
            upload: MediaUpload(
              filename: upload.filename,
              bytes: encrypted.cipherBytes,
              mimeType: upload.mimeType,
            ),
            caption: _captionController.text,
            encryption: encrypted.encryption,
          );
      _captionController.clear();
      if (mounted) {
        _setStatus(
          strings.photoDumpSendSuccessEncrypted,
          tone: PixelTone.green,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.photoDumpSendSuccessEncrypted)),
        );
      }
      await _refreshAll(showLoading: false);
    } catch (error) {
      await _handleSessionExpiryIfNeeded(ref, error);
      if (mounted) {
        _setStatus(
          _friendlyShellErrorMessage(
            strings: strings,
            error: error,
            prefix: strings.photoDumpLoadFailed,
          ),
          tone: PixelTone.ruby,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyShellErrorMessage(
                strings: strings,
                error: error,
                prefix: strings.photoDumpLoadFailed,
              ),
            ),
            backgroundColor: AppColors.hpRuby,
          ),
        );
      }
    } finally {
      _applyPhotoState(() => _working = false);
    }
  }

  Future<void> _exportSelected() async {
    if (_working) {
      return;
    }
    final strings = ref.read(appStringsProvider);
    if (_selectedVaultIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.photoDumpNoSelection)));
      return;
    }
    _applyPhotoState(() => _working = true);
    try {
      await ref
          .read(apiClientProvider)
          .createPhotoDumpExport(
            assetIds: _selectedVaultIds.toList(growable: false),
            style: 'retro',
          );
      if (mounted) {
        _setStatus(strings.photoDumpExportSelected, tone: PixelTone.green);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.photoDumpExportSelected)),
        );
      }
      _selectedVaultIds.clear();
      await _refreshAll(showLoading: false);
    } catch (error) {
      await _handleSessionExpiryIfNeeded(ref, error);
      if (mounted) {
        _setStatus(
          _friendlyShellErrorMessage(
            strings: strings,
            error: error,
            prefix: strings.photoDumpLoadFailed,
          ),
          tone: PixelTone.ruby,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyShellErrorMessage(
                strings: strings,
                error: error,
                prefix: strings.photoDumpLoadFailed,
              ),
            ),
            backgroundColor: AppColors.hpRuby,
          ),
        );
      }
    } finally {
      _applyPhotoState(() => _working = false);
    }
  }

  Future<void> _openOneTime(MediaOnceDelivery delivery) async {
    if (_working) {
      return;
    }
    final strings = ref.read(appStringsProvider);
    _applyPhotoState(() => _working = true);
    try {
      final api = ref.read(apiClientProvider);
      final open = await api.openOnceMedia(deliveryId: delivery.id);
      if (!mounted) {
        return;
      }
      final bytes = await api.fetchMediaBytes(contentPath: open.contentPath);
      List<int> displayBytes = bytes;
      if (open.encryption.isEncrypted) {
        final session = ref.read(authSessionProvider);
        if (session == null) {
          throw StateError(strings.photoDumpAuthRequired);
        }
        final e2ee = ref.read(dmE2eeServiceProvider);
        final security = await e2ee.resolveThreadSecurity(
          session: session,
          counterpartHunterId: delivery.senderHunterId,
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
      _setStatus(strings.photoDumpOpenOnce, tone: PixelTone.gold);
      await _refreshAll(showLoading: false);
    } catch (error) {
      await _handleSessionExpiryIfNeeded(ref, error);
      if (!mounted) {
        return;
      }
      if (_isConsumedOrExpiredOnceError(error)) {
        _setStatus(strings.photoDumpAlreadyViewed, tone: PixelTone.slate);
        await _refreshAll(showLoading: false);
        return;
      }
      _setStatus(
        _friendlyShellErrorMessage(
          strings: strings,
          error: error,
          prefix: strings.photoDumpOpenFailed,
        ),
        tone: PixelTone.ruby,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyShellErrorMessage(
              strings: strings,
              error: error,
              prefix: strings.photoDumpOpenFailed,
            ),
          ),
          backgroundColor: AppColors.hpRuby,
        ),
      );
    } finally {
      _applyPhotoState(() => _working = false);
    }
  }

  void _toggleVaultSelection(String id) {
    _applyPhotoState(() {
      if (_selectedVaultIds.contains(id)) {
        _selectedVaultIds.remove(id);
      } else {
        _selectedVaultIds.add(id);
      }
    });
  }

  Future<String?> _resolveRecipientHunterId(String playerId) async {
    final normalizedPlayerId = playerId.trim().toLowerCase();
    if (normalizedPlayerId.isEmpty) {
      return null;
    }
    final cached = _recipientHunterIdByPlayerId[normalizedPlayerId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final friends = await ref.read(apiClientProvider).listFriends();
    for (final friend in friends) {
      final candidate = friend.playerId.trim().toLowerCase();
      if (candidate == normalizedPlayerId) {
        _recipientHunterIdByPlayerId[normalizedPlayerId] = friend.id;
        return friend.id;
      }
    }
    return null;
  }
}
