import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:the_bit_and_bond_client/app/app.dart';
import 'package:the_bit_and_bond_client/core/auth/auth_session.dart';
import 'package:the_bit_and_bond_client/core/network/api_client.dart';
import 'package:the_bit_and_bond_client/core/network/auth_api_client.dart';
import 'package:the_bit_and_bond_client/features/quests/models.dart';
import 'package:the_bit_and_bond_client/features/quests/quest_repository.dart';
import 'package:the_bit_and_bond_client/state/auth_controller.dart';
import 'package:the_bit_and_bond_client/state/inventory_controller.dart';
import 'package:the_bit_and_bond_client/state/progression_controller.dart';
import 'package:the_bit_and_bond_client/state/providers.dart';
import 'package:the_bit_and_bond_client/state/quest_controller.dart';
import 'package:the_bit_and_bond_client/state/social_controller.dart';

void main() {
  testWidgets('Game shell renders tavern HUD and profile dialog', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          questControllerProvider.overrideWith((ref) => _TestQuestController()),
          progressionControllerProvider.overrideWith(
            (ref) => _TestProgressionController(),
          ),
          inventoryControllerProvider.overrideWith(
            (ref) => _TestInventoryController(),
          ),
          socialControllerProvider.overrideWith(
            (ref) => _TestSocialController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('公會任務板'), findsOneWidget);
    expect(find.text('左下固定搖桿可 360 度移動'), findsOneWidget);
    expect(find.text('玩家通行證'), findsNothing);

    await tester.tap(find.text('Lv.2'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('玩家通行證'), findsOneWidget);
    expect(find.textContaining('公會：'), findsOneWidget);
  });

  testWidgets('Game shell dialogs stay stable on phone-sized viewport', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          questControllerProvider.overrideWith((ref) => _TestQuestController()),
          progressionControllerProvider.overrideWith(
            (ref) => _TestProgressionController(),
          ),
          inventoryControllerProvider.overrideWith(
            (ref) => _TestInventoryController(),
          ),
          socialControllerProvider.overrideWith(
            (ref) => _TestSocialController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Lv.2'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('玩家通行證'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Campfire dialog keeps join action visible on phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          questControllerProvider.overrideWith((ref) => _TestQuestController()),
          progressionControllerProvider.overrideWith(
            (ref) => _TestProgressionController(),
          ),
          inventoryControllerProvider.overrideWith(
            (ref) => _TestInventoryController(),
          ),
          socialControllerProvider.overrideWith(
            (ref) => _TestSocialController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('營火聊天'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('營火語音吧台'), findsOneWidget);
    expect(find.text('加入營火'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Inventory dialog keeps action buttons stable on phone viewport',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _TestAuthController()),
            questControllerProvider.overrideWith(
              (ref) => _TestQuestController(),
            ),
            progressionControllerProvider.overrideWith(
              (ref) => _TestProgressionController(),
            ),
            inventoryControllerProvider.overrideWith(
              (ref) => _TestInventoryController(),
            ),
            socialControllerProvider.overrideWith(
              (ref) => _TestSocialController(),
            ),
          ],
          child: const TheBitAndBondApp(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('背包'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('冒險背包'), findsOneWidget);
      expect(find.text('修理工具卷'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Campfire dialog stays stable on landscape phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          questControllerProvider.overrideWith((ref) => _TestQuestController()),
          progressionControllerProvider.overrideWith(
            (ref) => _TestProgressionController(),
          ),
          inventoryControllerProvider.overrideWith(
            (ref) => _TestInventoryController(),
          ),
          socialControllerProvider.overrideWith(
            (ref) => _TestSocialController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('營火聊天'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('營火語音吧台'), findsOneWidget);
    expect(find.text('加入營火'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestQuestController extends QuestController {
  _TestQuestController() : super(repo: _NoopQuestRepository()) {
    state = AsyncValue.data(_sampleQuests);
  }

  static final List<QuestInstance> _sampleQuests = [
    QuestInstance(
      id: 'q-1',
      templateId: 't-1',
      templateTitle: 'Spellbook Study',
      category: QuestCategory.study,
      statCategory: QuestStatCategory.intelligence,
      baseXp: 20,
      baseCoins: 10,
      status: QuestStatus.available,
      dueAt: null,
      updatedAt: DateTime(2026, 3, 4),
    ),
    QuestInstance(
      id: 'q-2',
      templateId: 't-2',
      templateTitle: 'Room Cleanup',
      category: QuestCategory.chore,
      statCategory: QuestStatCategory.strength,
      baseXp: 25,
      baseCoins: 12,
      status: QuestStatus.available,
      dueAt: null,
      updatedAt: DateTime(2026, 3, 4),
    ),
  ];

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> submitQuest(String questInstanceId) async {}
}

class _TestProgressionController extends ProgressionController {
  _TestProgressionController()
    : super(repo: _NoopQuestRepository(), selectedHunterId: _childId) {
    state = AsyncValue.data(
      Progression(
        childMemberId: _childId,
        level: 2,
        xp: 140,
        coins: 35,
        availableQuests: 2,
        submittedQuests: 0,
      ),
    );
  }

  static const String _childId = '00000000-0000-0000-0000-000000000011';

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}
}

class _TestInventoryController extends InventoryController {
  _TestInventoryController() : super(repo: _NoopQuestRepository()) {
    state = AsyncValue.data([
      InventoryItem(
        itemId: 'inventory-1',
        name: '修理工具卷',
        description: '記下今天要修的家具與工具，方便公會長派工。',
        iconTag: 'SCROLL',
        quantity: 1,
        updatedAt: DateTime(2026, 3, 7),
      ),
    ]);
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<InventoryUseResult> useItem({required String itemId}) async {
    return InventoryUseResult(
      itemId: itemId,
      itemName: '修理工具卷',
      remainingQuantity: 0,
      systemMessage: '已使用修理工具卷',
      chatMessageId: 'chat-message-1',
    );
  }
}

class _TestSocialController extends SocialController {
  _TestSocialController()
    : super(
        api: ApiClient(
          baseUrl: 'http://127.0.0.1:18080',
          authSession: const AuthSession(
            accessToken: 'test-token',
            guildId: '00000000-0000-0000-0000-000000000001',
            hunterId: '00000000-0000-0000-0000-000000000011',
            guildRole: GuildRole.member,
          ),
          httpClient: _NeverHttpClient(),
        ),
      ) {
    state = AsyncValue.data(
      SocialSnapshot(
        friends: const [],
        pendingInvites: const [],
        incomingFriendRequests: const [],
        profile: null,
      ),
    );
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}
}

// The test controllers inject state directly and never call into the
// repository. We still provide a valid QuestRepository instance for constructor
// compatibility.
class _NoopQuestRepository extends QuestRepository {
  _NoopQuestRepository()
    : super(
        ApiClient(
          baseUrl: 'http://127.0.0.1:18080',
          authSession: const AuthSession(
            accessToken: 'test-token',
            guildId: '00000000-0000-0000-0000-000000000001',
            hunterId: '00000000-0000-0000-0000-000000000011',
            guildRole: GuildRole.member,
          ),
          httpClient: _NeverHttpClient(),
        ),
      );
}

class _NeverHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw StateError('Network should not be called in widget tests');
  }
}

class _TestAuthController extends AuthController {
  _TestAuthController()
    : super(
        authApi: AuthApiClient(
          baseUrl: 'http://127.0.0.1:18080',
          httpClient: _NeverHttpClient(),
        ),
        storage: const FlutterSecureStorage(),
        restoreOnInit: false,
      ) {
    state = const AsyncValue.data(
      AuthSession(
        accessToken: 'test-token',
        guildId: '00000000-0000-0000-0000-000000000001',
        hunterId: '00000000-0000-0000-0000-000000000011',
        guildRole: GuildRole.member,
      ),
    );
  }

  @override
  Future<void> logout() async {
    state = const AsyncValue.data(null);
  }
}
