part of '../../game_shell_page.dart';

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
                  child: _PixelTextInput(
                    key: const ValueKey('dm_inbox_search'),
                    controller: searchController,
                    label: strings.tr(zh: '搜尋', en: 'Search'),
                    hintText: strings.tr(
                      zh: '搜尋朋友、玩家 ID 或最近一句話...',
                      en: 'Search friends, player IDs, or recent lines...',
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
                    scrollCacheExtent: const ScrollCacheExtent.pixels(720),
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
                            : _directMessagePreviewLabel(
                                strings: strings,
                                raw: entry.thread!.lastMessage,
                              ),
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
    required this.unreadCount,
    required this.searchController,
    required this.searchQuery,
    required this.selectedName,
    required this.errorMessage,
    required this.roster,
    required this.threadSecurityByCounterpart,
    required this.selectedCounterpartId,
    required this.loading,
    required this.onRefresh,
    required this.onSelect,
  });

  final int unreadCount;
  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedName;
  final String? errorMessage;
  final List<_DirectMessageRosterEntry> roster;
  final Map<String, DmThreadSecuritySnapshot> threadSecurityByCounterpart;
  final String? selectedCounterpartId;
  final bool loading;
  final VoidCallback onRefresh;
  final ValueChanged<_DirectMessageRosterEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.directMessages,
                style: const TextStyle(
                  color: AppColors.inkBrown,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (unreadCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PixelTag(
                  label: strings.tr(
                    zh: '$unreadCount 未讀',
                    en: '$unreadCount unread',
                  ),
                  tone: PixelTone.ruby,
                  compact: true,
                ),
              ),
            SizedBox(
              width: 92,
              child: PixelButton(
                label: strings.photoDumpRefresh,
                compact: true,
                tone: PixelTone.slate,
                onPressed: onRefresh,
              ),
            ),
          ],
        ),
        if (selectedName != null && selectedName!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            strings.tr(zh: '目前選擇：$selectedName', en: 'Selected: $selectedName'),
            style: TextStyle(
              color: AppColors.inkBrown.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
                    onPressed: onRefresh,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
