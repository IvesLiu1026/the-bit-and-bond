import 'dart:typed_data';

import '../../features/quests/models.dart';

const String _encryptedThreadMode = 'encrypted';

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
  bool get isEncryptedThread => threadMode == _encryptedThreadMode;

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

class DmEncryptedMediaPayload {
  const DmEncryptedMediaPayload({
    required this.cipherBytes,
    required this.encryption,
  });

  final Uint8List cipherBytes;
  final MediaEncryptionMeta encryption;
}
