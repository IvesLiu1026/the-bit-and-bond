part of '../game_shell_page.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ProviderSubscription<int>? _messageCountSubscription;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref
          .read(directMessagesControllerProvider.notifier)
          .selectCounterpart(widget.counterpartId);
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
    _messageCountSubscription?.close();
    _messageCountSubscription = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    final selfHunterId = ref.watch(authSessionProvider.select((s) => s?.hunterId));

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
            onSend: send,
          ),
        ),
      ),
    );
  }
}

class _DirectMessageConversation extends StatelessWidget {
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
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final timelineEntries = _buildDirectMessageTimeline(messages, strings);
    final securityStatus = _resolveDmSecurityStatus(
      strings: strings,
      security: security,
      serverMode: serverThreadMode,
    );
    final encryptionSubtitle = _resolveDmSecuritySubtitle(
      strings: strings,
      security: security,
      serverMode: serverThreadMode,
    );
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
            faceColor: Colors.white.withValues(alpha: 0.22),
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 102,
                    maxWidth: 118,
                  ),
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
                const SizedBox(width: 10),
                _DirectMessageAvatar(
                  label: counterpartName ?? strings.tr(zh: '好友', en: 'Friend'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        counterpartName == null
                            ? strings.tr(zh: '選一位好友', en: 'Pick a Friend')
                            : counterpartName!,
                        style: const TextStyle(
                          color: AppColors.inkBrown,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.tr(
                          zh: '私人聊天室，只有你們兩位看得到。',
                          en: 'Private thread visible only to the two of you.',
                        ),
                        style: TextStyle(
                          color: AppColors.inkBrown.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (counterpartPlayerId != null &&
                              counterpartPlayerId!.isNotEmpty)
                            PixelTag(
                              label: counterpartPlayerId!.toUpperCase(),
                              tone: PixelTone.wood,
                              compact: true,
                            ),
                          PixelTag(
                            label: strings.tr(zh: '私訊', en: 'Direct'),
                            tone: PixelTone.plum,
                            compact: true,
                          ),
                          PixelTag(
                            label: securityStatus.label,
                            tone: securityStatus.tone,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        encryptionSubtitle,
                        style: TextStyle(
                          color: AppColors.inkBrown.withValues(alpha: 0.66),
                          fontWeight: FontWeight.w700,
                          height: 1.2,
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
              padding: const EdgeInsets.all(10),
              cut: 12,
              shadowDepth: 2,
              child: Text(
                errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFFFF3F0),
                  fontWeight: FontWeight.w800,
                ),
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
                      cacheExtent: 640,
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
                                constraints: const BoxConstraints(maxWidth: 328),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                      Text(
                                        message.decryptionFailed
                                            ? strings.encryptedMessageUnavailable
                                            : message.content,
                                        style: TextStyle(
                                          color: mine
                                              ? const Color(0xFF1F2740)
                                              : AppColors.inkBrown,
                                          fontWeight: FontWeight.w700,
                                          height: 1.3,
                                        ),
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
          Align(
            alignment: Alignment.centerLeft,
            child: PixelTag(
              label: securityStatus.label,
              tone: securityStatus.tone,
              compact: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PixelPanel(
                  tone: PixelTone.parchment,
                  showShadow: false,
                  faceColor: const Color(0xFFF0E5CF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: messageController,
                    enabled: selectedCounterpartId != null && !sending,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: strings.tr(
                        zh: '打一段今天想說的話...',
                        en: 'Write a message...',
                      ),
                      hintStyle: TextStyle(
                        color: AppColors.inkBrown.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      color: AppColors.inkBrown,
                      fontWeight: FontWeight.w800,
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: PixelButton(
                  label: sending
                      ? strings.tr(zh: '送出中', en: 'Sending')
                      : strings.tr(zh: '送出', en: 'Send'),
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
}
