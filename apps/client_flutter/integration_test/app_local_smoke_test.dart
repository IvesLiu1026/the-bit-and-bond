import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:the_bit_and_bond_client/app/app.dart';
import 'package:the_bit_and_bond_client/state/providers.dart';

import 'support/app_smoke_robot.dart';
import 'support/in_memory_secure_storage.dart';

const _demoMasterId = 'demo_master';
const _demoMasterPin = '1111';
const _demoMemberId = 'demo_member';
const _demoMemberPin = '2222';
const _memberPendingHabitQuestId = '10000000-0000-0000-0000-000000000301';
const _masterReviewHabitQuestId = '10000000-0000-0000-0000-000000000302';
const _friendRegularImageMessageId = '60000000-0000-0000-0000-000000000104';
const _friendOneTimeDeliveryId = '71000000-0000-0000-0000-000000000101';
const _guildStickerItemId = '20000000-0000-0000-0000-000000000104';
const _voiceSmokeModeName = String.fromEnvironment(
  'VOICE_SMOKE_MODE',
  defaultValue: 'connect',
);

VoiceSmokeMode _voiceSmokeMode() {
  return switch (_voiceSmokeModeName) {
    'graceful' => VoiceSmokeMode.graceful,
    _ => VoiceSmokeMode.connect,
  };
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStorageProvider.overrideWith((ref) => InMemorySecureStorage()),
      ],
      child: const TheBitAndBondApp(),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('manual login reaches DM thread and sends a message', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    final robot = AppSmokeRobot(tester);
    await robot.completeManualLogin(
      playerId: _demoMasterId,
      pinCode: _demoMasterPin,
    );
    await robot.openDirectMessages();
    await robot.openConversation('demo_friend');
    await robot.sendDirectMessage(
      'ios smoke ${DateTime.now().millisecondsSinceEpoch}',
    );
  });

  testWidgets('manual login can join and leave the voice room', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    final robot = AppSmokeRobot(tester);
    await robot.completeManualLogin(
      playerId: _demoMasterId,
      pinCode: _demoMasterPin,
    );
    await robot.exerciseVoiceRoomWithMode(
      'voice smoke ${DateTime.now().millisecondsSinceEpoch}',
      mode: _voiceSmokeMode(),
    );
  });

  testWidgets('master can open DM media and consume one-time photo', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    final robot = AppSmokeRobot(tester);
    await robot.completeManualLogin(
      playerId: _demoMasterId,
      pinCode: _demoMasterPin,
    );
    await robot.verifyDirectMessageMediaFixture(
      counterpartPlayerId: 'demo_friend',
      regularImageMessageId: _friendRegularImageMessageId,
      onceDeliveryId: _friendOneTimeDeliveryId,
    );
  });

  testWidgets('master can send DM image and one-time image fixtures', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    final robot = AppSmokeRobot(tester);
    await robot.completeManualLogin(
      playerId: _demoMasterId,
      pinCode: _demoMasterPin,
    );
    await robot.sendDirectMessageMediaFixtures('demo_member');
  });

  testWidgets('member can submit a habit proof note from the app', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    final robot = AppSmokeRobot(tester);
    await robot.completeManualLogin(
      playerId: _demoMemberId,
      pinCode: _demoMemberPin,
    );
    await robot.submitHabitProof(
      questId: _memberPendingHabitQuestId,
      note: 'member smoke ${DateTime.now().millisecondsSinceEpoch}',
    );
  });

  testWidgets('master can approve a pending habit review from the app', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    final robot = AppSmokeRobot(tester);
    await robot.completeManualLogin(
      playerId: _demoMasterId,
      pinCode: _demoMasterPin,
    );
    await robot.approveHabitReview(_masterReviewHabitQuestId);
  });

  testWidgets('master reward purchase updates bag and profile coins', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    final robot = AppSmokeRobot(tester);
    await robot.completeManualLogin(
      playerId: _demoMasterId,
      pinCode: _demoMasterPin,
    );
    await robot.buyRewardItem(
      itemId: _guildStickerItemId,
      expectedCoinsOnHand: 242,
    );
    await robot.closeRoute();
    await robot.useInventoryItem(_guildStickerItemId);
    await robot.closeRoute();
    await robot.expectProfileCoins(242);
  });
}
