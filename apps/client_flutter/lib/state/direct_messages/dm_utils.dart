import '../../features/quests/models.dart';

DirectMessageThread? findDirectMessageThread(
  String counterpartHunterId,
  List<DirectMessageThread> threads,
) {
  for (final thread in threads) {
    if (thread.counterpartHunterId == counterpartHunterId) {
      return thread;
    }
  }
  return null;
}

FriendProfile? findFriendProfile(
  String counterpartHunterId,
  List<FriendProfile> contacts,
) {
  for (final contact in contacts) {
    if (contact.id == counterpartHunterId) {
      return contact;
    }
  }
  return null;
}

List<DirectMessageThread> sortDirectMessageThreads(
  List<DirectMessageThread> threads,
) {
  final sorted = [...threads];
  sorted.sort((a, b) {
    final aUnread = a.unreadCount > 0 ? 1 : 0;
    final bUnread = b.unreadCount > 0 ? 1 : 0;
    if (aUnread != bUnread) {
      return bUnread.compareTo(aUnread);
    }
    if (a.unreadCount != b.unreadCount) {
      return b.unreadCount.compareTo(a.unreadCount);
    }
    if (a.lastMessageAtMs != b.lastMessageAtMs) {
      return b.lastMessageAtMs.compareTo(a.lastMessageAtMs);
    }
    return a.counterpartName.compareTo(b.counterpartName);
  });
  return sorted;
}

List<DirectMessage> mergeDirectMessages(
  List<DirectMessage> plaintextMessages,
  List<DirectMessage> encryptedMessages,
) {
  final byKey = <String, DirectMessage>{};
  for (final message in [...plaintextMessages, ...encryptedMessages]) {
    final key = [
      message.encryptionMode,
      message.id,
      message.clientMessageId,
      message.sentAtMs,
    ].join('|');
    byKey[key] = message;
  }
  final merged = byKey.values.toList(growable: false)
    ..sort((a, b) {
      final byTime = a.sentAt.compareTo(b.sentAt);
      if (byTime != 0) {
        return byTime;
      }
      return a.id.compareTo(b.id);
    });
  return merged;
}
