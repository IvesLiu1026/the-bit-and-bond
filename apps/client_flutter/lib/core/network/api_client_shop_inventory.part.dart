part of 'api_client.dart';

Future<List<GuildShopItem>> _apiClientListShopItems(
  ApiClient api, {
  bool includeInactive = false,
}) async {
  final query = <String, String>{};
  if (includeInactive) {
    query['include_inactive'] = 'true';
  }
  final data = await api._authedGet(
    '/api/v1/shop/items',
    query,
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => GuildShopItem.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<ShopPurchaseResult> _apiClientBuyShopItem(
  ApiClient api, {
  required String itemId,
  required String idempotencyKey,
}) async {
  final data = await api._authedPost('/api/v1/shop/buy/$itemId', {
    'idempotency_key': idempotencyKey,
  }, role: _AuthRole.any);
  return ShopPurchaseResult.fromJson(data as Map<String, dynamic>);
}

Future<GuildShopItem> _apiClientCreateShopItem(
  ApiClient api, {
  required String name,
  String? description,
  required int costCoins,
  required String iconTag,
}) async {
  final data = await api._authedPost('/api/v1/shop/items', {
    'name': name,
    'description': description,
    'cost_coins': costCoins,
    'icon_tag': iconTag,
  }, role: _AuthRole.owner);
  return GuildShopItem.fromJson(data as Map<String, dynamic>);
}

Future<GuildShopItem> _apiClientUpdateShopItem(
  ApiClient api, {
  required String itemId,
  required String name,
  String? description,
  required int costCoins,
  required String iconTag,
}) async {
  final data = await api._authedPut('/api/v1/shop/items/$itemId', {
    'name': name,
    'description': description,
    'cost_coins': costCoins,
    'icon_tag': iconTag,
  }, role: _AuthRole.owner);
  return GuildShopItem.fromJson(data as Map<String, dynamic>);
}

Future<GuildShopItem> _apiClientDeactivateShopItem(
  ApiClient api, {
  required String itemId,
}) async {
  final data = await api._authedDelete(
    '/api/v1/shop/items/$itemId',
    role: _AuthRole.owner,
  );
  return GuildShopItem.fromJson(data as Map<String, dynamic>);
}

Future<List<InventoryItem>> _apiClientListInventory(ApiClient api) async {
  final data = await api._authedGet(
    '/api/v1/inventory',
    const {},
    role: _AuthRole.any,
  );
  return (data as List)
      .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<InventoryUseResult> _apiClientUseInventoryItem(
  ApiClient api, {
  required String itemId,
}) async {
  final data = await api._authedPost(
    '/api/v1/inventory/use/$itemId',
    const {},
    role: _AuthRole.any,
  );
  return InventoryUseResult.fromJson(data as Map<String, dynamic>);
}

Future<RealtimeWsTicket> _apiClientIssueRealtimeTicket(ApiClient api) async {
  final data = await api._authedPost(
    '/api/v1/realtime/ticket',
    const {},
    role: _AuthRole.any,
  );
  return RealtimeWsTicket.fromJson(data as Map<String, dynamic>);
}
