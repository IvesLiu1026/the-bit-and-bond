part of 'models.dart';

class MediaEncryptionMeta {
  MediaEncryptionMeta({
    required this.mode,
    this.protocolVersion,
    this.senderDeviceId,
    this.recipientDeviceId,
    this.nonceBase64,
    this.macBase64,
  });

  final String mode;
  final String? protocolVersion;
  final String? senderDeviceId;
  final String? recipientDeviceId;
  final String? nonceBase64;
  final String? macBase64;

  bool get isEncrypted => mode == 'e2ee';

  factory MediaEncryptionMeta.fromJson(Map<String, dynamic> json) {
    return MediaEncryptionMeta(
      mode: (json['mode'] as String?)?.trim().isNotEmpty == true
          ? (json['mode'] as String).trim().toLowerCase()
          : 'plaintext',
      protocolVersion: json['protocol_version'] as String?,
      senderDeviceId: json['sender_device_id'] as String?,
      recipientDeviceId: json['recipient_device_id'] as String?,
      nonceBase64: json['nonce'] as String?,
      macBase64: json['mac'] as String?,
    );
  }

  Map<String, String> toMultipartFields() {
    final fields = <String, String>{'encryption_mode': mode};
    final protocol = protocolVersion?.trim();
    if (protocol != null && protocol.isNotEmpty) {
      fields['protocol_version'] = protocol;
    }
    final sender = senderDeviceId?.trim();
    if (sender != null && sender.isNotEmpty) {
      fields['sender_device_id'] = sender;
    }
    final recipient = recipientDeviceId?.trim();
    if (recipient != null && recipient.isNotEmpty) {
      fields['recipient_device_id'] = recipient;
    }
    final nonce = nonceBase64?.trim();
    if (nonce != null && nonce.isNotEmpty) {
      fields['encryption_nonce'] = nonce;
    }
    final mac = macBase64?.trim();
    if (mac != null && mac.isNotEmpty) {
      fields['encryption_mac'] = mac;
    }
    return fields;
  }
}

class MediaUpload {
  MediaUpload({required this.filename, required this.bytes, this.mimeType});

  final String filename;
  final List<int> bytes;
  final String? mimeType;
}

class MediaAssetItem {
  MediaAssetItem({
    required this.id,
    required this.guildId,
    required this.ownerHunterId,
    required this.ownerName,
    required this.ownerPlayerId,
    required this.mode,
    this.originalFilename,
    required this.mimeType,
    required this.byteSize,
    this.caption,
    required this.isPhotoDumpReady,
    required this.createdAt,
    this.expiresAt,
    required this.contentPath,
  });

  final String id;
  final String guildId;
  final String ownerHunterId;
  final String ownerName;
  final String ownerPlayerId;
  final String mode;
  final String? originalFilename;
  final String mimeType;
  final int byteSize;
  final String? caption;
  final bool isPhotoDumpReady;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String contentPath;

  factory MediaAssetItem.fromJson(Map<String, dynamic> json) {
    return MediaAssetItem(
      id: json['id'] as String,
      guildId: json['guild_id'] as String,
      ownerHunterId: json['owner_hunter_id'] as String,
      ownerName: (json['owner_name'] ?? '') as String,
      ownerPlayerId: (json['owner_player_id'] ?? '') as String,
      mode: (json['mode'] ?? 'vault') as String,
      originalFilename: json['original_filename'] as String?,
      mimeType: (json['mime_type'] ?? 'application/octet-stream') as String,
      byteSize: (json['byte_size'] ?? 0) as int,
      caption: json['caption'] as String?,
      isPhotoDumpReady: json['is_photo_dump_ready'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      contentPath: (json['content_path'] ?? '') as String,
    );
  }
}

class MediaOnceDelivery {
  MediaOnceDelivery({
    required this.id,
    required this.mediaAssetId,
    required this.guildId,
    required this.senderHunterId,
    required this.senderName,
    required this.senderPlayerId,
    required this.recipientHunterId,
    this.caption,
    required this.mimeType,
    required this.createdAt,
    this.expiresAt,
    this.openedAt,
    this.consumedAt,
    required this.remainingViews,
    required this.encryption,
  });

  final String id;
  final String mediaAssetId;
  final String guildId;
  final String senderHunterId;
  final String senderName;
  final String senderPlayerId;
  final String recipientHunterId;
  final String? caption;
  final String mimeType;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? openedAt;
  final DateTime? consumedAt;
  final int remainingViews;
  final MediaEncryptionMeta encryption;

  factory MediaOnceDelivery.fromJson(Map<String, dynamic> json) {
    return MediaOnceDelivery(
      id: json['id'] as String,
      mediaAssetId: json['media_asset_id'] as String,
      guildId: json['guild_id'] as String,
      senderHunterId: json['sender_hunter_id'] as String,
      senderName: (json['sender_name'] ?? '') as String,
      senderPlayerId: (json['sender_player_id'] ?? '') as String,
      recipientHunterId: json['recipient_hunter_id'] as String,
      caption: json['caption'] as String?,
      mimeType: (json['mime_type'] ?? 'application/octet-stream') as String,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      openedAt: json['opened_at'] == null
          ? null
          : DateTime.parse(json['opened_at'] as String),
      consumedAt: json['consumed_at'] == null
          ? null
          : DateTime.parse(json['consumed_at'] as String),
      remainingViews: (json['remaining_views'] ?? 0) as int,
      encryption: json['encryption'] is Map<String, dynamic>
          ? MediaEncryptionMeta.fromJson(
              json['encryption'] as Map<String, dynamic>,
            )
          : MediaEncryptionMeta(mode: 'plaintext'),
    );
  }
}

class MediaOnceOpenResult {
  MediaOnceOpenResult({
    required this.deliveryId,
    required this.mediaAssetId,
    required this.openedAt,
    this.consumedAt,
    required this.contentPath,
    required this.tokenTtlSeconds,
    required this.encryption,
  });

  final String deliveryId;
  final String mediaAssetId;
  final DateTime openedAt;
  final DateTime? consumedAt;
  final String contentPath;
  final int tokenTtlSeconds;
  final MediaEncryptionMeta encryption;

  factory MediaOnceOpenResult.fromJson(Map<String, dynamic> json) {
    return MediaOnceOpenResult(
      deliveryId: json['delivery_id'] as String,
      mediaAssetId: json['media_asset_id'] as String,
      openedAt: DateTime.parse(json['opened_at'] as String),
      consumedAt: json['consumed_at'] == null
          ? null
          : DateTime.parse(json['consumed_at'] as String),
      contentPath: (json['content_path'] ?? '') as String,
      tokenTtlSeconds: (json['token_ttl_seconds'] ?? 45) as int,
      encryption: json['encryption'] is Map<String, dynamic>
          ? MediaEncryptionMeta.fromJson(
              json['encryption'] as Map<String, dynamic>,
            )
          : MediaEncryptionMeta(mode: 'plaintext'),
    );
  }
}

class PhotoDumpExportItem {
  PhotoDumpExportItem({
    required this.id,
    required this.guildId,
    required this.ownerHunterId,
    required this.title,
    required this.style,
    required this.assetCount,
    required this.createdAt,
    required this.assets,
  });

  final String id;
  final String guildId;
  final String ownerHunterId;
  final String title;
  final String style;
  final int assetCount;
  final DateTime createdAt;
  final List<MediaAssetItem> assets;

  factory PhotoDumpExportItem.fromJson(Map<String, dynamic> json) {
    return PhotoDumpExportItem(
      id: json['id'] as String,
      guildId: json['guild_id'] as String,
      ownerHunterId: json['owner_hunter_id'] as String,
      title: (json['title'] ?? '') as String,
      style: (json['style'] ?? 'retro') as String,
      assetCount: (json['asset_count'] ?? 0) as int,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
      assets: (json['assets'] as List<dynamic>? ?? const [])
          .map((item) => MediaAssetItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
