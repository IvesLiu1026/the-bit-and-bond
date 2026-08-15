part of '../../game_shell_page.dart';

class _DirectMessageConversation extends ConsumerWidget {
  const _DirectMessageConversation({
    required this.counterpartName,
    required this.counterpartPlayerId,
    required this.security,
    required this.serverThreadMode,
    required this.selectedCounterpartId,
    required this.messages,
    required this.selfHunterId,
    required this.loading,
    required this.sending,
    required this.errorMessage,
    required this.messageController,
    required this.scrollController,
    required this.onBack,
    required this.onRetry,
    required this.onSendImage,
    required this.onSendOneTimeImage,
    required this.sendingImage,
    required this.sendingOneTimeImage,
    required this.mediaStatusMessage,
    required this.mediaStatusTone,
    required this.oneTimeSendEnabled,
    required this.viewedOneTimeDeliveryIds,
    required this.openingOneTimeDeliveryIds,
    required this.openableOneTimeDeliveryIds,
    required this.onOpenOneTimePhoto,
    required this.onSend,
  });

  final String? counterpartName;
  final String? counterpartPlayerId;
  final DmThreadSecuritySnapshot? security;
  final String? serverThreadMode;
  final String? selectedCounterpartId;
  final List<DirectMessage> messages;
  final String? selfHunterId;
  final bool loading;
  final bool sending;
  final String? errorMessage;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final VoidCallback onBack;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSendImage;
  final Future<void> Function() onSendOneTimeImage;
  final bool sendingImage;
  final bool sendingOneTimeImage;
  final String? mediaStatusMessage;
  final PixelTone mediaStatusTone;
  final bool oneTimeSendEnabled;
  final Set<String> viewedOneTimeDeliveryIds;
  final Set<String> openingOneTimeDeliveryIds;
  final Set<String> openableOneTimeDeliveryIds;
  final Future<void> Function({
    required String deliveryId,
    required String senderHunterId,
  })
  onOpenOneTimePhoto;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final timelineEntries = _buildDirectMessageTimeline(messages, strings);
    final securityStatus = _resolveDmSecurityStatus(
      strings: strings,
      security: security,
      serverMode: serverThreadMode,
    );
    final headerSubtitle =
        counterpartPlayerId != null && counterpartPlayerId!.trim().isNotEmpty
        ? '${counterpartPlayerId!.toUpperCase()} · ${securityStatus.label}'
        : securityStatus.label;
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: const EdgeInsets.all(10),
      cut: 12,
      shadowDepth: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelPanel(
            tone: PixelTone.parchment,
            showShadow: false,
            faceColor: Colors.white.withValues(alpha: 0.18),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 86,
                  child: PixelButton(
                    label: strings.tr(zh: '收件匣', en: 'Inbox'),
                    onPressed: onBack,
                    compact: true,
                    tone: PixelTone.slate,
                    leading: const Text(
                      '<',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _DirectMessageAvatar(
                  label: counterpartName ?? strings.tr(zh: '好友', en: 'Friend'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        counterpartName == null
                            ? strings.tr(zh: '選一位好友', en: 'Pick a Friend')
                            : counterpartName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkBrown,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        headerSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.inkBrown.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (errorMessage != null) ...[
            PixelPanel(
              tone: PixelTone.ruby,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              cut: 12,
              shadowDepth: 2,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      errorMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFF3F0),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 78,
                    child: PixelButton(
                      label: strings.photoDumpRefresh,
                      compact: true,
                      tone: PixelTone.slate,
                      onPressed: () => unawaited(onRetry()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: PixelPanel(
              tone: PixelTone.parchment,
              showShadow: false,
              faceColor: const Color(0xFFF7EED8),
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : selectedCounterpartId == null
                  ? Center(
                      child: Text(
                        strings.tr(
                          zh: '回到收件匣選一位好友，就能打開聊天室。',
                          en: 'Head back to your inbox and choose a friend to open the chat.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.inkBrown,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    )
                  : messages.isEmpty
                  ? Center(
                      child: Text(
                        strings.tr(
                          zh: '這段對話還沒有訊息。先發第一句吧。',
                          en: 'This conversation is empty. Send the first line.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.inkBrown,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      scrollCacheExtent: 640,
                      itemCount: timelineEntries.length,
                      itemBuilder: (context, index) {
                        final entry = timelineEntries[index];
                        if (entry.isDayDivider) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
                            child: Center(
                              child: PixelTag(
                                label: entry.dayLabel!,
                                tone: PixelTone.slate,
                                compact: true,
                              ),
                            ),
                          );
                        }

                        final message = entry.message!;
                        final mine = message.senderHunterId == selfHunterId;
                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 328,
                                ),
                                child: PixelPanel(
                                  tone: mine
                                      ? PixelTone.blue
                                      : PixelTone.parchment,
                                  padding: const EdgeInsets.all(10),
                                  cut: 10,
                                  shadowDepth: 2,
                                  faceColor: mine
                                      ? null
                                      : Colors.white.withValues(alpha: 0.45),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message.senderName,
                                        style: TextStyle(
                                          color: mine
                                              ? const Color(0xFF1F2740)
                                              : AppColors.inkBrown,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildMessageBody(
                                        context: context,
                                        ref: ref,
                                        strings: strings,
                                        message: message,
                                        mine: mine,
                                        viewedOneTimeDeliveryIds:
                                            viewedOneTimeDeliveryIds,
                                        openingOneTimeDeliveryIds:
                                            openingOneTimeDeliveryIds,
                                        openableOneTimeDeliveryIds:
                                            openableOneTimeDeliveryIds,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatDateTime(message.sentAt),
                                        style: TextStyle(
                                          color:
                                              (mine
                                                      ? const Color(0xFF1F2740)
                                                      : AppColors.inkBrown)
                                                  .withValues(alpha: 0.62),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelTag(
                label: securityStatus.label,
                tone: securityStatus.tone,
                compact: true,
              ),
              SizedBox(
                width: 84,
                child: PixelButton(
                  label: sendingImage
                      ? strings.dmUploadingShort
                      : strings.dmSendImage,
                  compact: true,
                  tone: PixelTone.blue,
                  onPressed:
                      selectedCounterpartId == null ||
                          sending ||
                          sendingImage ||
                          sendingOneTimeImage
                      ? null
                      : () => unawaited(onSendImage()),
                ),
              ),
              SizedBox(
                width: 106,
                child: PixelButton(
                  label: sendingOneTimeImage
                      ? strings.dmSendingShort
                      : strings.dmSendOneTimeImage,
                  compact: true,
                  tone: PixelTone.plum,
                  onPressed:
                      selectedCounterpartId == null ||
                          sending ||
                          sendingImage ||
                          sendingOneTimeImage ||
                          !oneTimeSendEnabled
                      ? null
                      : () => unawaited(onSendOneTimeImage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            securityStatus.subtitle,
            style: PixelTypography.style(
              color: AppColors.inkBrown.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              height: 1.2,
            ),
          ),
          if (mediaStatusMessage != null) ...[
            const SizedBox(height: 8),
            PixelPanel(
              tone: mediaStatusTone,
              showShadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              cut: 10,
              borderWidth: 2,
              child: Text(
                mediaStatusMessage!,
                style: PixelTypography.style(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PixelTextInput(
                  controller: messageController,
                  enabled: selectedCounterpartId != null && !sending,
                  minLines: 1,
                  maxLines: 3,
                  label: strings.tr(zh: '訊息', en: 'Message'),
                  hintText: strings.tr(
                    zh: '打一段今天想說的話...',
                    en: 'Write a message...',
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: PixelButton(
                  label: sending
                      ? strings.dmSendingShort
                      : strings.dmSendMessage,
                  tone: PixelTone.green,
                  onPressed: selectedCounterpartId == null || sending
                      ? null
                      : onSend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBody({
    required BuildContext context,
    required WidgetRef ref,
    required AppStrings strings,
    required DirectMessage message,
    required bool mine,
    required Set<String> viewedOneTimeDeliveryIds,
    required Set<String> openingOneTimeDeliveryIds,
    required Set<String> openableOneTimeDeliveryIds,
  }) {
    final textColor = mine ? const Color(0xFF1F2740) : AppColors.inkBrown;
    if (message.decryptionFailed) {
      return Text(
        strings.encryptedMessageUnavailable,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      );
    }

    final imageContentPath = _tryParseDmImageContentPath(message.content);
    if (imageContentPath != null) {
      final api = ref.watch(apiClientProvider);
      final imageUrl = api.resolveMediaUrl(imageContentPath);
      final headers = api.mediaHeaders();
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 180,
          child: Image.network(
            imageUrl,
            headers: headers,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Text(
              strings.dmImageOpenFailed,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ),
      );
    }

    final onceDeliveryId = _tryParseDmOnceDeliveryId(message.content);
    if (onceDeliveryId != null) {
      final alreadyViewed =
          viewedOneTimeDeliveryIds.contains(onceDeliveryId) ||
          (!mine && !openableOneTimeDeliveryIds.contains(onceDeliveryId));
      final opening = openingOneTimeDeliveryIds.contains(onceDeliveryId);
      return PixelPanel(
        tone: mine ? PixelTone.slate : PixelTone.parchment,
        showShadow: false,
        padding: const EdgeInsets.all(8),
        cut: 8,
        faceColor: mine
            ? const Color(0xFF6B7EA8).withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.52),
        child: Row(
          children: [
            Expanded(
              child: Text(
                strings.dmOneTimeImagePreview,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
              ),
            ),
            if (!mine && alreadyViewed)
              SizedBox(
                width: 88,
                child: PixelTag(
                  label: strings.dmViewed,
                  tone: PixelTone.slate,
                  compact: true,
                ),
              ),
            if (!mine && !alreadyViewed)
              SizedBox(
                width: 88,
                child: PixelButton(
                  label: opening
                      ? strings.dmOpeningShort
                      : strings.photoDumpOpenOnce,
                  compact: true,
                  tone: PixelTone.gold,
                  onPressed: opening
                      ? null
                      : () => unawaited(
                          onOpenOneTimePhoto(
                            deliveryId: onceDeliveryId,
                            senderHunterId: message.senderHunterId,
                          ),
                        ),
                ),
              ),
          ],
        ),
      );
    }

    return Text(
      message.content,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
    );
  }
}
