import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:the_bit_and_bond_client/core/ui/app_test_ids.dart';

enum VoiceSmokeMode { connect, graceful }

class AppSmokeRobot {
  AppSmokeRobot(this.tester);

  final WidgetTester tester;

  Finder _editableField(Key key) {
    final root = find.byKey(key);
    final textField = find.descendant(
      of: root,
      matching: find.byType(TextField),
    );
    if (textField.evaluate().isNotEmpty) {
      return textField;
    }
    return root;
  }

  Finder _finderByStringKeyPrefix(String prefix) {
    return find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith(prefix);
    });
  }

  String _textValue(Finder finder) {
    final text = tester.widget<Text>(finder);
    return text.data ?? text.textSpan?.toPlainText() ?? '';
  }

  String _descendantText(Finder root) {
    final values = find
        .descendant(of: root, matching: find.byType(Text))
        .evaluate()
        .map((element) {
          final widget = element.widget;
          if (widget is! Text) {
            return '';
          }
          return widget.data ?? widget.textSpan?.toPlainText() ?? '';
        })
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return values.join(' ');
  }

  Future<void> waitForVisible(
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
    String? reason,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    throw TestFailure(reason ?? 'Timed out waiting for $finder');
  }

  Future<void> waitForGone(
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
    String? reason,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      try {
        if (finder.evaluate().isEmpty) {
          return;
        }
      } on StateError {
        return;
      }
    }
    throw TestFailure(reason ?? 'Timed out waiting for $finder to disappear');
  }

  Future<void> waitUntil(
    bool Function() predicate, {
    Duration timeout = const Duration(seconds: 30),
    String? reason,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (predicate()) {
        return;
      }
    }
    throw TestFailure(reason ?? 'Timed out waiting for predicate');
  }

  Future<void> tap(
    Finder finder, {
    double horizontalBias = 0.5,
    double verticalBias = 0.5,
  }) async {
    await waitForVisible(finder);
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 200));
    final rect = tester.getRect(finder);
    final dx = rect.left + (rect.width * horizontalBias);
    final dy = rect.top + (rect.height * verticalBias);
    await tester.tapAt(Offset(dx, dy));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> triggerGestureTap(Finder finder) async {
    await waitForVisible(
      finder,
      reason: 'Expected gesture tap target to become visible',
    );
    final gesture = tester.widget<GestureDetector>(finder);
    final onTap = gesture.onTap;
    if (onTap == null) {
      throw TestFailure('Expected $finder to expose an onTap callback');
    }
    onTap();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> _openMainMenuCard(String id) async {
    await tap(find.byKey(AppTestIds.mainMenuOpenButtonKey));
    await waitForVisible(find.byKey(AppTestIds.mainMenuGridKey));
    final card = find.byKey(AppTestIds.mainMenuCard(id));
    final mainMenuScrollable = find.descendant(
      of: find.byKey(AppTestIds.mainMenuGridKey),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(card, 140, scrollable: mainMenuScrollable);
    await tester.pump(const Duration(milliseconds: 200));
    await tapInside(card);
  }

  Future<void> _reveal(Finder finder) async {
    await waitUntil(
      () => finder.evaluate().isNotEmpty,
      reason: 'Expected target widget to be built',
    );
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> _scrollWithin(
    Finder scrollable,
    Finder target, {
    double delta = 220,
    int maxScrolls = 20,
  }) async {
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: scrollable,
      maxScrolls: maxScrolls,
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> _revealInAnyScrollable(
    Finder target, {
    double delta = 220,
    int maxScrolls = 20,
  }) async {
    if (target.evaluate().isNotEmpty) {
      await _reveal(target);
      return;
    }
    final scrollables = find
        .byType(Scrollable)
        .evaluate()
        .toList(growable: false);
    if (scrollables.isEmpty) {
      throw TestFailure('Expected a scrollable to reveal $target');
    }
    Object? lastError;
    for (final element in scrollables.reversed) {
      final scrollable = find.byWidget(element.widget);
      try {
        await _scrollWithin(
          scrollable,
          target,
          delta: delta,
          maxScrolls: maxScrolls,
        );
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw TestFailure(
      'Failed to reveal $target in available scrollables: $lastError',
    );
  }

  Future<void> tapInside(
    Finder finder, {
    Offset offset = const Offset(24, 24),
  }) async {
    await waitForVisible(finder);
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(tester.getTopLeft(finder) + offset);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> enterText(Key key, String value) async {
    final finder = _editableField(key);
    await waitForVisible(finder);
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> dismissKeyboard() async {
    tester.binding.focusManager.primaryFocus?.unfocus();
    try {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    } catch (_) {
      // Some real-device text inputs do not expose a pending action channel.
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> completeManualLogin({
    required String playerId,
    required String pinCode,
  }) async {
    await tap(find.byKey(AppTestIds.onboardingEnterSpaceButtonKey));
    await waitForVisible(find.byKey(AppTestIds.onboardingCustomizationStepKey));
    await tap(find.byKey(AppTestIds.onboardingContinueToContractButtonKey));
    await waitForVisible(find.byKey(AppTestIds.onboardingContractStepKey));
    await tap(find.byKey(AppTestIds.onboardingManualLoginButtonKey));
    await enterText(AppTestIds.authAccountFieldKey, playerId);
    await enterText(AppTestIds.authSecretFieldKey, pinCode);
    await dismissKeyboard();
    final submitButton = find.byKey(AppTestIds.authSubmitButtonKey);
    final authErrorBanner = find.byKey(AppTestIds.authErrorBannerKey);
    final mainMenuButton = find.byKey(AppTestIds.mainMenuOpenButtonKey);
    await _revealInAnyScrollable(submitButton, delta: 120, maxScrolls: 8);
    for (var attempt = 0; attempt < 2; attempt += 1) {
      await tap(submitButton, verticalBias: 0.72);
      await waitUntil(
        () {
          if (mainMenuButton.evaluate().isNotEmpty ||
              authErrorBanner.evaluate().isNotEmpty) {
            return true;
          }
          if (submitButton.evaluate().isEmpty) {
            return false;
          }
          final submitText = _descendantText(submitButton);
          return submitText.contains('處理中') || submitText.contains('Working');
        },
        timeout: const Duration(seconds: 8),
        reason: 'Expected manual login to react after tapping submit',
      );
      if (mainMenuButton.evaluate().isNotEmpty) {
        return;
      }
      if (authErrorBanner.evaluate().isNotEmpty) {
        throw TestFailure(
          'Manual login failed: ${_descendantText(authErrorBanner)}',
        );
      }
      await waitUntil(
        () =>
            mainMenuButton.evaluate().isNotEmpty ||
            authErrorBanner.evaluate().isNotEmpty ||
            _descendantText(submitButton).contains('登入遊戲') ||
            _descendantText(submitButton).contains('Enter Space'),
        timeout: const Duration(seconds: 45),
        reason: 'Expected manual login to finish routing after submit',
      );
      if (mainMenuButton.evaluate().isNotEmpty) {
        return;
      }
      if (authErrorBanner.evaluate().isNotEmpty) {
        throw TestFailure(
          'Manual login failed: ${_descendantText(authErrorBanner)}',
        );
      }
    }
    throw TestFailure('Expected game shell to appear after manual login');
  }

  Future<void> openDirectMessages() async {
    await _openMainMenuCard('dm');
    await waitForVisible(find.byKey(AppTestIds.dmInboxSearchKey));
  }

  Future<void> openConversation(String counterpartPlayerId) async {
    await tap(find.byKey(AppTestIds.dmRosterCard(counterpartPlayerId)));
    await waitForVisible(find.byKey(AppTestIds.dmComposerFieldKey));
  }

  Future<void> returnToInbox() async {
    await tap(find.byKey(AppTestIds.dmBackButtonKey));
    await waitForVisible(find.byKey(AppTestIds.dmInboxSearchKey));
  }

  Future<void> sendDirectMessage(String message) async {
    await enterText(AppTestIds.dmComposerFieldKey, message);
    try {
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump(const Duration(milliseconds: 300));
    } catch (_) {
      // Real-device text fields do not always expose the action channel.
    }
    final fieldFinder = _editableField(AppTestIds.dmComposerFieldKey);
    final field = tester.widget<TextField>(fieldFinder);
    final composerClearedAfterSubmitAction =
        field.controller?.text.isEmpty ?? false;
    if (!composerClearedAfterSubmitAction) {
      await dismissKeyboard();
      await tap(find.byKey(AppTestIds.dmSendButtonKey));
    }
    await waitUntil(
      () {
        final field = tester.widget<TextField>(fieldFinder);
        final composerCleared = field.controller?.text.isEmpty ?? false;
        final sentMessageVisible = find.text(message).evaluate().isNotEmpty;
        return composerCleared || sentMessageVisible;
      },
      reason:
          'Expected DM send flow to either clear the composer or append the message',
    );
    await waitForVisible(
      find.text(message),
      reason: 'Expected sent DM to appear in the conversation timeline',
    );
  }

  Future<void> sendDirectMessageMediaFixtures(
    String counterpartPlayerId,
  ) async {
    await openDirectMessages();
    await openConversation(counterpartPlayerId);

    final anyImageBubble = _finderByStringKeyPrefix('dm_image_bubble_');
    final anyOneTimeBubble = _finderByStringKeyPrefix('dm_onetime_bubble_');
    final baselineImageCount = anyImageBubble.evaluate().length;
    final baselineOneTimeCount = anyOneTimeBubble.evaluate().length;

    await tap(find.byKey(AppTestIds.dmSendImageButtonKey));
    await waitUntil(
      () => anyImageBubble.evaluate().length > baselineImageCount,
      reason: 'Expected DM image send flow to append an image bubble',
    );

    await tap(find.byKey(AppTestIds.dmSendOneTimeImageButtonKey));
    await waitUntil(
      () => anyOneTimeBubble.evaluate().length > baselineOneTimeCount,
      reason:
          'Expected one-time DM send flow to append a one-time preview bubble',
    );
  }

  Future<void> verifyDirectMessageMediaFixture({
    required String counterpartPlayerId,
    required String regularImageMessageId,
    required String onceDeliveryId,
  }) async {
    await openDirectMessages();
    await openConversation(counterpartPlayerId);
    final regularImage = find.byKey(
      AppTestIds.dmImageBubble(regularImageMessageId),
    );
    final oneTimeOpenButton = find.byKey(
      AppTestIds.dmOneTimeOpenButton(onceDeliveryId),
    );
    await waitUntil(
      () =>
          regularImage.evaluate().isNotEmpty ||
          oneTimeOpenButton.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      reason: 'Expected seeded DM media fixtures to load in the conversation',
    );
    await _revealInAnyScrollable(regularImage, maxScrolls: 8);
    await waitForVisible(
      regularImage,
      reason: 'Expected seeded DM image bubble to render in the timeline',
    );
    await _revealInAnyScrollable(oneTimeOpenButton, maxScrolls: 8);
    await tap(oneTimeOpenButton);
    await waitForVisible(
      find.byKey(AppTestIds.dmOneTimeViewerDialogKey),
      reason: 'Expected one-time DM photo viewer to open',
    );
    await tap(find.byKey(AppTestIds.dmOneTimeViewerCloseButtonKey));
    await waitForGone(
      find.byKey(AppTestIds.dmOneTimeViewerDialogKey),
      reason: 'Expected one-time DM photo viewer to close',
    );
    await waitForVisible(
      find.byKey(AppTestIds.dmOneTimeViewedTag(onceDeliveryId)),
      reason: 'Expected one-time DM photo to become viewed after opening',
    );
    await returnToInbox();
    await openConversation(counterpartPlayerId);
    await waitForVisible(
      find.byKey(AppTestIds.dmOneTimeViewedTag(onceDeliveryId)),
      reason: 'Expected viewed one-time DM photo to stay consumed after reload',
    );
    if (find
        .byKey(AppTestIds.dmOneTimeOpenButton(onceDeliveryId))
        .evaluate()
        .isNotEmpty) {
      throw TestFailure(
        'Expected consumed one-time DM photo to stop exposing an open action',
      );
    }
  }

  Future<void> openVoiceRoom() async {
    await _openMainMenuCard('voice');
    await waitForVisible(find.byKey(AppTestIds.voiceJoinButtonKey));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> exerciseVoiceRoom(String message) async {
    await exerciseVoiceRoomWithMode(message, mode: VoiceSmokeMode.connect);
  }

  Future<void> exerciseVoiceRoomWithMode(
    String message, {
    required VoiceSmokeMode mode,
  }) async {
    await openVoiceRoom();
    final joinButton = find.byKey(AppTestIds.voiceJoinButtonKey);
    await tap(joinButton);
    var joinReacted = false;
    try {
      await waitUntil(
        () =>
            joinButton.evaluate().isEmpty ||
            _descendantText(joinButton).contains('連線中') ||
            _descendantText(joinButton).contains('Connecting') ||
            find.byKey(AppTestIds.voiceLeaveButtonKey).evaluate().isNotEmpty ||
            find.byKey(AppTestIds.voiceErrorBannerKey).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 4),
        reason: 'Expected join action to react after tapping voice room join',
      );
      joinReacted = true;
    } catch (_) {
      await tapInside(joinButton, offset: const Offset(18, 18));
    }
    if (!joinReacted) {
      try {
        await waitUntil(
          () =>
              joinButton.evaluate().isEmpty ||
              _descendantText(joinButton).contains('連線中') ||
              _descendantText(joinButton).contains('Connecting') ||
              find.byKey(AppTestIds.voiceLeaveButtonKey).evaluate().isNotEmpty ||
              find.byKey(AppTestIds.voiceErrorBannerKey).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
          reason: 'Expected join action to react after tapping voice room join',
        );
      } catch (_) {
        await triggerGestureTap(joinButton);
        await waitUntil(
          () =>
              joinButton.evaluate().isEmpty ||
              _descendantText(joinButton).contains('連線中') ||
              _descendantText(joinButton).contains('Connecting') ||
              find.byKey(AppTestIds.voiceLeaveButtonKey).evaluate().isNotEmpty ||
              find.byKey(AppTestIds.voiceErrorBannerKey).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
          reason: 'Expected join action to react after triggering voice join',
        );
      }
    }
    await waitUntil(
      () =>
          find.byKey(AppTestIds.voiceLeaveButtonKey).evaluate().isNotEmpty ||
          find.byKey(AppTestIds.voiceErrorBannerKey).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
      reason: 'Expected voice room to either connect or surface an error',
    );
    final errorBanner = find.byKey(AppTestIds.voiceErrorBannerKey);
    if (errorBanner.evaluate().isNotEmpty) {
      final errorText = find.descendant(
        of: errorBanner,
        matching: find.byType(Text),
      );
      final rendered = errorText.evaluate().isEmpty
          ? 'unknown voice error'
          : tester.widget<Text>(errorText.first).data ?? 'unknown voice error';
      if (mode == VoiceSmokeMode.graceful &&
          _isRecoverableSimulatorVoiceError(rendered)) {
        await waitForVisible(
          find.byKey(AppTestIds.voiceJoinButtonKey),
          reason: 'Expected join action to remain available after voice error',
        );
        return;
      }
      throw TestFailure('Voice room failed to connect: $rendered');
    }
    await waitForVisible(
      find.byKey(AppTestIds.voiceLeaveButtonKey),
      reason: 'Expected voice room to connect and show leave action',
    );
    await enterText(AppTestIds.voiceMessageFieldKey, message);
    await tap(find.byKey(AppTestIds.voiceSendButtonKey));
    await waitForVisible(
      find.text(message),
      reason: 'Expected sent voice-room chat message to appear',
    );
    await tap(find.byKey(AppTestIds.voiceLeaveButtonKey));
    await waitForVisible(
      find.byKey(AppTestIds.voiceJoinButtonKey),
      reason: 'Expected join action to return after leaving voice room',
    );
  }

  Future<void> openHabits() async {
    await _openMainMenuCard('habits');
    final panel = find.byKey(AppTestIds.habitsPanelKey);
    await waitForVisible(panel);
    final loading = find.descendant(
      of: panel,
      matching: find.byType(CircularProgressIndicator),
    );
    await waitUntil(
      () => loading.evaluate().isEmpty,
      reason: 'Expected habits panel to finish loading',
    );
  }

  Future<void> openRewards() async {
    await _openMainMenuCard('rewards');
    await waitForVisible(find.byKey(AppTestIds.rewardsPanelKey));
  }

  Future<void> buyRewardItem({
    required String itemId,
    required int expectedCoinsOnHand,
  }) async {
    await openRewards();
    final buyButton = find.byKey(AppTestIds.rewardBuyButton(itemId));
    await _reveal(buyButton);
    await tap(buyButton);
    await waitForVisible(
      find.byKey(AppTestIds.rewardsSuccessTextKey),
      reason: 'Expected reward purchase success feedback to appear',
    );
    await waitUntil(
      () => _textValue(
        find.byKey(AppTestIds.rewardsCoinsLabelKey),
      ).contains('$expectedCoinsOnHand'),
      reason: 'Expected reward station coins label to reflect the purchase',
    );
  }

  Future<void> closeRoute() async {
    await tester.tapAt(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openBag() async {
    await _openMainMenuCard('bag');
    await waitForVisible(find.byKey(AppTestIds.inventoryPanelKey));
  }

  Future<void> useInventoryItem(String itemId) async {
    await openBag();
    final itemCard = find.byKey(AppTestIds.inventoryItemCard(itemId));
    final useButton = find.byKey(AppTestIds.inventoryUseButton(itemId));
    await _reveal(itemCard);
    await tap(useButton);
    await tap(find.byKey(AppTestIds.inventoryConfirmUseButtonKey));
    await waitForVisible(
      find.byKey(AppTestIds.inventorySuccessTextKey),
      reason: 'Expected inventory use success feedback to appear',
    );
    await waitForGone(
      itemCard,
      reason: 'Expected single-quantity inventory item to disappear after use',
    );
  }

  Future<void> openProfile() async {
    await _openMainMenuCard('profile');
    await waitForVisible(find.byKey(AppTestIds.profileCoinsTileKey));
  }

  Future<void> expectProfileCoins(int expectedCoins) async {
    await openProfile();
    await waitUntil(
      () => _descendantText(
        find.byKey(AppTestIds.profileCoinsTileKey),
      ).contains('$expectedCoins'),
      reason: 'Expected profile coins tile to reflect the latest balance',
    );
  }

  Future<void> submitHabitProof({
    required String questId,
    required String note,
  }) async {
    await openHabits();
    final submitButton = find.byKey(AppTestIds.habitSubmitButton(questId));
    await _reveal(submitButton);
    await tap(submitButton);
    await enterText(AppTestIds.habitProofNoteFieldKey, note);
    await dismissKeyboard();
    await _revealInAnyScrollable(
      find.byKey(AppTestIds.habitProofSendButtonKey),
      delta: 120,
      maxScrolls: 12,
    );
    await tap(find.byKey(AppTestIds.habitProofSendButtonKey));
    await waitForGone(
      find.byKey(AppTestIds.habitProofNoteFieldKey),
      reason: 'Expected habit proof dialog to close after submitting',
    );
    final panel = find.byKey(AppTestIds.habitsPanelKey);
    final panelScrollables = find.descendant(
      of: panel,
      matching: find.byType(Scrollable),
    );
    if (panelScrollables.evaluate().isNotEmpty) {
      await _scrollWithin(
        panelScrollables.first,
        find.byKey(AppTestIds.habitsReviewSectionKey),
        delta: 180,
        maxScrolls: 20,
      );
    }
    final activeCard = find.byKey(AppTestIds.habitActiveCard(questId));
    final reviewCard = find.byKey(AppTestIds.habitReviewCard(questId));
    await waitUntil(() {
      final noteVisible = find.textContaining(note).evaluate().isNotEmpty;
      final activeText = activeCard.evaluate().isEmpty
          ? ''
          : _descendantText(activeCard);
      final reviewText = reviewCard.evaluate().isEmpty
          ? ''
          : _descendantText(reviewCard);
      return submitButton.evaluate().isEmpty ||
          reviewCard.evaluate().isNotEmpty ||
          noteVisible ||
          activeText.contains(note) ||
          reviewText.contains(note);
    }, reason: 'Expected habit proof submission to refresh the board state');
  }

  Future<void> approveHabitReview(String questId) async {
    await openHabits();
    final panel = find.byKey(AppTestIds.habitsPanelKey);
    final reviewSection = find.byKey(AppTestIds.habitsReviewSectionKey);
    final panelScrollables = find.descendant(
      of: panel,
      matching: find.byType(Scrollable),
    );
    if (panelScrollables.evaluate().isNotEmpty) {
      await _scrollWithin(
        panelScrollables.first,
        reviewSection,
        delta: 180,
        maxScrolls: 20,
      );
    }
    final reviewCard = find.byKey(AppTestIds.habitReviewCard(questId));
    final approveButton = find.byKey(AppTestIds.habitApproveButton(questId));
    final anyApproveButtons = _finderByStringKeyPrefix('habit_approve_');
    await waitUntil(
      () => approveButton.evaluate().isNotEmpty || anyApproveButtons.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
      reason: 'Expected a habit review card to appear for approval',
    );
    Finder targetApprove;
    if (approveButton.evaluate().isNotEmpty) {
      await _reveal(approveButton);
      targetApprove = approveButton;
    } else {
      await _reveal(anyApproveButtons.first);
      targetApprove = anyApproveButtons.first;
    }
    await tap(targetApprove);
    if (reviewCard.evaluate().isNotEmpty) {
      await waitForGone(
        reviewCard,
        reason: 'Expected reviewed habit card to leave the review inbox',
      );
      return;
    }
    await waitForGone(
      targetApprove,
      reason: 'Expected approved habit review action to disappear',
    );
  }

  bool _isRecoverableSimulatorVoiceError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('peerconnection') ||
        normalized.contains('ice connectivity') ||
        normalized.contains('mediaconnectexception') ||
        normalized.contains('timed out waiting');
  }
}
