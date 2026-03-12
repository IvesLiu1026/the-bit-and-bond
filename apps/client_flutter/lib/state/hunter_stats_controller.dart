import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/models/models.dart';
import 'providers.dart';

final hunterStatsControllerProvider =
    StateNotifierProvider<
      HunterStatsController,
      AsyncValue<HunterStatsSummary?>
    >((ref) {
      final api = ref.watch(apiClientProvider);
      final session = ref.watch(authSessionProvider);
      return HunterStatsController(api: api, hunterId: session?.hunterId)
        ..load();
    });

class HunterStatsController
    extends StateNotifier<AsyncValue<HunterStatsSummary?>> {
  HunterStatsController({required ApiClient api, required String? hunterId})
    : _api = api,
      _hunterId = hunterId,
      super(const AsyncValue.loading());

  final ApiClient _api;
  final String? _hunterId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    await refresh();
  }

  Future<void> refresh() async {
    final hunterId = _hunterId?.trim();
    if (hunterId == null || hunterId.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final stats = await _api.getHunterStats(hunterId: hunterId);
      state = AsyncValue.data(stats);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
