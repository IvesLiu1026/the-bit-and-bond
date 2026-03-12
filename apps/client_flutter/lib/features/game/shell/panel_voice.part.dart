part of '../game_shell_page.dart';

class _CampfireVoicePanel extends StatefulWidget {
  const _CampfireVoicePanel({
    required this.state,
    required this.onJoin,
    required this.onLeave,
    required this.onToggleMic,
    required this.onSendMessage,
  });

  final VoiceChatState state;
  final Future<void> Function() onJoin;
  final Future<void> Function() onLeave;
  final Future<void> Function() onToggleMic;
  final Future<void> Function(String text) onSendMessage;

  @override
  State<_CampfireVoicePanel> createState() => _CampfireVoicePanelState();
}

class _CampfireVoicePanelState extends State<_CampfireVoicePanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _sending = false;
  bool _autoScrollEnabled = true;
  bool _joining = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _lastMessageCount = widget.state.messages.length;
  }

  @override
  void didUpdateWidget(covariant _CampfireVoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousCount = _lastMessageCount;
    final nextCount = widget.state.messages.length;
    _lastMessageCount = nextCount;
    if (nextCount > previousCount) {
      _scrollToBottom(animated: true);
    }
    if (_joining &&
        (widget.state.connecting ||
            widget.state.connected ||
            widget.state.errorMessage != null)) {
      _joining = false;
    }
  }

  @override
  void dispose() {
    _chatScrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollToBottom({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) {
        return;
      }
      if (!_autoScrollEnabled) {
        return;
      }
      final position = _chatScrollController.position.maxScrollExtent;
      if (animated) {
        _chatScrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _chatScrollController.jumpTo(position);
      }
    });
  }

  Future<void> _send() async {
    if (_sending || !widget.state.connected) {
      return;
    }
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
    });
    try {
      await widget.onSendMessage(text);
      _messageController.clear();
      _autoScrollEnabled = true;
      _scrollToBottom(animated: true);
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _join() async {
    if (_joining || widget.state.connected || widget.state.connecting) {
      return;
    }
    setState(() {
      _joining = true;
    });
    try {
      await widget.onJoin();
    } finally {
      if (mounted &&
          !widget.state.connecting &&
          !widget.state.connected &&
          widget.state.errorMessage == null) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final state = widget.state;
    final joining = state.connecting || _joining;
    final speakingCount = state.activeSpeakerIdentities.length;
    final media = MediaQuery.of(context);
    final narrowLayout = media.size.width < 520;
    final shortHeight = media.size.height < 520;
    final keyboardOpen = media.viewInsets.bottom > 0;
    final denseSpacing = narrowLayout || shortHeight;
    final roomLabel = () {
      final room = state.roomId;
      if (room == null || room.isEmpty) {
        return strings.tr(zh: '未加入', en: 'Not Joined');
      }
      if (room.length <= 12) {
        return room;
      }
      return '${room.substring(0, 6)}..';
    }();
    final subtitle = state.connected
        ? strings.tr(zh: '語音房已連線', en: 'Voice room connected')
        : (joining
              ? strings.tr(zh: '正在連到語音房...', en: 'Connecting to voice...')
              : strings.tr(zh: '尚未連線', en: 'Offline'));

    return _ParchmentSection(
      title: strings.tr(zh: '語音房', en: 'Voice Room'),
      icon: Icons.local_fire_department,
      expandChild: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final compressedLayout = keyboardOpen || availableHeight < 360;
          final showStatTiles = !keyboardOpen && availableHeight >= 320;
          final stackComposer = narrowLayout && !compressedLayout;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compressedLayout)
                Row(
                  children: [
                    Expanded(child: _CampfireStatusBanner(subtitle: subtitle)),
                    const SizedBox(width: 8),
                    _StampButton(
                      label: state.connected
                          ? strings.tr(
                              zh: state.micEnabled ? '麥克風開啟' : '麥克風靜音',
                              en: state.micEnabled ? 'Mic On' : 'Mic Muted',
                            )
                          : strings.tr(zh: '麥克風', en: 'Mic'),
                      iconWidget: _PixelMicStoneIcon(enabled: state.micEnabled),
                      tone: state.micEnabled
                          ? _StampTone.green
                          : _StampTone.wood,
                      onPressed: state.connected ? widget.onToggleMic : null,
                    ),
                  ],
                )
              else if (narrowLayout)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CampfireStatusBanner(subtitle: subtitle),
                    SizedBox(height: denseSpacing ? 6 : 8),
                    _StampButton(
                      label: state.connected
                          ? strings.tr(
                              zh: state.micEnabled ? '麥克風開啟' : '麥克風靜音',
                              en: state.micEnabled ? 'Mic On' : 'Mic Muted',
                            )
                          : strings.tr(zh: '麥克風', en: 'Mic'),
                      iconWidget: _PixelMicStoneIcon(enabled: state.micEnabled),
                      tone: state.micEnabled
                          ? _StampTone.green
                          : _StampTone.wood,
                      onPressed: state.connected ? widget.onToggleMic : null,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _CampfireStatusBanner(subtitle: subtitle)),
                    const SizedBox(width: 8),
                    _StampButton(
                      label: state.connected
                          ? strings.tr(
                              zh: state.micEnabled ? '麥克風開啟' : '麥克風靜音',
                              en: state.micEnabled ? 'Mic On' : 'Mic Muted',
                            )
                          : strings.tr(zh: '麥克風', en: 'Mic'),
                      iconWidget: _PixelMicStoneIcon(enabled: state.micEnabled),
                      tone: state.micEnabled
                          ? _StampTone.green
                          : _StampTone.wood,
                      onPressed: state.connected ? widget.onToggleMic : null,
                    ),
                  ],
                ),
              if (showStatTiles) ...[
                SizedBox(height: denseSpacing ? 6 : 8),
                if (narrowLayout)
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              title: strings.tr(zh: '連線人數', en: 'Members'),
                              value: '${state.participantCount}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatTile(
                              title: strings.tr(zh: '發話中', en: 'Speaking'),
                              value: '$speakingCount',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _StatTile(
                        title: strings.tr(zh: '房間', en: 'Room'),
                        value: roomLabel,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          title: strings.tr(zh: '連線人數', en: 'Members'),
                          value: '${state.participantCount}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          title: strings.tr(zh: '發話中', en: 'Speaking'),
                          value: '$speakingCount',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          title: strings.tr(zh: '房間', en: 'Room'),
                          value: roomLabel,
                        ),
                      ),
                    ],
                  ),
              ],
              if (state.errorMessage != null) ...[
                SizedBox(height: denseSpacing ? 6 : 8),
                PixelPanel(
                  key: AppTestIds.voiceErrorBannerKey,
                  tone: PixelTone.ruby,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  cut: 10,
                  borderWidth: 2,
                  shadowDepth: 2,
                  child: Text(
                    state.errorMessage!,
                    style: PixelTypography.style(
                      color: const Color(0xFFFFD7CF),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      height: 1.12,
                    ),
                  ),
                ),
              ],
              SizedBox(height: denseSpacing ? 6 : 10),
              Expanded(
                child: PixelPanel(
                  tone: PixelTone.wood,
                  padding: const EdgeInsets.all(8),
                  cut: 10,
                  borderWidth: 2,
                  shadowDepth: 3,
                  child: state.messages.isEmpty
                      ? Center(
                          child: Text(
                            strings.tr(
                              zh: '語音房還很安靜，來說第一句話吧。',
                              en: 'The voice room is quiet. Say the first line.',
                            ),
                            textAlign: TextAlign.center,
                            style: PixelTypography.style(
                              color: AppColors.inkBrown,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              height: 1.18,
                            ),
                          ),
                        )
                      : NotificationListener<UserScrollNotification>(
                          onNotification: (notification) {
                            if (!_chatScrollController.hasClients) {
                              return false;
                            }
                            final extentAfter =
                                _chatScrollController.position.extentAfter;
                            if (notification.direction ==
                                ScrollDirection.reverse) {
                              _autoScrollEnabled = true;
                            } else if (notification.direction ==
                                ScrollDirection.forward) {
                              _autoScrollEnabled = extentAfter <= 56;
                            }
                            return false;
                          },
                          child: ListView.separated(
                            controller: _chatScrollController,
                            itemCount: state.messages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final message = state.messages[index];
                              return PixelPanel(
                                tone: index.isEven
                                    ? PixelTone.slate
                                    : PixelTone.wood,
                                padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                                cut: 8,
                                borderWidth: 2,
                                shadowDepth: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            message.senderName,
                                            style: PixelTypography.style(
                                              color: index.isEven
                                                  ? const Color(0xFFF4F0DD)
                                                  : const Color(0xFFFFE8BF),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatDateTime(message.sentAt),
                                          style: PixelTypography.style(
                                            color: index.isEven
                                                ? const Color(0xFFE8E0C9)
                                                : const Color(0xFFD3B88E),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      message.content,
                                      style: PixelTypography.style(
                                        color: index.isEven
                                            ? const Color(0xFFF8F5EA)
                                            : const Color(0xFFFDF4E3),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        height: 1.16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
              SizedBox(height: denseSpacing ? 6 : 10),
              if (!state.connected)
                _StampButton(
                  tapTargetKey: AppTestIds.voiceJoinButtonKey,
                  label: joining
                      ? strings.tr(zh: '連線中...', en: 'Connecting...')
                      : strings.tr(zh: '加入語音房', en: 'Join Voice Room'),
                  icon: Icons.campaign,
                  tone: _StampTone.green,
                  onPressed: joining ? null : _join,
                )
              else if (stackComposer)
                Column(
                  children: [
                    _PixelTextInput(
                      key: AppTestIds.voiceMessageFieldKey,
                      controller: _messageController,
                      enabled: !_sending,
                      label: strings.tr(zh: '房間聊天', en: 'Room Chat'),
                      hintText: strings.tr(
                        zh: '輸入要廣播到語音房的訊息',
                        en: 'Write a message for the room',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _StampButton(
                            tapTargetKey: AppTestIds.voiceSendButtonKey,
                            label: _sending
                                ? strings.tr(zh: '送出中...', en: 'Sending...')
                                : strings.tr(zh: '送出', en: 'Send'),
                            icon: Icons.send_rounded,
                            tone: _StampTone.blue,
                            onPressed: _sending ? null : _send,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StampButton(
                            tapTargetKey: AppTestIds.voiceLeaveButtonKey,
                            label: strings.tr(
                              zh: '離開語音房',
                              en: 'Leave Voice Room',
                            ),
                            icon: Icons.logout,
                            tone: _StampTone.ruby,
                            onPressed: widget.onLeave,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _PixelTextInput(
                        key: AppTestIds.voiceMessageFieldKey,
                        controller: _messageController,
                        enabled: !_sending,
                        label: strings.tr(zh: '房間聊天', en: 'Room Chat'),
                        hintText: strings.tr(
                          zh: '輸入要廣播到語音房的訊息',
                          en: 'Write a message for the room',
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          _send();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StampButton(
                      tapTargetKey: AppTestIds.voiceSendButtonKey,
                      label: _sending
                          ? strings.tr(zh: '送出中...', en: 'Sending...')
                          : strings.tr(zh: '送出', en: 'Send'),
                      icon: Icons.send_rounded,
                      tone: _StampTone.blue,
                      onPressed: _sending ? null : _send,
                    ),
                    const SizedBox(width: 8),
                    _StampButton(
                      tapTargetKey: AppTestIds.voiceLeaveButtonKey,
                      label: strings.tr(zh: '離開語音房', en: 'Leave Voice Room'),
                      icon: Icons.logout,
                      tone: _StampTone.ruby,
                      onPressed: widget.onLeave,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
