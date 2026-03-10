part of '../../game_shell_page.dart';

@immutable
class _DirectMessageInboxSnapshot {
  const _DirectMessageInboxSnapshot({
    required this.loading,
    required this.errorMessage,
    required this.contacts,
    required this.threads,
    required this.threadSecurityByCounterpart,
    required this.selectedCounterpartId,
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
      unreadCount: state.totalUnreadCount,
    );
  }

  final bool loading;
  final String? errorMessage;
  final List<FriendProfile> contacts;
  final List<DirectMessageThread> threads;
  final Map<String, DmThreadSecuritySnapshot> threadSecurityByCounterpart;
  final String? selectedCounterpartId;
  final int unreadCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _DirectMessageInboxSnapshot &&
            loading == other.loading &&
            errorMessage == other.errorMessage &&
            selectedCounterpartId == other.selectedCounterpartId &&
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
      unreadCount: snapshot.unreadCount,
      searchController: _searchController,
      searchQuery: _searchQuery,
      selectedName: selectedName,
      errorMessage: snapshot.errorMessage,
      roster: roster,
      threadSecurityByCounterpart: snapshot.threadSecurityByCounterpart,
      selectedCounterpartId: counterpartId,
      loading: snapshot.loading,
      onRefresh: () =>
          ref.read(directMessagesControllerProvider.notifier).refresh(),
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
