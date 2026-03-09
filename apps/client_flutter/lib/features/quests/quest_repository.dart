import '../../core/network/api_client.dart';
import 'models.dart';

class QuestRepository {
  QuestRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<QuestInstance>> fetchQuests() {
    return _apiClient.listQuests();
  }

  Future<QuestInstance> createQuest({
    required String title,
    String? description,
    required int rewardXp,
    required int rewardCoins,
    required QuestStatCategory statCategory,
    QuestCategory category = QuestCategory.chore,
    String? assignedHunterId,
    HabitCadence cadence = HabitCadence.none,
  }) {
    return _apiClient.createQuest(
      title: title,
      description: description,
      rewardXp: rewardXp,
      rewardCoins: rewardCoins,
      statCategory: statCategory,
      category: category,
      assignedHunterId: assignedHunterId,
      cadence: cadence,
    );
  }

  Future<void> submitQuest({
    required String questInstanceId,
    String? proofNote,
    QuestProofUpload? proofMedia,
  }) {
    return _apiClient.submitQuestProof(
      questInstanceId: questInstanceId,
      proofNote: proofNote,
      proofMedia: proofMedia,
    );
  }

  Future<QuestReviewResult> reviewSubmission({
    required String submissionId,
    required bool approve,
    String? hunterId,
    String? reviewNote,
  }) {
    return _apiClient.reviewSubmission(
      submissionId: submissionId,
      approve: approve,
      hunterId: hunterId,
      reviewNote: reviewNote,
    );
  }

  Future<Progression> fetchProgression({String? hunterId}) {
    return _apiClient.getProgression(hunterId: hunterId);
  }

  Future<List<HunterProfile>> fetchHunters() {
    return _apiClient.listHunters();
  }

  Future<List<HunterProfile>> fetchGuildHunters() {
    return _apiClient.listGuildHunters();
  }

  Future<HunterProfile> createHunter({
    required String name,
    required String avatarType,
    required String pinCode,
  }) {
    return _apiClient.createHunter(
      name: name,
      avatarType: avatarType,
      pinCode: pinCode,
    );
  }

  Future<HunterProfile> resetHunterPin({
    required String hunterId,
    required String pinCode,
  }) {
    return _apiClient.resetHunterPin(hunterId: hunterId, pinCode: pinCode);
  }

  Future<List<GuildShopItem>> fetchShopItems({bool includeInactive = false}) {
    return _apiClient.listShopItems(includeInactive: includeInactive);
  }

  Future<ShopPurchaseResult> buyShopItem({
    required String itemId,
    required String idempotencyKey,
  }) {
    return _apiClient.buyShopItem(
      itemId: itemId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<GuildShopItem> createShopItem({
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  }) {
    return _apiClient.createShopItem(
      name: name,
      description: description,
      costCoins: costCoins,
      iconTag: iconTag,
    );
  }

  Future<GuildShopItem> updateShopItem({
    required String itemId,
    required String name,
    String? description,
    required int costCoins,
    required String iconTag,
  }) {
    return _apiClient.updateShopItem(
      itemId: itemId,
      name: name,
      description: description,
      costCoins: costCoins,
      iconTag: iconTag,
    );
  }

  Future<GuildShopItem> deactivateShopItem({required String itemId}) {
    return _apiClient.deactivateShopItem(itemId: itemId);
  }

  Future<List<InventoryItem>> fetchInventoryItems() {
    return _apiClient.listInventory();
  }

  Future<InventoryUseResult> useInventoryItem({required String itemId}) {
    return _apiClient.useInventoryItem(itemId: itemId);
  }
}
