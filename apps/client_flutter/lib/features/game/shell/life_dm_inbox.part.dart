part of '../game_shell_page.dart';

@immutable
class _DirectMessageInboxSnapshot {
  const _DirectMessageInboxSnapshot({
    required this.loading,
    required this.errorMessage,
    required this.contacts,
    required this.threads,
    required this.threadSecurityByCounterpart,
    required this.selectedCounterpartId,
    required this.friendCount,
    required this.threadCount,
    required this.unreadCount,
  });

  factory _DirectMessageInboxSnapshot.fromState(DirectMessagesState state) {
    return _DirectMessageInboxSnapshot(
      loading: state.loading,
      errorMessage: state.errorMessage,
      contacts: state.contacts,
      threads: state.threads,
      threadSecurityByCounterpart: state.threadSecurityByCounterpart,
      selectedCounterpartId: state.selectedCounterpartId,
      friendCount: state.contacts.length,
      threadCount: state.threads.length,
      unreadCount: state.totalUnreadCount,
    );
  }

  final bool loading;
  final String? errorMessage;
  final List<FriendProfile> contacts;
  final List<DirectMessageThread> threads;
  final Map<String, DmThreadSecuritySnapshot> threadSecurityByCounterpart;
  final String? selectedCounterpartId;
  final int friendCount;
  final int threadCount;
  final int unreadCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _DirectMessageInboxSnapshot &&
            loading == other.loading &&
            errorMessage == other.errorMessage &&
            selectedCounterpartId == other.selectedCounterpartId &&
            friendCount == other.friendCount &&
            threadCount == other.threadCount &&
            unreadCount == other.unreadCount &&
            identical(contacts, other.contacts) &&
            identical(threads, other.threads) &&
            identical(
              threadSecurityByCounterpart,
              other.threadSecurityByCounterpart,
            );
  }

  @override
  int get hashCode => Object.hash(
    loading,
    errorMessage,
    selectedCounterpartId,
    friendCount,
    threadCount,
    unreadCount,
    identityHashCode(contacts),
    identityHashCode(threads),
    identityHashCode(threadSecurityByCounterpart),
  );
}

class _DirectMessagesPanel extends ConsumerStatefulWidget {
  const _DirectMessagesPanel();

  @override
  ConsumerState<_DirectMessagesPanel> createState() =>
      _DirectMessagesPanelState();
}

class _DirectMessagesPanelState extends ConsumerState<_DirectMessagesPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text;
    if (nextQuery == _searchQuery || !mounted) {
      return;
    }
    setState(() => _searchQuery = nextQuery);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(
      directMessagesControllerProvider.select(
        _DirectMessageInboxSnapshot.fromState,
      ),
    );
    final counterpartId = snapshot.selectedCounterpartId;
    final selectedThread = counterpartId == null
        ? null
        : _findDirectMessageThread(snapshot.threads, counterpartId);
    final selectedContact = counterpartId == null
        ? null
        : _findFriendContact(snapshot.contacts, counterpartId);
    final selectedName =
        selectedThread?.counterpartName ?? selectedContact?.name;
    final roster = _mergeDirectMessageRoster(
      threads: snapshot.threads,
      contacts: snapshot.contacts,
    );

    Future<void> openConversation(_DirectMessageRosterEntry entry) async {
      FocusScope.of(context).unfocus();
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        _buildDirectMessageConversationRoute(
          counterpartId: entry.hunterId,
          counterpartName: entry.name,
          counterpartPlayerId: entry.playerId,
        ),
      );
    }

    return _DirectMessageInboxPage(
      threadCount: snapshot.threadCount,
      friendCount: snapshot.friendCount,
      unreadCount: snapshot.unreadCount,
      searchController: _searchController,
      searchQuery: _searchQuery,
      selectedName: selectedName,
      errorMessage: snapshot.errorMessage,
      roster: roster,
      threadSecurityByCounterpart: snapshot.threadSecurityByCounterpart,
      selectedCounterpartId: counterpartId,
      loading: snapshot.loading,
      onSelect: (entry) => unawaited(openConversation(entry)),
    );
  }
}

class _DirectMessageRosterSection {
  const _DirectMessageRosterSection({
    required this.title,
    required this.entries,
  });

  final String title;
  final List<_DirectMessageRosterEntry> entries;
}

class _DirectMessageRosterListItem {
  const _DirectMessageRosterListItem.section(this.sectionTitle) : entry = null;
  const _DirectMessageRosterListItem.entry(this.entry) : sectionTitle = null;

  final String? sectionTitle;
  final _DirectMessageRosterEntry? entry;

  bool get isSection => sectionTitle != null;
}

DirectMessageThread? _findDirectMessageThread(
  List<DirectMessageThread> threads,
  String counterpartId,
) {
  for (final thread in threads) {
    if (thread.counterpartHunterId == counterpartId) {
      return thread;
    }
  }
  return null;
}

FriendProfile? _findFriendContact(
  List<FriendProfile> contacts,
  String counterpartId,
) {
  for (final contact in contacts) {
    if (contact.id == counterpartId) {
      return contact;
    }
  }
  return null;
}

class _DirectMessageRosterEntry {
  const _DirectMessageRosterEntry({
    required this.hunterId,
    required this.name,
    required this.playerId,
    required this.avatarType,
    this.thread,
  });

  final String hunterId;
  final String name;
  final String playerId;
  final String avatarType;
  final DirectMessageThread? thread;
}

List<_DirectMessageRosterEntry> _mergeDirectMessageRoster({
  required List<DirectMessageThread> threads,
  required List<FriendProfile> contacts,
}) {
  final byId = <String, _DirectMessageRosterEntry>{};
  for (final thread in threads) {
    byId[thread.counterpartHunterId] = _DirectMessageRosterEntry(
      hunterId: thread.counterpartHunterId,
      name: thread.counterpartName,
      playerId: thread.counterpartPlayerId,
      avatarType: thread.counterpartAvatarType,
      thread: thread,
    );
  }
  for (final contact in contacts) {
    byId.putIfAbsent(
      contact.id,
      () => _DirectMessageRosterEntry(
        hunterId: contact.id,
        name: contact.name,
        playerId: contact.playerId,
        avatarType: contact.avatarType,
      ),
    );
  }
  final entries = byId.values.toList(growable: false);
  entries.sort((a, b) {
    final aUnread = a.thread?.unreadCount ?? 0;
    final bUnread = b.thread?.unreadCount ?? 0;
    if ((aUnread > 0) != (bUnread > 0)) {
      return (bUnread > 0 ? 1 : 0).compareTo(aUnread > 0 ? 1 : 0);
    }
    if (aUnread != bUnread) {
      return bUnread.compareTo(aUnread);
    }
    final aAt = a.thread?.lastMessageAtMs ?? -1;
    final bAt = b.thread?.lastMessageAtMs ?? -1;
    if (aAt != bAt) {
      return bAt.compareTo(aAt);
    }
    return a.name.compareTo(b.name);
  });
  return entries;
}

List<_DirectMessageRosterEntry> _filterDirectMessageRoster({
  required List<_DirectMessageRosterEntry> roster,
  required String searchQuery,
}) {
  final normalized = searchQuery.trim().toLowerCase();
  if (normalized.isEmpty) {
    return roster;
  }
  return roster
      .where((entry) {
        final threadPreview = entry.thread?.lastMessage.toLowerCase() ?? '';
        final haystack = <String>[
          entry.name.toLowerCase(),
          entry.playerId.toLowerCase(),
          threadPreview,
        ].join(' ');
        return haystack.contains(normalized);
      })
      .toList(growable: false);
}

List<_DirectMessageRosterSection> _buildDirectMessageRosterSections({
  required List<_DirectMessageRosterEntry> roster,
  required AppStrings strings,
}) {
  final unread = <_DirectMessageRosterEntry>[];
  final today = <_DirectMessageRosterEntry>[];
  final yesterday = <_DirectMessageRosterEntry>[];
  final earlier = <_DirectMessageRosterEntry>[];
  final newChats = <_DirectMessageRosterEntry>[];
  final now = DateTime.now();
  final todayAnchor = DateTime(now.year, now.month, now.day);
  final yesterdayAnchor = todayAnchor.subtract(const Duration(days: 1));

  for (final entry in roster) {
    final unreadCount = entry.thread?.unreadCount ?? 0;
    if (unreadCount > 0) {
      unread.add(entry);
      continue;
    }
    final thread = entry.thread;
    if (thread == null) {
      newChats.add(entry);
      continue;
    }
    final local = thread.lastMessageAt.toLocal();
    final anchor = DateTime(local.year, local.month, local.day);
    if (_sameCalendarDay(anchor, todayAnchor)) {
      today.add(entry);
    } else if (_sameCalendarDay(anchor, yesterdayAnchor)) {
      yesterday.add(entry);
    } else {
      earlier.add(entry);
    }
  }

  final sections = <_DirectMessageRosterSection>[];
  if (unread.isNotEmpty) {
    sections.add(
      _DirectMessageRosterSection(
        title: strings.tr(zh: '未讀', en: 'Unread'),
        entries: unread,
      ),
    );
  }
  if (today.isNotEmpty) {
    sections.add(
      _DirectMessageRosterSection(
        title: strings.tr(zh: '今天', en: 'Today'),
        entries: today,
      ),
    );
  }
  if (yesterday.isNotEmpty) {
    sections.add(
      _DirectMessageRosterSection(
        title: strings.tr(zh: '昨天', en: 'Yesterday'),
        entries: yesterday,
      ),
    );
  }
  if (earlier.isNotEmpty) {
    sections.add(
      _DirectMessageRosterSection(
        title: strings.tr(zh: '較早', en: 'Earlier'),
        entries: earlier,
      ),
    );
  }
  if (newChats.isNotEmpty) {
    sections.add(
      _DirectMessageRosterSection(
        title: strings.tr(zh: '新對話', en: 'Start New'),
        entries: newChats,
      ),
    );
  }
  return sections;
}

List<_DirectMessageRosterListItem> _flattenDirectMessageRosterSections(
  List<_DirectMessageRosterSection> sections,
) {
  if (sections.isEmpty) {
    return const <_DirectMessageRosterListItem>[];
  }
  final items = <_DirectMessageRosterListItem>[];
  for (final section in sections) {
    items.add(_DirectMessageRosterListItem.section(section.title));
    for (final entry in section.entries) {
      items.add(_DirectMessageRosterListItem.entry(entry));
    }
  }
  return items;
}

class _DirectMessageRoster extends StatelessWidget {
  const _DirectMessageRoster({
    required this.roster,
    required this.threadSecurityByCounterpart,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCounterpartId,
    required this.loading,
    required this.onSelect,
  });

  final List<_DirectMessageRosterEntry> roster;
  final Map<String, DmThreadSecuritySnapshot> threadSecurityByCounterpart;
  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedCounterpartId;
  final bool loading;
  final ValueChanged<_DirectMessageRosterEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final hasSearch = searchQuery.trim().isNotEmpty;
    final filteredRoster = hasSearch
        ? _filterDirectMessageRoster(roster: roster, searchQuery: searchQuery)
        : roster;
    final sections = _buildDirectMessageRosterSections(
      roster: filteredRoster,
      strings: strings,
    );
    final listItems = _flattenDirectMessageRosterSections(sections);
    return PixelPanel(
      tone: PixelTone.parchment,
      padding: const EdgeInsets.all(10),
      cut: 12,
      shadowDepth: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.tr(zh: '好友名單', en: 'Roster'),
            style: const TextStyle(
              color: AppColors.inkBrown,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          PixelPanel(
            tone: PixelTone.parchment,
            showShadow: false,
            faceColor: const Color(0xFFF0E5CF),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('dm_inbox_search'),
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: strings.tr(
                        zh: '搜尋朋友、玩家 ID 或最近一句話...',
                        en: 'Search friends, player IDs, or recent lines...',
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
                  ),
                ),
                if (searchQuery.trim().isNotEmpty)
                  GestureDetector(
                    onTap: () => searchController.clear(),
                    child: PixelTag(
                      label: strings.tr(zh: '清除', en: 'Clear'),
                      tone: PixelTone.slate,
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : roster.isEmpty
                ? Center(
                    child: Text(
                      strings.tr(
                        zh: '先加好友，這裡才會出現可私訊的對象。',
                        en: 'Add a friend first to unlock direct messages here.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.inkBrown,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  )
                : filteredRoster.isEmpty
                ? Center(
                    child: Text(
                      strings.tr(
                        zh: '沒有符合搜尋的對話。換個名字、玩家 ID 或訊息關鍵字試試看。',
                        en: 'No matching threads. Try a friend name, player ID, or a word from the preview.',
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
                    cacheExtent: 720,
                    itemCount: listItems.length,
                    itemBuilder: (context, index) {
                      final item = listItems[index];
                      if (item.isSection) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                          child: Text(
                            item.sectionTitle!,
                            style: TextStyle(
                              color: AppColors.inkBrown.withValues(alpha: 0.74),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                        );
                      }
                      final entry = item.entry!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RepaintBoundary(
                          child: _DirectMessageRosterCard(
                            entry: entry,
                            selectedCounterpartId: selectedCounterpartId,
                            security:
                                threadSecurityByCounterpart[entry.hunterId],
                            onTap: () => onSelect(entry),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DirectMessageRosterCard extends StatelessWidget {
  const _DirectMessageRosterCard({
    required this.entry,
    required this.selectedCounterpartId,
    required this.security,
    required this.onTap,
  });

  final _DirectMessageRosterEntry entry;
  final String? selectedCounterpartId;
  final DmThreadSecuritySnapshot? security;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final selected = entry.hunterId == selectedCounterpartId;
    final unreadCount = entry.thread?.unreadCount ?? 0;
    final securityStatus = _resolveDmSecurityStatus(
      strings: strings,
      security: security,
      serverMode: entry.thread?.encryptionMode,
    );
    return InkWell(
      onTap: onTap,
      child: PixelPanel(
        tone: selected ? PixelTone.blue : PixelTone.parchment,
        padding: const EdgeInsets.all(10),
        cut: 10,
        shadowDepth: 2,
        faceColor: selected ? null : Colors.white.withValues(alpha: 0.32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DirectMessageAvatar(label: entry.name),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PixelTag(
                            label: entry.playerId.toUpperCase(),
                            tone: selected ? PixelTone.slate : PixelTone.wood,
                            compact: true,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.inkBrown,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.thread == null
                            ? strings.tr(
                                zh: '點進去和對方開一條新的聊天線。',
                                en: 'Tap in to start a new conversation.',
                              )
                            : entry.thread!.lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.inkBrown.withValues(alpha: 0.76),
                          fontWeight: unreadCount > 0
                              ? FontWeight.w900
                              : FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PixelTag(
                        label: securityStatus.label,
                        tone: securityStatus.tone,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (unreadCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: PixelTag(
                          label: unreadCount > 99
                              ? '99+'
                              : unreadCount.toString(),
                          tone: PixelTone.ruby,
                          compact: true,
                        ),
                      ),
                    Text(
                      entry.thread == null
                          ? strings.tr(zh: '新對話', en: 'New')
                          : _formatDirectMessageListTime(
                              entry.thread!.lastMessageAt,
                              strings,
                            ),
                      style: TextStyle(
                        color: AppColors.inkBrown.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '>',
                      style: TextStyle(
                        color: AppColors.inkBrown.withValues(alpha: 0.46),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectMessageInboxPage extends StatelessWidget {
  const _DirectMessageInboxPage({
    required this.threadCount,
    required this.friendCount,
    required this.unreadCount,
    required this.searchController,
    required this.searchQuery,
    required this.selectedName,
    required this.errorMessage,
    required this.roster,
    required this.threadSecurityByCounterpart,
    required this.selectedCounterpartId,
    required this.loading,
    required this.onSelect,
  });

  final int threadCount;
  final int friendCount;
  final int unreadCount;
  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedName;
  final String? errorMessage;
  final List<_DirectMessageRosterEntry> roster;
  final Map<String, DmThreadSecuritySnapshot> threadSecurityByCounterpart;
  final String? selectedCounterpartId;
  final bool loading;
  final ValueChanged<_DirectMessageRosterEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.directMessages,
          style: const TextStyle(
            color: AppColors.inkBrown,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          strings.tr(
            zh: '像真正訊息 app 一樣，先看對話列表，再點進去和家人或朋友聊天。',
            en: 'Browse your threads first, then tap in to chat with family and friends like a real messenger.',
          ),
          style: TextStyle(
            color: AppColors.inkBrown.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatGemChip(
              icon: const _PixelLabelGlyph(glyph: 'THR'),
              label: strings.tr(
                zh: '對話 $threadCount 條',
                en: '$threadCount Threads',
              ),
              color: AppColors.apSapphire,
            ),
            _StatGemChip(
              icon: const _PixelLabelGlyph(glyph: 'FRD'),
              label: strings.tr(
                zh: '好友 $friendCount 位',
                en: '$friendCount Friends',
              ),
              color: AppColors.stampGreen,
            ),
            _StatGemChip(
              icon: const _PixelLabelGlyph(glyph: 'SEL'),
              label:
                  selectedName ?? strings.tr(zh: '點一位朋友', en: 'Tap a Thread'),
              color: const Color(0xFF7C5FB3),
            ),
            if (unreadCount > 0)
              _StatGemChip(
                icon: const _PixelLabelGlyph(glyph: 'NEW'),
                label: strings.tr(
                  zh: '未讀 $unreadCount 則',
                  en: '$unreadCount Unread',
                ),
                color: AppColors.hpRuby,
              ),
          ],
        ),
        const SizedBox(height: 10),
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
          const SizedBox(height: 10),
        ],
        Expanded(
          child: _DirectMessageRoster(
            roster: roster,
            threadSecurityByCounterpart: threadSecurityByCounterpart,
            searchController: searchController,
            searchQuery: searchQuery,
            selectedCounterpartId: selectedCounterpartId,
            loading: loading,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}
