import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/quests/models.dart';
import '../auth/auth_session.dart';
import '../network/api_client.dart';

abstract interface class DmSecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterDmSecureStore implements DmSecureStore {
  const FlutterDmSecureStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }
}

class DmLocalDeviceIdentity {
  const DmLocalDeviceIdentity({
    required this.deviceId,
    required this.deviceLabel,
    required this.signingPrivateKey,
    required this.signingPublicKey,
    required this.encryptionPrivateKey,
    required this.encryptionPublicKey,
  });

  final String deviceId;
  final String deviceLabel;
  final String signingPrivateKey;
  final String signingPublicKey;
  final String encryptionPrivateKey;
  final String encryptionPublicKey;

  factory DmLocalDeviceIdentity.fromJson(Map<String, dynamic> json) {
    return DmLocalDeviceIdentity(
      deviceId: json['device_id'] as String,
      deviceLabel: json['device_label'] as String? ?? 'bitbond-device',
      signingPrivateKey: json['signing_private_key'] as String,
      signingPublicKey: json['signing_public_key'] as String,
      encryptionPrivateKey: json['encryption_private_key'] as String,
      encryptionPublicKey: json['encryption_public_key'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_label': deviceLabel,
      'signing_private_key': signingPrivateKey,
      'signing_public_key': signingPublicKey,
      'encryption_private_key': encryptionPrivateKey,
      'encryption_public_key': encryptionPublicKey,
    };
  }
}

class DmThreadSecuritySnapshot {
  const DmThreadSecuritySnapshot({
    required this.counterpartHunterId,
    required this.threadMode,
    required this.localIdentity,
    required this.peerDeviceKeys,
  });

  final String counterpartHunterId;
  final String threadMode;
  final DmLocalDeviceIdentity? localIdentity;
  final List<DmDeviceKey> peerDeviceKeys;

  String? get localDeviceId => localIdentity?.deviceId;
  bool get localIdentityReady => localIdentity != null;
  bool get peerReady => peerDeviceKeys.isNotEmpty;
  bool get canEncryptNewMessages => localIdentityReady && peerReady;
  bool get isEncryptedThread => threadMode == DmE2eeService.encryptedMode;

  DmDeviceKey? get preferredPeerKey {
    if (peerDeviceKeys.isEmpty) {
      return null;
    }
    final sorted = [...peerDeviceKeys]
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    return sorted.first;
  }

  DmThreadSecuritySnapshot copyWith({
    String? threadMode,
    DmLocalDeviceIdentity? localIdentity,
    List<DmDeviceKey>? peerDeviceKeys,
  }) {
    return DmThreadSecuritySnapshot(
      counterpartHunterId: counterpartHunterId,
      threadMode: threadMode ?? this.threadMode,
      localIdentity: localIdentity ?? this.localIdentity,
      peerDeviceKeys: peerDeviceKeys ?? this.peerDeviceKeys,
    );
  }
}

class _DmPeerKeyCacheEntry {
  const _DmPeerKeyCacheEntry({required this.keys, required this.fetchedAt});

  final List<DmDeviceKey> keys;
  final DateTime fetchedAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(fetchedAt) <= ttl;
}

class DmE2eeService {
  DmE2eeService({required ApiClient api, required DmSecureStore store})
    : _api = api,
      _store = store;

  static const String encryptedMode = 'encrypted';
  static const String plaintextMode = 'plaintext';
  static const String protocolVersion = 'dm-e2ee-v1';
  static const int _nonceBytesLength = 12;
  static const String _storagePrefix = 'the_bit_and_bond_dm_e2ee_v1';
  static const Duration _peerKeyCacheTtl = Duration(seconds: 45);

  final ApiClient _api;
  final DmSecureStore _store;
  final Ed25519 _ed25519 = Ed25519();
  final X25519 _x25519 = X25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Random _random = Random.secure();
  final Map<String, DmLocalDeviceIdentity> _identityCache = {};
  final Map<String, _DmPeerKeyCacheEntry> _peerKeyCache = {};
  final Set<String> _registrationCheckedHunters = {};

  Future<DmLocalDeviceIdentity?> warmUp(AuthSession? session) {
    if (session == null) {
      return Future.value(null);
    }
    return ensureLocalIdentity(session);
  }

  Future<DmLocalDeviceIdentity> ensureLocalIdentity(AuthSession session) async {
    final cached = _identityCache[session.hunterId];
    if (cached != null) {
      await _ensureRegistered(session, cached);
      return cached;
    }

    final storageKey = _identityStorageKey(session.hunterId);
    final raw = await _store.read(storageKey);
    if (raw != null && raw.isNotEmpty) {
      final parsed = DmLocalDeviceIdentity.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _identityCache[session.hunterId] = parsed;
      await _ensureRegistered(session, parsed);
      return parsed;
    }

    final signingKeyPair = await _ed25519.newKeyPair();
    final signingPublicKey = await signingKeyPair.extractPublicKey();
    final signingPrivateBytes = await signingKeyPair.extractPrivateKeyBytes();

    final encryptionKeyPair = await _x25519.newKeyPair();
    final encryptionPublicKey = await encryptionKeyPair.extractPublicKey();
    final encryptionPrivateBytes = await encryptionKeyPair
        .extractPrivateKeyBytes();

    final identity = DmLocalDeviceIdentity(
      deviceId: _buildDeviceId(session.hunterId),
      deviceLabel: _defaultDeviceLabel(),
      signingPrivateKey: base64Encode(signingPrivateBytes),
      signingPublicKey: base64Encode(signingPublicKey.bytes),
      encryptionPrivateKey: base64Encode(encryptionPrivateBytes),
      encryptionPublicKey: base64Encode(encryptionPublicKey.bytes),
    );
    await _store.write(storageKey, jsonEncode(identity.toJson()));
    _identityCache[session.hunterId] = identity;
    await _ensureRegistered(session, identity);
    return identity;
  }

  Future<DmThreadSecuritySnapshot> resolveThreadSecurity({
    required AuthSession session,
    required String counterpartHunterId,
    String threadMode = plaintextMode,
    bool forceRefresh = false,
  }) async {
    final map = await resolveThreadSecurityBatch(
      session: session,
      counterpartHunterIds: <String>[counterpartHunterId],
      threadModeByCounterpart: <String, String>{counterpartHunterId: threadMode},
      forceRefresh: forceRefresh,
    );
    return map[counterpartHunterId] ??
        DmThreadSecuritySnapshot(
          counterpartHunterId: counterpartHunterId,
          threadMode: threadMode,
          localIdentity: _identityCache[session.hunterId],
          peerDeviceKeys: const <DmDeviceKey>[],
        );
  }

  Future<Map<String, DmThreadSecuritySnapshot>> resolveThreadSecurityBatch({
    required AuthSession session,
    required Iterable<String> counterpartHunterIds,
    Map<String, String> threadModeByCounterpart = const <String, String>{},
    bool forceRefresh = false,
  }) async {
    DmLocalDeviceIdentity? localIdentity;
    try {
      localIdentity = await ensureLocalIdentity(session);
    } catch (_) {
      localIdentity = _identityCache[session.hunterId];
    }

    final orderedIds = counterpartHunterIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (orderedIds.isEmpty) {
      return const <String, DmThreadSecuritySnapshot>{};
    }

    final byCounterpart = <String, List<DmDeviceKey>>{};
    final pendingFetch = <String>[];
    for (final counterpartId in orderedIds) {
      final cacheKey = _peerCacheKey(
        selfHunterId: session.hunterId,
        counterpartHunterId: counterpartId,
      );
      final cached = _peerKeyCache[cacheKey];
      if (!forceRefresh && cached != null) {
        byCounterpart[counterpartId] = cached.keys;
        if (!cached.isFresh(_peerKeyCacheTtl)) {
          pendingFetch.add(counterpartId);
        }
        continue;
      }
      pendingFetch.add(counterpartId);
    }

    if (pendingFetch.isNotEmpty) {
      try {
        final remote = await _api.listDirectMessageDeviceKeysBatch(
          hunterIds: pendingFetch,
        );
        final fetchedAt = DateTime.now();
        for (final counterpartId in pendingFetch) {
          final keys = [...(remote[counterpartId] ?? const <DmDeviceKey>[])]
            ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
          byCounterpart[counterpartId] = keys;
          _peerKeyCache[_peerCacheKey(
            selfHunterId: session.hunterId,
            counterpartHunterId: counterpartId,
          )] = _DmPeerKeyCacheEntry(keys: keys, fetchedAt: fetchedAt);
        }
      } catch (_) {
        for (final counterpartId in pendingFetch) {
          byCounterpart.putIfAbsent(counterpartId, () {
            final cached = _peerKeyCache[_peerCacheKey(
              selfHunterId: session.hunterId,
              counterpartHunterId: counterpartId,
            )];
            return cached?.keys ?? const <DmDeviceKey>[];
          });
        }
      }
    }

    final snapshots = <String, DmThreadSecuritySnapshot>{};
    for (final counterpartId in orderedIds) {
      snapshots[counterpartId] = DmThreadSecuritySnapshot(
        counterpartHunterId: counterpartId,
        threadMode: threadModeByCounterpart[counterpartId] ?? plaintextMode,
        localIdentity: localIdentity,
        peerDeviceKeys: byCounterpart[counterpartId] ?? const <DmDeviceKey>[],
      );
    }
    return snapshots;
  }

  Map<String, DmThreadSecuritySnapshot> cachedThreadSecuritySnapshots({
    required AuthSession session,
    required Iterable<String> counterpartHunterIds,
    Map<String, String> threadModeByCounterpart = const <String, String>{},
  }) {
    final localIdentity = _identityCache[session.hunterId];
    final snapshots = <String, DmThreadSecuritySnapshot>{};
    for (final counterpartId in counterpartHunterIds) {
      final normalized = counterpartId.trim();
      if (normalized.isEmpty) {
        continue;
      }
      final cached = _peerKeyCache[_peerCacheKey(
        selfHunterId: session.hunterId,
        counterpartHunterId: normalized,
      )];
      snapshots[normalized] = DmThreadSecuritySnapshot(
        counterpartHunterId: normalized,
        threadMode: threadModeByCounterpart[normalized] ?? plaintextMode,
        localIdentity: localIdentity,
        peerDeviceKeys: cached?.keys ?? const <DmDeviceKey>[],
      );
    }
    return snapshots;
  }

  void invalidateThreadSecurityCache({
    required String selfHunterId,
    required String counterpartHunterId,
  }) {
    _peerKeyCache.remove(_peerCacheKey(
      selfHunterId: selfHunterId,
      counterpartHunterId: counterpartHunterId,
    ));
  }

  String _peerCacheKey({
    required String selfHunterId,
    required String counterpartHunterId,
  }) {
    return '$selfHunterId|$counterpartHunterId';
  }

  Future<List<DirectMessage>> loadEncryptedConversation({
    required AuthSession session,
    required DmThreadSecuritySnapshot security,
    required String counterpartHunterId,
    int limit = 80,
  }) async {
    if (security.localIdentity == null) {
      return const <DirectMessage>[];
    }
    if (!security.isEncryptedThread && !security.peerReady) {
      return const <DirectMessage>[];
    }

    final history = await _api.getEncryptedDirectMessageHistory(
      counterpartHunterId: counterpartHunterId,
      limit: limit,
    );

    final decrypted = <DirectMessage>[];
    for (final message in history) {
      decrypted.add(
        await _decryptEnvelope(
          session: session,
          security: security,
          message: message,
        ),
      );
    }
    return decrypted;
  }

  Future<DirectMessage> sendEncryptedMessage({
    required AuthSession session,
    required DmThreadSecuritySnapshot security,
    required String counterpartHunterId,
    required String counterpartName,
    required String counterpartPlayerId,
    required String counterpartGuildId,
    required String content,
    required String clientMessageId,
    required DateTime sentAt,
  }) async {
    final localIdentity = security.localIdentity;
    final peerKey = security.preferredPeerKey;
    if (localIdentity == null || peerKey == null) {
      throw StateError('Encrypted DM is not ready on this thread yet');
    }

    final encrypted = await _encryptText(
      plaintext: content,
      localIdentity: localIdentity,
      peerKey: peerKey,
    );

    final saved = await _api.persistEncryptedDirectMessage(
      recipientHunterId: counterpartHunterId,
      senderDeviceId: localIdentity.deviceId,
      recipientDeviceId: peerKey.deviceId,
      clientMessageId: clientMessageId,
      protocolVersion: protocolVersion,
      ciphertext: encrypted.$1,
      nonce: encrypted.$2,
      sentAtMs: sentAt.millisecondsSinceEpoch,
    );

    return DirectMessage(
      id: saved.id,
      senderHunterId: saved.senderHunterId,
      recipientHunterId: saved.recipientHunterId,
      counterpartHunterId: saved.counterpartHunterId,
      counterpartName: counterpartName,
      counterpartPlayerId: counterpartPlayerId,
      counterpartGuildId: counterpartGuildId,
      senderName: _selfDisplayName(session),
      clientMessageId: saved.clientMessageId,
      content: content,
      sentAt: saved.sentAt,
      sentAtMs: saved.sentAtMs,
      encryptionMode: encryptedMode,
    );
  }

  Future<void> _ensureRegistered(
    AuthSession session,
    DmLocalDeviceIdentity identity,
  ) async {
    if (_registrationCheckedHunters.contains(session.hunterId)) {
      return;
    }
    final remoteKeys = await _api.listDirectMessageDeviceKeys(
      hunterId: session.hunterId,
    );
    final existing = _findDeviceKey(remoteKeys, identity.deviceId);
    if (existing == null ||
        existing.signingPublicKey != identity.signingPublicKey ||
        existing.encryptionPublicKey != identity.encryptionPublicKey) {
      await _api.registerDirectMessageDeviceKey(
        deviceId: identity.deviceId,
        deviceLabel: identity.deviceLabel,
        signingPublicKey: identity.signingPublicKey,
        encryptionPublicKey: identity.encryptionPublicKey,
      );
    }
    _registrationCheckedHunters.add(session.hunterId);
  }

  Future<(String, String)> _encryptText({
    required String plaintext,
    required DmLocalDeviceIdentity localIdentity,
    required DmDeviceKey peerKey,
  }) async {
    final secretKey = await _deriveConversationKey(
      localPrivateKey: localIdentity.encryptionPrivateKey,
      localPublicKey: localIdentity.encryptionPublicKey,
      remotePublicKey: peerKey.encryptionPublicKey,
      senderDeviceId: localIdentity.deviceId,
      recipientDeviceId: peerKey.deviceId,
    );
    final nonceBytes = _newNonce();
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonceBytes,
    );
    final payload = jsonEncode({
      'ct': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
    return (payload, base64Encode(secretBox.nonce));
  }

  Future<DirectMessage> _decryptEnvelope({
    required AuthSession session,
    required DmThreadSecuritySnapshot security,
    required EncryptedDirectMessage message,
  }) async {
    final localIdentity = security.localIdentity;
    if (localIdentity == null) {
      return _encryptedFallbackMessage(
        session: session,
        message: message,
        failed: true,
      );
    }

    final remoteDeviceId = message.senderHunterId == session.hunterId
        ? message.recipientDeviceId
        : message.senderDeviceId;
    final remoteKey = _findDeviceKey(security.peerDeviceKeys, remoteDeviceId);
    if (remoteKey == null) {
      return _encryptedFallbackMessage(
        session: session,
        message: message,
        failed: true,
      );
    }

    try {
      final secretKey = await _deriveConversationKey(
        localPrivateKey: localIdentity.encryptionPrivateKey,
        localPublicKey: localIdentity.encryptionPublicKey,
        remotePublicKey: remoteKey.encryptionPublicKey,
        senderDeviceId: message.senderDeviceId,
        recipientDeviceId: message.recipientDeviceId,
      );
      final payload = jsonDecode(message.ciphertext) as Map<String, dynamic>;
      final ciphertext = base64Decode(payload['ct'] as String);
      final mac = base64Decode(payload['mac'] as String);
      final nonce = base64Decode(message.nonce);
      final decryptedBytes = await _aesGcm.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
      );
      return DirectMessage(
        id: message.id,
        senderHunterId: message.senderHunterId,
        recipientHunterId: message.recipientHunterId,
        counterpartHunterId: message.counterpartHunterId,
        counterpartName: message.counterpartName,
        counterpartPlayerId: message.counterpartPlayerId,
        counterpartGuildId: message.counterpartGuildId,
        senderName: message.senderHunterId == session.hunterId
            ? _selfDisplayName(session)
            : message.counterpartName,
        clientMessageId: message.clientMessageId,
        content: utf8.decode(decryptedBytes),
        sentAt: message.sentAt,
        sentAtMs: message.sentAtMs,
        encryptionMode: message.encryptionMode,
      );
    } catch (_) {
      return _encryptedFallbackMessage(
        session: session,
        message: message,
        failed: true,
      );
    }
  }

  DirectMessage _encryptedFallbackMessage({
    required AuthSession session,
    required EncryptedDirectMessage message,
    required bool failed,
  }) {
    return DirectMessage(
      id: message.id,
      senderHunterId: message.senderHunterId,
      recipientHunterId: message.recipientHunterId,
      counterpartHunterId: message.counterpartHunterId,
      counterpartName: message.counterpartName,
      counterpartPlayerId: message.counterpartPlayerId,
      counterpartGuildId: message.counterpartGuildId,
      senderName: message.senderHunterId == session.hunterId
          ? _selfDisplayName(session)
          : message.counterpartName,
      clientMessageId: message.clientMessageId,
      content: '',
      sentAt: message.sentAt,
      sentAtMs: message.sentAtMs,
      encryptionMode: message.encryptionMode,
      decryptionFailed: failed,
    );
  }

  Future<SecretKey> _deriveConversationKey({
    required String localPrivateKey,
    required String localPublicKey,
    required String remotePublicKey,
    required String senderDeviceId,
    required String recipientDeviceId,
  }) async {
    final localKeyPair = SimpleKeyPairData(
      base64Decode(localPrivateKey),
      publicKey: SimplePublicKey(
        base64Decode(localPublicKey),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
    final remoteKey = SimplePublicKey(
      base64Decode(remotePublicKey),
      type: KeyPairType.x25519,
    );
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: remoteKey,
    );
    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode('$protocolVersion|$senderDeviceId|$recipientDeviceId'),
      info: utf8.encode('the-bit-and-bond-dm-text'),
    );
  }

  DmDeviceKey? _findDeviceKey(List<DmDeviceKey> keys, String deviceId) {
    for (final key in keys) {
      if (key.deviceId == deviceId) {
        return key;
      }
    }
    return null;
  }

  String _identityStorageKey(String hunterId) =>
      '$_storagePrefix:$hunterId:identity';

  String _buildDeviceId(String hunterId) {
    final suffix = hunterId.length <= 6
        ? hunterId
        : hunterId.substring(hunterId.length - 6);
    final seed = List<int>.generate(
      8,
      (_) => _random.nextInt(256),
      growable: false,
    );
    return 'bb-${_platformSeed()}-$suffix-${base64UrlEncode(seed).replaceAll('=', '')}';
  }

  String _defaultDeviceLabel() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios-device',
    TargetPlatform.android => 'android-device',
    TargetPlatform.macOS => 'mac-device',
    TargetPlatform.windows => 'windows-device',
    TargetPlatform.linux => 'linux-device',
    TargetPlatform.fuchsia => 'fuchsia-device',
  };

  String _platformSeed() {
    if (kIsWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'mac',
      TargetPlatform.windows => 'win',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  String _selfDisplayName(AuthSession session) {
    final displayName = session.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return 'You';
  }

  List<int> _newNonce() {
    return List<int>.generate(
      _nonceBytesLength,
      (_) => _random.nextInt(256),
      growable: false,
    );
  }
}
