part of 'api_client.dart';

Future<List<HunterProfile>> _apiClientListHunters(ApiClient api) async {
  final data = await api._authedGet(
    '/api/v1/hunters',
    const {},
    role: _AuthRole.owner,
  );
  return (data as List)
      .map((item) => HunterProfile.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<List<HunterProfile>> _apiClientListGuildHunters(ApiClient api) async {
  final data = await api._authedGet(
    '/api/v1/hunters/roster',
    const {},
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => HunterProfile.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<HunterProfile> _apiClientCreateHunter(
  ApiClient api, {
  required String name,
  required String avatarType,
  required String pinCode,
}) async {
  final data = await api._authedPost('/api/v1/hunters', {
    'name': name.trim(),
    'avatar_type': avatarType.trim(),
    'pin_code': pinCode.trim(),
  }, role: _AuthRole.owner);
  return HunterProfile.fromJson(data as Map<String, dynamic>);
}

Future<HunterProfile> _apiClientResetHunterPin(
  ApiClient api, {
  required String hunterId,
  required String pinCode,
}) async {
  final data = await api._authedPatch('/api/v1/hunters/$hunterId/pin', {
    'pin_code': pinCode.trim(),
  }, role: _AuthRole.owner);
  return HunterProfile.fromJson(data as Map<String, dynamic>);
}

Future<HunterProfile> _apiClientGetHunterMe(ApiClient api) async {
  final data = await api._authedGet(
    '/api/v1/hunters/me',
    const {},
    role: _AuthRole.any,
  );
  return HunterProfile.fromJson(data as Map<String, dynamic>);
}

Future<HunterStatsSummary> _apiClientGetHunterStats(
  ApiClient api, {
  required String hunterId,
}) async {
  final data = await api._authedGet(
    '/api/v1/hunters/$hunterId/stats',
    const {},
    role: _AuthRole.any,
  );
  return HunterStatsSummary.fromJson(data as Map<String, dynamic>);
}

HunterProfile _apiClientResolveHunterSelection(
  List<HunterProfile> hunters,
  String? hunterId,
) {
  if (hunterId == null || hunterId.trim().isEmpty) {
    return hunters.first;
  }
  final normalized = hunterId.trim();
  for (final hunter in hunters) {
    if (hunter.id == normalized) {
      return hunter;
    }
  }
  return hunters.first;
}
