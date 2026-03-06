part of 'game_shell_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final speakingCount = state.activeSpeakerIdentities.length;
    final compact =
        MediaQuery.of(context).size.width < 520 ||
        MediaQuery.of(context).size.height < 760;
    final roomLabel = () {
      final room = state.roomId;
      if (room == null || room.isEmpty) {
        return '未加入';
      }
      if (room.length <= 12) {
        return room;
      }
      return '${room.substring(0, 6)}..';
    }();
    final subtitle = state.connected
        ? '酒館營火連線中'
        : (state.connecting ? '正在連到營火...' : '尚未連線');

    return _ParchmentSection(
      title: '營火語音吧台',
      icon: Icons.local_fire_department,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A2A20),
                    border: Border.all(
                      color: const Color(0xFF7B5A3C),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x803E2723),
                        offset: Offset(0, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFFDE8C8),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _StampButton(
                  label: state.connected
                      ? (state.micEnabled ? '麥克風開啟' : '麥克風靜音')
                      : '麥克風',
                  iconWidget: _PixelMicStoneIcon(enabled: state.micEnabled),
                  tone: state.micEnabled ? _StampTone.green : _StampTone.wood,
                  onPressed: state.connected ? widget.onToggleMic : null,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2A20),
                      border: Border.all(
                        color: const Color(0xFF7B5A3C),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x803E2723),
                          offset: Offset(0, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFFDE8C8),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StampButton(
                  label: state.connected
                      ? (state.micEnabled ? '麥克風開啟' : '麥克風靜音')
                      : '麥克風',
                  iconWidget: _PixelMicStoneIcon(enabled: state.micEnabled),
                  tone: state.micEnabled ? _StampTone.green : _StampTone.wood,
                  onPressed: state.connected ? widget.onToggleMic : null,
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (compact)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        title: '連線人數',
                        value: '${state.participantCount}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(title: '發話中', value: '$speakingCount'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _StatTile(title: '房間', value: roomLabel),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    title: '連線人數',
                    value: '${state.participantCount}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(title: '發話中', value: '$speakingCount'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(title: '房間', value: roomLabel),
                ),
              ],
            ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF5E2720),
                border: Border.all(color: const Color(0xFFD84343), width: 2),
              ),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFFFD7CF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          SizedBox(height: compact ? 6 : 10),
          SizedBox(
            height: compact ? 156 : 248,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3E2723),
                border: Border.all(color: const Color(0xFF9C7454), width: 2.4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x8A2A1811),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: state.messages.isEmpty
                  ? const Center(
                      child: Text(
                        '營火還很安靜，來說第一句話吧。',
                        style: TextStyle(
                          color: Color(0xFFF5DEBE),
                          fontWeight: FontWeight.w700,
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
                        if (notification.direction == ScrollDirection.reverse) {
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
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final message = state.messages[index];
                          return Container(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5D4037),
                              border: Border.all(
                                color: const Color(0xFFD7C4A3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        message.senderName,
                                        style: const TextStyle(
                                          color: Color(0xFFFFE8BF),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(message.sentAt),
                                      style: const TextStyle(
                                        color: Color(0xFFD3B88E),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message.content,
                                  style: const TextStyle(
                                    color: Color(0xFFFDF4E3),
                                    fontWeight: FontWeight.w700,
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
          SizedBox(height: compact ? 6 : 10),
          if (!state.connected)
            _StampButton(
              label: state.connecting ? '連線中...' : '加入營火',
              icon: Icons.campaign,
              tone: _StampTone.green,
              onPressed: state.connecting ? null : widget.onJoin,
            )
          else if (compact)
            Column(
              children: [
                TextField(
                  controller: _messageController,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                    labelText: '酒館聊天',
                    isDense: true,
                    filled: true,
                    fillColor: Color(0xFFE7DDC9),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StampButton(
                        label: _sending ? '送出中...' : '送出',
                        icon: Icons.send_rounded,
                        tone: _StampTone.blue,
                        onPressed: _sending ? null : _send,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StampButton(
                        label: '離開營火',
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
                  child: TextField(
                    controller: _messageController,
                    enabled: !_sending,
                    decoration: const InputDecoration(
                      labelText: '酒館聊天',
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFFE7DDC9),
                    ),
                    onSubmitted: (_) {
                      _send();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _StampButton(
                  label: _sending ? '送出中...' : '送出',
                  icon: Icons.send_rounded,
                  tone: _StampTone.blue,
                  onPressed: _sending ? null : _send,
                ),
                const SizedBox(width: 8),
                _StampButton(
                  label: '離開營火',
                  icon: Icons.logout,
                  tone: _StampTone.ruby,
                  onPressed: widget.onLeave,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PixelMicStoneIcon extends StatelessWidget {
  const _PixelMicStoneIcon({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _PixelMicStonePainter(enabled: enabled)),
    );
  }
}

class _PixelMicStonePainter extends CustomPainter {
  const _PixelMicStonePainter({required this.enabled});

  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = enabled ? const Color(0xFF1976D2) : const Color(0xFF8B8B8B);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFF2A1F18);
    final gloss = Paint()
      ..color = enabled ? const Color(0xAA90CAF9) : const Color(0x66E0E0E0);

    final orb = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawRect(orb, bg);
    canvas.drawRect(orb, edge);
    canvas.drawRect(
      Rect.fromLTWH(
        3,
        3,
        math.max(2, size.width * 0.35),
        math.max(2, size.height * 0.35),
      ),
      gloss,
    );

    final mic = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..color = enabled ? const Color(0xFFEAF6FF) : const Color(0xFF3E2723);
    final centerX = size.width / 2;
    canvas.drawLine(Offset(centerX, 5), Offset(centerX, size.height - 6), mic);
    canvas.drawLine(
      Offset(centerX - 4, size.height - 6),
      Offset(centerX + 4, size.height - 6),
      mic,
    );
    if (!enabled) {
      final crack = Paint()
        ..strokeWidth = 1.8
        ..color = const Color(0xFF3E2723);
      canvas.drawLine(const Offset(4, 16), const Offset(16, 4), crack);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelMicStonePainter oldDelegate) {
    return oldDelegate.enabled != enabled;
  }
}
