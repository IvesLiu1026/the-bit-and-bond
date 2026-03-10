import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_bit_and_bond_client/core/auth/auth_session.dart';
import 'package:the_bit_and_bond_client/core/network/api_client.dart';
import 'package:the_bit_and_bond_client/core/security/dm_e2ee_service.dart';
import 'package:the_bit_and_bond_client/features/quests/models.dart';

void main() {
  test(
    'dm e2ee service can encrypt, persist, and decrypt a DM round-trip',
    () async {
      final session = AuthSession(
        accessToken: 'token-self',
        guildId: 'guild-home',
        hunterId: 'hunter-self',
        guildRole: GuildRole.member,
        displayName: 'Demo Self',
      );
      final remoteIdentity = await _RemoteIdentity.create(
        hunterId: 'hunter-peer',
        deviceId: 'peer-main',
      );
      final api = _FakeApiClient(
        session: session,
        remoteHunterId: 'hunter-peer',
        remoteName: 'Demo Peer',
        remotePlayerId: 'demo_peer',
        remoteGuildId: 'guild-home',
        seededRemoteKeys: [remoteIdentity.deviceKey],
      );
      final store = _MemoryDmStore();
      final service = DmE2eeService(api: api, store: store);

      final localIdentity = await service.ensureLocalIdentity(session);
      expect(localIdentity.deviceId, isNotEmpty);
      expect(api.registeredLocalKeys, hasLength(1));

      final security = await service.resolveThreadSecurity(
        session: session,
        counterpartHunterId: 'hunter-peer',
      );
      expect(security.canEncryptNewMessages, isTrue);

      await service.sendEncryptedMessage(
        session: session,
        security: security,
        counterpartHunterId: 'hunter-peer',
        counterpartName: 'Demo Peer',
        counterpartPlayerId: 'demo_peer',
        counterpartGuildId: 'guild-home',
        content: 'drink water',
        clientMessageId: 'client-1',
        sentAt: DateTime.parse('2026-03-09T08:00:00Z'),
      );

      final messages = await service.loadEncryptedConversation(
        session: session,
        security: security.copyWith(threadMode: DmE2eeService.encryptedMode),
        counterpartHunterId: 'hunter-peer',
      );

      expect(messages, hasLength(1));
      expect(messages.first.content, 'drink water');
      expect(messages.first.isEncrypted, isTrue);
      expect(messages.first.decryptionFailed, isFalse);
    },
  );

  test('dm e2ee service can encrypt and decrypt media bytes', () async {
    final session = AuthSession(
      accessToken: 'token-self',
      guildId: 'guild-home',
      hunterId: 'hunter-self',
      guildRole: GuildRole.member,
      displayName: 'Demo Self',
    );
    final remoteIdentity = await _RemoteIdentity.create(
      hunterId: 'hunter-peer',
      deviceId: 'peer-main',
    );
    final api = _FakeApiClient(
      session: session,
      remoteHunterId: 'hunter-peer',
      remoteName: 'Demo Peer',
      remotePlayerId: 'demo_peer',
      remoteGuildId: 'guild-home',
      seededRemoteKeys: [remoteIdentity.deviceKey],
    );
    final service = DmE2eeService(api: api, store: _MemoryDmStore());

    await service.ensureLocalIdentity(session);
    final security = await service.resolveThreadSecurity(
      session: session,
      counterpartHunterId: 'hunter-peer',
      threadMode: DmE2eeService.encryptedMode,
    );
    expect(security.canEncryptNewMessages, isTrue);

    final plainBytes = List<int>.generate(
      512,
      (index) => index % 251,
      growable: false,
    );
    final encrypted = await service.encryptMediaBytes(
      security: security,
      plaintextBytes: plainBytes,
    );
    expect(encrypted.encryption.isEncrypted, isTrue);
    expect(encrypted.cipherBytes, isNot(plainBytes));

    final decrypted = await service.decryptMediaBytes(
      security: security,
      encryption: encrypted.encryption,
      cipherBytes: encrypted.cipherBytes,
    );
    expect(decrypted, plainBytes);

    final tampered = MediaEncryptionMeta(
      mode: encrypted.encryption.mode,
      protocolVersion: encrypted.encryption.protocolVersion,
      senderDeviceId: encrypted.encryption.senderDeviceId,
      recipientDeviceId: encrypted.encryption.recipientDeviceId,
      nonceBase64: encrypted.encryption.nonceBase64,
      macBase64: base64Encode(List<int>.filled(16, 7)),
    );
    await expectLater(
      () => service.decryptMediaBytes(
        security: security,
        encryption: tampered,
        cipherBytes: encrypted.cipherBytes,
      ),
      throwsA(isA<Object>()),
    );
  });
}

class _MemoryDmStore implements DmSecureStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class _RemoteIdentity {
  const _RemoteIdentity({required this.deviceKey});

  final DmDeviceKey deviceKey;

  static Future<_RemoteIdentity> create({
    required String hunterId,
    required String deviceId,
  }) async {
    final signing = await Ed25519().newKeyPair();
    final signingPublic = await signing.extractPublicKey();
    final encryption = await X25519().newKeyPair();
    final encryptionPublic = await encryption.extractPublicKey();
    final now = DateTime.parse('2026-03-09T08:00:00Z');
    return _RemoteIdentity(
      deviceKey: DmDeviceKey(
        id: 'remote-key-$deviceId',
        hunterId: hunterId,
        deviceId: deviceId,
        deviceLabel: 'peer-device',
        signingPublicKey: base64Encode(signingPublic.bytes),
        encryptionPublicKey: base64Encode(encryptionPublic.bytes),
        createdAt: now,
        lastSeenAt: now,
        revokedAt: null,
      ),
    );
  }
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({
    required this.session,
    required this.remoteHunterId,
    required this.remoteName,
    required this.remotePlayerId,
    required this.remoteGuildId,
    required List<DmDeviceKey> seededRemoteKeys,
  }) : _deviceKeysByHunter = <String, List<DmDeviceKey>>{
         remoteHunterId: [...seededRemoteKeys],
       },
       super(baseUrl: 'http://127.0.0.1:18080', authSession: session);

  final AuthSession session;
  final String remoteHunterId;
  final String remoteName;
  final String remotePlayerId;
  final String remoteGuildId;
  final Map<String, List<DmDeviceKey>> _deviceKeysByHunter;
  final Map<String, List<EncryptedDirectMessage>> _encryptedHistory =
      <String, List<EncryptedDirectMessage>>{};

  List<DmDeviceKey> get registeredLocalKeys =>
      _deviceKeysByHunter[session.hunterId] ?? const <DmDeviceKey>[];

  @override
  Future<List<DmDeviceKey>> listDirectMessageDeviceKeys({
    required String hunterId,
  }) async {
    return List<DmDeviceKey>.unmodifiable(
      _deviceKeysByHunter[hunterId] ?? const <DmDeviceKey>[],
    );
  }

  @override
  Future<Map<String, List<DmDeviceKey>>> listDirectMessageDeviceKeysBatch({
    required List<String> hunterIds,
  }) async {
    final grouped = <String, List<DmDeviceKey>>{};
    for (final hunterId in hunterIds) {
      grouped[hunterId] = List<DmDeviceKey>.unmodifiable(
        _deviceKeysByHunter[hunterId] ?? const <DmDeviceKey>[],
      );
    }
    return grouped;
  }

  @override
  Future<DmDeviceKey> registerDirectMessageDeviceKey({
    required String deviceId,
    String? deviceLabel,
    required String signingPublicKey,
    required String encryptionPublicKey,
  }) async {
    final now = DateTime.parse('2026-03-09T08:00:00Z');
    final registered = DmDeviceKey(
      id: 'local-key-$deviceId',
      hunterId: session.hunterId,
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      signingPublicKey: signingPublicKey,
      encryptionPublicKey: encryptionPublicKey,
      createdAt: now,
      lastSeenAt: now,
      revokedAt: null,
    );
    _deviceKeysByHunter[session.hunterId] = [registered];
    return registered;
  }

  @override
  Future<List<EncryptedDirectMessage>> getEncryptedDirectMessageHistory({
    required String counterpartHunterId,
    int limit = 50,
    int? beforeMs,
  }) async {
    final history = _encryptedHistory[counterpartHunterId] ?? const [];
    return List<EncryptedDirectMessage>.unmodifiable(history.take(limit));
  }

  @override
  Future<EncryptedDirectMessage> persistEncryptedDirectMessage({
    required String recipientHunterId,
    required String senderDeviceId,
    required String recipientDeviceId,
    String? clientMessageId,
    String? protocolVersion,
    required String ciphertext,
    required String nonce,
    int? sentAtMs,
  }) async {
    final sentAt = DateTime.fromMillisecondsSinceEpoch(
      sentAtMs ?? 0,
      isUtc: true,
    );
    final saved = EncryptedDirectMessage(
      id: 'enc-${clientMessageId ?? '1'}',
      senderHunterId: session.hunterId,
      recipientHunterId: recipientHunterId,
      counterpartHunterId: remoteHunterId,
      counterpartName: remoteName,
      counterpartPlayerId: remotePlayerId,
      counterpartGuildId: remoteGuildId,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
      clientMessageId: clientMessageId ?? 'client',
      protocolVersion: protocolVersion ?? DmE2eeService.protocolVersion,
      ciphertext: ciphertext,
      nonce: nonce,
      sentAt: sentAt,
      sentAtMs: sentAtMs ?? sentAt.millisecondsSinceEpoch,
      encryptionMode: DmE2eeService.encryptedMode,
    );
    _encryptedHistory.putIfAbsent(
      recipientHunterId,
      () => <EncryptedDirectMessage>[],
    );
    _encryptedHistory[recipientHunterId]!.add(saved);
    return saved;
  }
}
