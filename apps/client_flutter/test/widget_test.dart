import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:the_bit_and_bond_client/app/app.dart';
import 'package:the_bit_and_bond_client/core/auth/auth_session.dart';
import 'package:the_bit_and_bond_client/core/network/api_client.dart';
import 'package:the_bit_and_bond_client/core/security/dm_e2ee_service.dart';
import 'package:the_bit_and_bond_client/core/network/auth_api_client.dart';
import 'package:the_bit_and_bond_client/features/quests/models.dart';
import 'package:the_bit_and_bond_client/state/direct_messages_controller.dart';
import 'package:the_bit_and_bond_client/features/quests/quest_repository.dart';
import 'package:the_bit_and_bond_client/state/auth_controller.dart';
import 'package:the_bit_and_bond_client/state/hunter_directory_controller.dart';
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
          directMessagesControllerProvider.overrideWith(
            (ref) => _TestDirectMessagesController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('The Bit and Bond'), findsOneWidget);
    expect(find.textContaining('目前空間：'), findsOneWidget);
    expect(find.textContaining('左下固定搖桿可 360 度移動'), findsOneWidget);
    expect(find.text('玩家通行證'), findsNothing);

    await tester.tap(find.text('Lv.2'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('玩家通行證'), findsOneWidget);
    expect(find.textContaining('家庭：'), findsOneWidget);
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
          directMessagesControllerProvider.overrideWith(
            (ref) => _TestDirectMessagesController(),
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
          directMessagesControllerProvider.overrideWith(
            (ref) => _TestDirectMessagesController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('選單').first);
    await _pumpUi(tester);
    final mainMenuScrollable = find.descendant(
      of: find.byKey(const ValueKey('main_menu_grid')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main_menu_card_voice')),
      220,
      scrollable: mainMenuScrollable,
    );
    await _tapMenuCard(tester, 'voice');
    await _pumpUi(tester);

    expect(find.text('語音房'), findsOneWidget);
    expect(find.text('加入語音房'), findsOneWidget);
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
            directMessagesControllerProvider.overrideWith(
              (ref) => _TestDirectMessagesController(),
            ),
          ],
          child: const TheBitAndBondApp(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('選單').first);
      await _pumpUi(tester);
      final mainMenuScrollable = find.descendant(
        of: find.byKey(const ValueKey('main_menu_grid')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('main_menu_card_bag')),
        220,
        scrollable: mainMenuScrollable,
      );
      await _tapMenuCard(tester, 'bag');
      await _pumpUi(tester);

      expect(find.text('收藏背包'), findsOneWidget);
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
          directMessagesControllerProvider.overrideWith(
            (ref) => _TestDirectMessagesController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('選單').first);
    await _pumpUi(tester);
    final mainMenuScrollable = find.descendant(
      of: find.byKey(const ValueKey('main_menu_grid')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main_menu_card_voice')),
      220,
      scrollable: mainMenuScrollable,
    );
    await _tapMenuCard(tester, 'voice');
    await _pumpUi(tester);

    expect(find.text('語音房'), findsOneWidget);
    expect(find.text('加入語音房'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sandbox floorplan overlay can open on phone viewport', (
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
          directMessagesControllerProvider.overrideWith(
            (ref) => _TestDirectMessagesController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('地圖').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('空間平面圖'), findsOneWidget);
    expect(find.textContaining('俯視模式：'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings dialog can switch language skeleton', (
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
          directMessagesControllerProvider.overrideWith(
            (ref) => _TestDirectMessagesController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('選單').first);
    await _pumpUi(tester);
    final mainMenuScrollable = find.descendant(
      of: find.byKey(const ValueKey('main_menu_grid')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main_menu_card_settings')),
      220,
      scrollable: mainMenuScrollable,
    );
    await _tapMenuCard(tester, 'settings');
    await _pumpUi(tester);

    expect(find.text('系統語言'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('English'));
    await _pumpUi(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('System Language'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Main menu surfaces DM unread badge', (
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
          directMessagesControllerProvider.overrideWith(
            (ref) => _TestDirectMessagesController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('選單').first);
    await _pumpUi(tester);
    final mainMenuScrollable = find.descendant(
      of: find.byKey(const ValueKey('main_menu_grid')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main_menu_card_dm')),
      220,
      scrollable: mainMenuScrollable,
    );

    expect(find.text('2'), findsWidgets);
    expect(find.textContaining('未讀訊息'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DM inbox supports unread sections and search', (
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
          directMessagesControllerProvider.overrideWith(
            (ref) => _TestDirectMessagesController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('選單').first);
    await _pumpUi(tester);
    final mainMenuScrollable = find.descendant(
      of: find.byKey(const ValueKey('main_menu_grid')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main_menu_card_dm')),
      220,
      scrollable: mainMenuScrollable,
    );
    await _tapMenuCard(tester, 'dm');
    await _pumpUi(tester);

    expect(find.text('未讀'), findsOneWidget);
    expect(find.text('Demo Friend'), findsWidgets);
    expect(find.text('Demo Member'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('dm_inbox_search')),
      'friend',
    );
    await _pumpUi(tester);

    expect(find.text('Demo Friend'), findsWidgets);
    expect(find.text('Demo Member'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Habit panel supports catch-up proof and review sort order', (
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
          questControllerProvider.overrideWith(
            (ref) => _TestHabitQuestController(),
          ),
          hunterDirectoryControllerProvider.overrideWith(
            (ref) => _TestHunterDirectoryController(),
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
          directMessagesControllerProvider.overrideWith(
            (ref) => _TestDirectMessagesController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('選單').first);
    await _pumpUi(tester);
    final mainMenuScrollable = find.descendant(
      of: find.byKey(const ValueKey('main_menu_grid')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main_menu_card_habits')),
      220,
      scrollable: mainMenuScrollable,
    );
    await _tapMenuCard(tester, 'habits');
    await _pumpUi(tester);

    expect(find.text('習慣養成板'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('補交完成證明'), 180);
    await _pumpUi(tester);

    final newestFinder = find.byKey(
      const ValueKey('habit_card_active_habit-review-new'),
    );
    final olderFinder = find.byKey(
      const ValueKey('habit_card_active_habit-review-old'),
    );
    expect(newestFinder, findsOneWidget);
    expect(olderFinder, findsOneWidget);
    expect(
      tester.getTopLeft(newestFinder).dy,
      lessThan(tester.getTopLeft(olderFinder).dy),
    );

    await tester.tap(find.text('補交完成證明').first);
    await _pumpUi(tester);
    expect(find.text('提交習慣證明'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('從相簿選擇'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUi(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i += 1) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _tapMenuCard(WidgetTester tester, String id) async {
  final finder = find.byKey(ValueKey('main_menu_card_$id'));
  await tester.ensureVisible(finder);
  final rect = tester.getRect(finder);
  await tester.tapAt(rect.topLeft + const Offset(18, 18));
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
  Future<void> submitQuest(
    String questInstanceId, {
    String? proofNote,
    QuestProofUpload? proofMedia,
  }) async {}
}

class _TestHabitQuestController extends QuestController {
  _TestHabitQuestController() : super(repo: _NoopQuestRepository()) {
    final now = DateTime.now();
    state = AsyncValue.data([
      QuestInstance(
        id: 'habit-review-old',
        templateId: 'habit-template-old',
        templateTitle: 'Older Review',
        category: QuestCategory.habit,
        statCategory: QuestStatCategory.vitality,
        baseXp: 12,
        baseCoins: 3,
        status: QuestStatus.submitted,
        assignedHunterId: _TestProgressionController._childId,
        cadence: HabitCadence.daily,
        streakCount: 2,
        bestStreak: 2,
        completionsCount: 2,
        proofNote: 'older proof',
        proofSubmittedAt: now.subtract(const Duration(hours: 8)),
        dueAt: null,
        updatedAt: now.subtract(const Duration(hours: 8)),
      ),
      QuestInstance(
        id: 'habit-review-new',
        templateId: 'habit-template-new',
        templateTitle: 'Newest Review',
        category: QuestCategory.habit,
        statCategory: QuestStatCategory.vitality,
        baseXp: 15,
        baseCoins: 5,
        status: QuestStatus.submitted,
        assignedHunterId: _TestProgressionController._childId,
        cadence: HabitCadence.daily,
        streakCount: 4,
        bestStreak: 4,
        completionsCount: 4,
        proofNote: 'new proof',
        proofSubmittedAt: now.subtract(const Duration(hours: 1)),
        dueAt: null,
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      QuestInstance(
        id: 'habit-missed',
        templateId: 'habit-template-missed',
        templateTitle: 'Catch-up Habit',
        category: QuestCategory.habit,
        statCategory: QuestStatCategory.vitality,
        baseXp: 20,
        baseCoins: 6,
        status: QuestStatus.available,
        assignedHunterId: _TestProgressionController._childId,
        cadence: HabitCadence.daily,
        streakCount: 1,
        bestStreak: 3,
        completionsCount: 8,
        lastCompletedAt: now.subtract(const Duration(days: 2)),
        dueAt: null,
        updatedAt: now,
      ),
    ]);
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> submitQuest(
    String questInstanceId, {
    String? proofNote,
    QuestProofUpload? proofMedia,
  }) async {}
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

class _TestHunterDirectoryController extends HunterDirectoryController {
  _TestHunterDirectoryController()
    : super(
        repo: _NoopQuestRepository(),
        authSession: const AuthSession(
          accessToken: 'test-token',
          guildId: '00000000-0000-0000-0000-000000000001',
          hunterId: _TestProgressionController._childId,
          guildRole: GuildRole.member,
        ),
      ) {
    state = AsyncValue.data([
      HunterProfile(
        id: _TestProgressionController._childId,
        guildId: '00000000-0000-0000-0000-000000000001',
        playerId: 'demo_member',
        name: 'Demo Member',
        avatarType: 'bibon',
        level: 2,
        xp: 140,
        coins: 35,
      ),
    ]);
  }

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

class _TestDirectMessagesController extends DirectMessagesController {
  _TestDirectMessagesController()
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
        session: const AuthSession(
          accessToken: 'test-token',
          guildId: '00000000-0000-0000-0000-000000000001',
          hunterId: '00000000-0000-0000-0000-000000000011',
          guildRole: GuildRole.member,
        ),
        e2ee: DmE2eeService(
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
          store: _TestDmStore(),
        ),
      ) {
    state = DirectMessagesState(
      loading: false,
      refreshing: false,
      sending: false,
      contacts: [
        FriendProfile(
          id: '00000000-0000-0000-0000-000000000022',
          playerId: 'demo_member',
          name: 'Demo Member',
          guildId: '00000000-0000-0000-0000-000000000001',
          avatarType: 'bibon',
          level: 2,
          xp: 120,
          coins: 30,
        ),
        FriendProfile(
          id: '00000000-0000-0000-0000-000000000033',
          playerId: 'demo_friend',
          name: 'Demo Friend',
          guildId: '00000000-0000-0000-0000-000000000002',
          avatarType: 'bibon',
          level: 3,
          xp: 160,
          coins: 45,
        ),
      ],
      threads: [
        DirectMessageThread(
          conversationKey: 'conv-2',
          counterpartHunterId: '00000000-0000-0000-0000-000000000033',
          counterpartName: 'Demo Friend',
          counterpartPlayerId: 'demo_friend',
          counterpartGuildId: '00000000-0000-0000-0000-000000000002',
          counterpartAvatarType: 'bibon',
          lastMessage: 'Want to do a check-in later?',
          lastMessageSenderHunterId: '00000000-0000-0000-0000-000000000033',
          lastMessageSenderName: 'Demo Friend',
          lastMessageAt: DateTime(2026, 3, 9, 13, 30),
          lastMessageAtMs: DateTime(2026, 3, 9, 13, 30).millisecondsSinceEpoch,
          encryptionMode: 'plaintext',
          unreadCount: 2,
        ),
        DirectMessageThread(
          conversationKey: 'conv-1',
          counterpartHunterId: '00000000-0000-0000-0000-000000000022',
          counterpartName: 'Demo Member',
          counterpartPlayerId: 'demo_member',
          counterpartGuildId: '00000000-0000-0000-0000-000000000001',
          counterpartAvatarType: 'bibon',
          lastMessage: 'Remember to send the proof note.',
          lastMessageSenderHunterId: '00000000-0000-0000-0000-000000000011',
          lastMessageSenderName: 'Demo Self',
          lastMessageAt: DateTime(2026, 3, 8, 18, 20),
          lastMessageAtMs: DateTime(2026, 3, 8, 18, 20).millisecondsSinceEpoch,
          encryptionMode: 'encrypted',
          unreadCount: 0,
        ),
      ],
      threadSecurityByCounterpart: const {},
      selectedCounterpartId: '00000000-0000-0000-0000-000000000033',
      messages: const [],
      errorMessage: null,
    );
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> selectCounterpart(String counterpartHunterId) async {}

  @override
  Future<void> sendMessage(String content) async {}
}

class _TestDmStore implements DmSecureStore {
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
