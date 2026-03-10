part of '../game_shell_page.dart';

extension _GameShellActionsCommon on _GameShellPageState {
  void _showScrollNotice(String message) {
    if (!mounted) {
      return;
    }
    _scrollNoticeTimer?.cancel();
    _applyState(() {
      _scrollNoticeText = message;
    });
    _scrollNoticeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      _applyState(() {
        _scrollNoticeText = null;
      });
    });
  }

  void _handleGuildInviteScroll(SocialSnapshot snapshot) {
    final pendingIds = snapshot.pendingInvites
        .map((invite) => invite.id)
        .toSet();
    if (!_socialSnapshotBootstrapped) {
      _knownPendingInviteIds
        ..clear()
        ..addAll(pendingIds);
      _socialSnapshotBootstrapped = true;
      if (_activeGuildInvite == null && snapshot.pendingInvites.isNotEmpty) {
        _showSummonScroll(snapshot.pendingInvites.first);
      }
    } else {
      final newcomers = snapshot.pendingInvites
          .where((invite) => !_knownPendingInviteIds.contains(invite.id))
          .toList(growable: false);
      if (newcomers.isNotEmpty) {
        _showSummonScroll(newcomers.first);
      }
      _knownPendingInviteIds
        ..clear()
        ..addAll(pendingIds);
    }

    final active = _activeGuildInvite;
    if (active != null && !pendingIds.contains(active.id)) {
      _applyState(() {
        _activeGuildInvite = null;
      });
    }
  }

  void _showSummonScroll(GuildInviteInfo invite) {
    if (!mounted) {
      return;
    }
    _applyState(() {
      _activeGuildInvite = invite;
    });
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    String? successMessage,
    bool rethrowOnError = false,
  }) async {
    final strings = ref.read(appStringsProvider);
    try {
      await action();
      if (!mounted || successMessage == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (error) {
      await _handleSessionExpiryIfNeeded(ref, error);
      if (!mounted) {
        if (rethrowOnError) {
          rethrow;
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyShellErrorMessage(
              strings: strings,
              error: error,
              prefix: strings.tr(zh: '操作失敗。', en: 'Action failed.'),
            ),
          ),
          backgroundColor: AppColors.hpRuby,
        ),
      );
      if (rethrowOnError) {
        rethrow;
      }
    }
  }

  Future<void> _refreshChildData() async {
    await _runAction(
      action: () async {
        await ref.read(questControllerProvider.notifier).refresh();
        await ref.read(progressionControllerProvider.notifier).refresh();
        await ref.read(hunterDirectoryControllerProvider.notifier).refresh();
      },
    );
  }
}

bool _isSessionExpiryApiError(Object error) {
  if (error is! ApiException) {
    return false;
  }
  if (error.statusCode != 401 && error.statusCode != 403) {
    return false;
  }
  final message = error.message.toLowerCase();
  return message.contains('invalid or expired token') ||
      message.contains('token expired') ||
      message.contains('authentication required') ||
      message.contains('session missing');
}

Future<void> _handleSessionExpiryIfNeeded(WidgetRef ref, Object error) async {
  if (!_isSessionExpiryApiError(error)) {
    return;
  }
  await ref.read(authControllerProvider.notifier).logout();
}

String _friendlyShellErrorMessage({
  required AppStrings strings,
  required Object error,
  required String prefix,
}) {
  if (_isSessionExpiryApiError(error)) {
    return strings.tr(
      zh: '登入已過期，請重新登入。',
      en: 'Session expired. Please sign in again.',
    );
  }
  if (error is ApiException) {
    return '$prefix ${error.message}';
  }
  return '$prefix $error';
}
