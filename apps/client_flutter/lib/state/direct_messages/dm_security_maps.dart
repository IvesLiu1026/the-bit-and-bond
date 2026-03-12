import '../../core/auth/auth_session.dart';
import '../../core/security/dm_e2ee_service.dart';
import '../../core/models/models.dart';
import 'dm_utils.dart';

Map<String, DmThreadSecuritySnapshot> resolveCachedDmSecurityMap({
  required AuthSession session,
  required DmE2eeService e2ee,
  required List<FriendProfile> contacts,
  required List<DirectMessageThread> threads,
  Map<String, DmThreadSecuritySnapshot> seed = const {},
}) {
  final threadModeByCounterpart = <String, String>{
    for (final contact in contacts) contact.id: DmE2eeService.plaintextMode,
    for (final thread in threads)
      thread.counterpartHunterId: thread.encryptionMode,
  };
  final ids = threadModeByCounterpart.keys.toSet().toList(growable: false);
  if (ids.isEmpty) {
    return <String, DmThreadSecuritySnapshot>{...seed};
  }
  final cachedSnapshots = e2ee.cachedThreadSecuritySnapshots(
    session: session,
    counterpartHunterIds: ids,
    threadModeByCounterpart: threadModeByCounterpart,
  );
  final byCounterpart = <String, DmThreadSecuritySnapshot>{};
  for (final counterpartId in ids) {
    final thread = findDirectMessageThread(counterpartId, threads);
    byCounterpart[counterpartId] =
        cachedSnapshots[counterpartId] ??
        byCounterpart[counterpartId] ??
        DmThreadSecuritySnapshot(
          counterpartHunterId: counterpartId,
          threadMode: thread?.encryptionMode ?? DmE2eeService.plaintextMode,
          localIdentity: null,
          peerDeviceKeys: const <DmDeviceKey>[],
        );
  }
  return byCounterpart;
}

Future<Map<String, DmThreadSecuritySnapshot>> resolveFreshDmSecurityMap({
  required AuthSession session,
  required DmE2eeService e2ee,
  required List<FriendProfile> contacts,
  required List<DirectMessageThread> threads,
  Map<String, DmThreadSecuritySnapshot> seed = const {},
}) async {
  final threadModeByCounterpart = <String, String>{
    for (final contact in contacts) contact.id: DmE2eeService.plaintextMode,
    for (final thread in threads)
      thread.counterpartHunterId: thread.encryptionMode,
  };
  final ids = threadModeByCounterpart.keys.toSet().toList(growable: false);
  if (ids.isEmpty) {
    return <String, DmThreadSecuritySnapshot>{...seed};
  }
  final byCounterpart = <String, DmThreadSecuritySnapshot>{};
  Map<String, DmThreadSecuritySnapshot> resolved;
  try {
    resolved = await e2ee.resolveThreadSecurityBatch(
      session: session,
      counterpartHunterIds: ids,
      threadModeByCounterpart: threadModeByCounterpart,
    );
  } catch (_) {
    resolved = e2ee.cachedThreadSecuritySnapshots(
      session: session,
      counterpartHunterIds: ids,
      threadModeByCounterpart: threadModeByCounterpart,
    );
  }
  for (final counterpartId in ids) {
    final thread = findDirectMessageThread(counterpartId, threads);
    byCounterpart[counterpartId] =
        resolved[counterpartId] ??
        byCounterpart[counterpartId] ??
        DmThreadSecuritySnapshot(
          counterpartHunterId: counterpartId,
          threadMode: thread?.encryptionMode ?? DmE2eeService.plaintextMode,
          localIdentity: null,
          peerDeviceKeys: const <DmDeviceKey>[],
        );
  }
  return byCounterpart;
}
