part of 'api_client.dart';

Future<List<MediaAssetItem>> _apiClientListVaultMedia(
  ApiClient api, {
  required int limit,
}) async {
  final data = await api._authedGet('/api/v1/media/vault', <String, String>{
    'limit': '$limit',
  }, role: _AuthRole.any);
  return (data as List)
      .map((item) => MediaAssetItem.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<MediaAssetItem> _apiClientUploadVaultMedia(
  ApiClient api, {
  required MediaUpload upload,
  String? caption,
  required bool includeInDump,
}) async {
  final preparedUpload = _prepareMediaUpload(upload);
  http.MultipartRequest buildRequest(String token) {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${api.baseUrl}/api/v1/media/vault/upload'),
          )
          ..persistentConnection = false
          ..headers.addAll(api._bearerHeaders(token))
          ..fields['include_in_dump'] = includeInDump ? 'true' : 'false'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              preparedUpload.bytes,
              filename: preparedUpload.filename,
              contentType: preparedUpload.contentType,
            ),
          );

    final normalizedCaption = caption?.trim();
    if (normalizedCaption != null && normalizedCaption.isNotEmpty) {
      request.fields['caption'] = normalizedCaption;
    }
    return request;
  }

  final response = await _sendMultipartWithRetry(
    api,
    role: _AuthRole.any,
    requestBuilder: buildRequest,
  );
  final data = api._parseResponse(response);
  return MediaAssetItem.fromJson(data as Map<String, dynamic>);
}

Future<MediaOnceDelivery> _apiClientSendOnceMedia(
  ApiClient api, {
  required String recipientPlayerId,
  required MediaUpload upload,
  String? caption,
  int? ttlSeconds,
  MediaEncryptionMeta? encryption,
}) async {
  final preparedUpload = _prepareMediaUpload(upload);
  http.MultipartRequest buildRequest(String token) {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${api.baseUrl}/api/v1/media/once/send'),
          )
          ..persistentConnection = false
          ..headers.addAll(api._bearerHeaders(token))
          ..fields['recipient_player_id'] = recipientPlayerId.trim()
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              preparedUpload.bytes,
              filename: preparedUpload.filename,
              contentType: preparedUpload.contentType,
            ),
          );

    final normalizedCaption = caption?.trim();
    if (normalizedCaption != null && normalizedCaption.isNotEmpty) {
      request.fields['caption'] = normalizedCaption;
    }
    if (ttlSeconds != null) {
      request.fields['ttl_seconds'] = '$ttlSeconds';
    }
    final encryptionFields =
        (encryption ?? MediaEncryptionMeta(mode: 'plaintext'))
            .toMultipartFields();
    request.fields.addAll(encryptionFields);
    return request;
  }

  final response = await _sendMultipartWithRetry(
    api,
    role: _AuthRole.any,
    requestBuilder: buildRequest,
  );
  final data = api._parseResponse(response);
  return MediaOnceDelivery.fromJson(data as Map<String, dynamic>);
}

Future<List<int>> _apiClientFetchMediaBytes(
  ApiClient api, {
  required String contentPath,
}) async {
  final uri = Uri.parse(api.resolveMediaUrl(contentPath));
  final response = await api._authedRequestResponse(
    _AuthRole.any,
    (token) => api._httpClient.get(uri, headers: api._bearerHeaders(token)),
    timeout: const Duration(seconds: 20),
    retryTransportErrors: true,
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    api._parseResponse(response);
  }
  return response.bodyBytes;
}

Future<List<MediaOnceDelivery>> _apiClientListOnceInbox(
  ApiClient api, {
  required int limit,
}) async {
  final data = await api._authedGet(
    '/api/v1/media/once/inbox',
    <String, String>{'limit': '$limit'},
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => MediaOnceDelivery.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<MediaOnceOpenResult> _apiClientOpenOnceMedia(
  ApiClient api, {
  required String deliveryId,
}) async {
  final data = await api._authedPost(
    '/api/v1/media/once/$deliveryId/open',
    const {},
    role: _AuthRole.any,
  );
  return MediaOnceOpenResult.fromJson(data as Map<String, dynamic>);
}

Future<PhotoDumpExportItem> _apiClientCreatePhotoDumpExport(
  ApiClient api, {
  required List<String> assetIds,
  String? title,
  String? style,
}) async {
  final payload = <String, dynamic>{'asset_ids': assetIds};
  final normalizedTitle = title?.trim();
  if (normalizedTitle != null && normalizedTitle.isNotEmpty) {
    payload['title'] = normalizedTitle;
  }
  final normalizedStyle = style?.trim();
  if (normalizedStyle != null && normalizedStyle.isNotEmpty) {
    payload['style'] = normalizedStyle;
  }
  final data = await api._authedPost(
    '/api/v1/media/photo-dumps/export',
    payload,
    role: _AuthRole.any,
  );
  return PhotoDumpExportItem.fromJson(data as Map<String, dynamic>);
}

Future<List<PhotoDumpExportItem>> _apiClientListPhotoDumpExports(
  ApiClient api, {
  required int limit,
}) async {
  final data = await api._authedGet(
    '/api/v1/media/photo-dumps',
    <String, String>{'limit': '$limit'},
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => PhotoDumpExportItem.fromJson(item as Map<String, dynamic>))
      .toList();
}

class _PreparedMediaUpload {
  const _PreparedMediaUpload({
    required this.filename,
    required this.bytes,
    required this.contentType,
  });

  final String filename;
  final List<int> bytes;
  final MediaType contentType;
}

_PreparedMediaUpload _prepareMediaUpload(MediaUpload upload) {
  final bytes = upload.bytes;
  final rawFilename = upload.filename.trim();
  final sanitizedFilename = _sanitizeUploadFilename(rawFilename);
  final normalizedMime =
      _normalizeUploadMime(upload, sanitizedFilename, bytes) ?? 'image/jpeg';
  final normalizedFilename = _ensureUploadFilenameExtension(
    sanitizedFilename,
    normalizedMime,
  );
  final mediaType = _mediaTypeFromMime(normalizedMime);
  return _PreparedMediaUpload(
    filename: normalizedFilename,
    bytes: bytes,
    contentType: mediaType,
  );
}

String _sanitizeUploadFilename(String raw) {
  final source = raw.isEmpty ? 'photo' : raw;
  final collapsed = source.replaceAll(RegExp(r'\s+'), '_');
  final asciiSafe = collapsed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final trimmedDots = asciiSafe.replaceAll(RegExp(r'^\.+|\.+$'), '');
  return trimmedDots.isEmpty ? 'photo' : trimmedDots;
}

String? _normalizeUploadMime(
  MediaUpload upload,
  String filename,
  List<int> bytes,
) {
  final explicit = upload.mimeType?.trim().toLowerCase();
  if (_isSupportedUploadMime(explicit)) {
    return explicit;
  }
  final byFilename = _inferUploadMimeFromFilename(filename);
  if (byFilename != null) {
    return byFilename;
  }
  return _inferUploadMimeFromBytes(bytes);
}

bool _isSupportedUploadMime(String? value) {
  if (value == null || value.isEmpty) {
    return false;
  }
  return value == 'image/jpeg' ||
      value == 'image/jpg' ||
      value == 'image/png' ||
      value == 'image/webp' ||
      value == 'image/heic' ||
      value == 'image/heif';
}

String? _inferUploadMimeFromFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.heic')) {
    return 'image/heic';
  }
  if (lower.endsWith('.heif')) {
    return 'image/heif';
  }
  return null;
}

String? _inferUploadMimeFromBytes(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  if (bytes.length >= 12 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
    if (brand == 'heic' ||
        brand == 'heix' ||
        brand == 'hevc' ||
        brand == 'hevx') {
      return 'image/heic';
    }
    if (brand == 'heif' || brand == 'mif1' || brand == 'msf1') {
      return 'image/heif';
    }
  }
  return null;
}

String _ensureUploadFilenameExtension(String filename, String mime) {
  if (filename.contains('.')) {
    return filename;
  }
  final ext = _extensionFromUploadMime(mime);
  return '$filename.$ext';
}

String _extensionFromUploadMime(String mime) {
  switch (mime) {
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    case 'image/heic':
      return 'heic';
    case 'image/heif':
      return 'heif';
    case 'image/jpg':
    case 'image/jpeg':
    default:
      return 'jpg';
  }
}

MediaType _mediaTypeFromMime(String mime) {
  final normalized = mime.toLowerCase();
  if (normalized == 'image/jpg') {
    return MediaType('image', 'jpeg');
  }
  final parts = normalized.split('/');
  if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
    return MediaType('image', 'jpeg');
  }
  return MediaType(parts.first, parts.last);
}

Future<http.Response> _sendMultipartWithRetry(
  ApiClient api, {
  required _AuthRole role,
  required http.MultipartRequest Function(String token) requestBuilder,
}) async {
  return api._authedRequestResponse(
    role,
    (token) async {
      final streamed = await api._httpClient.send(requestBuilder(token));
      return http.Response.fromStream(streamed);
    },
    timeout: const Duration(seconds: 20),
    retryTransportErrors: true,
  );
}
