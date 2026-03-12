import 'package:flutter/foundation.dart';

abstract final class AppTestIds {
  static const ValueKey<String> onboardingGreetingStepKey = ValueKey<String>(
    'greeting',
  );
  static const ValueKey<String> onboardingCustomizationStepKey =
      ValueKey<String>('customization');
  static const ValueKey<String> onboardingContractStepKey = ValueKey<String>(
    'contract',
  );
  static const ValueKey<String> onboardingEnterSpaceButtonKey =
      ValueKey<String>('onboarding_enter_space');
  static const ValueKey<String> onboardingContinueToContractButtonKey =
      ValueKey<String>('onboarding_continue_contract');
  static const ValueKey<String> onboardingManualRegisterButtonKey =
      ValueKey<String>('onboarding_manual_register');
  static const ValueKey<String> onboardingManualLoginButtonKey =
      ValueKey<String>('onboarding_manual_login');

  static const ValueKey<String> authAccountFieldKey = ValueKey<String>(
    'auth_account_field',
  );
  static const ValueKey<String> authSecretFieldKey = ValueKey<String>(
    'auth_secret_field',
  );
  static const ValueKey<String> authDisplayNameFieldKey = ValueKey<String>(
    'auth_display_name_field',
  );
  static const ValueKey<String> authSubmitButtonKey = ValueKey<String>(
    'auth_submit_button',
  );
  static const ValueKey<String> authErrorBannerKey = ValueKey<String>(
    'auth_error_banner',
  );

  static const ValueKey<String> mainMenuOpenButtonKey = ValueKey<String>(
    'main_menu_open',
  );
  static const ValueKey<String> mainMenuGridKey = ValueKey<String>(
    'main_menu_grid',
  );
  static ValueKey<String> mainMenuCard(String id) =>
      ValueKey<String>('main_menu_card_$id');

  static const ValueKey<String> dmInboxSearchKey = ValueKey<String>(
    'dm_inbox_search',
  );
  static const ValueKey<String> dmBackButtonKey = ValueKey<String>(
    'dm_back_button',
  );
  static ValueKey<String> dmRosterCard(String playerId) =>
      ValueKey<String>('dm_roster_${playerId.toLowerCase()}');
  static const ValueKey<String> dmComposerFieldKey = ValueKey<String>(
    'dm_composer_field',
  );
  static const ValueKey<String> dmSendButtonKey = ValueKey<String>(
    'dm_send_button',
  );
  static const ValueKey<String> dmSendImageButtonKey = ValueKey<String>(
    'dm_send_image_button',
  );
  static const ValueKey<String> dmSendOneTimeImageButtonKey = ValueKey<String>(
    'dm_send_one_time_image_button',
  );
  static const ValueKey<String> dmMediaStatusBannerKey = ValueKey<String>(
    'dm_media_status_banner',
  );
  static ValueKey<String> dmImageBubble(String messageId) =>
      ValueKey<String>('dm_image_bubble_$messageId');
  static ValueKey<String> dmOneTimeBubble(String deliveryId) =>
      ValueKey<String>('dm_onetime_bubble_$deliveryId');
  static ValueKey<String> dmOneTimeOpenButton(String deliveryId) =>
      ValueKey<String>('dm_onetime_open_$deliveryId');
  static ValueKey<String> dmOneTimeViewedTag(String deliveryId) =>
      ValueKey<String>('dm_onetime_viewed_$deliveryId');
  static const ValueKey<String> dmOneTimeViewerDialogKey = ValueKey<String>(
    'dm_onetime_viewer_dialog',
  );
  static const ValueKey<String> dmOneTimeViewerCloseButtonKey =
      ValueKey<String>('dm_onetime_viewer_close');

  static ValueKey<String> habitActiveCard(String questId) =>
      ValueKey<String>('habit_card_active_$questId');
  static ValueKey<String> habitReviewCard(String questId) =>
      ValueKey<String>('habit_card_review_$questId');
  static ValueKey<String> habitSubmitButton(String questId) =>
      ValueKey<String>('habit_submit_$questId');
  static ValueKey<String> habitApproveButton(String questId) =>
      ValueKey<String>('habit_approve_$questId');
  static ValueKey<String> habitRejectButton(String questId) =>
      ValueKey<String>('habit_reject_$questId');
  static const ValueKey<String> habitProofNoteFieldKey = ValueKey<String>(
    'habit_proof_note_field',
  );
  static const ValueKey<String> habitProofSendButtonKey = ValueKey<String>(
    'habit_proof_send_button',
  );
  static const ValueKey<String> habitsPanelKey = ValueKey<String>(
    'habits_panel',
  );
  static const ValueKey<String> habitsReviewSectionKey = ValueKey<String>(
    'habits_review_section',
  );
  static const ValueKey<String> rewardsPanelKey = ValueKey<String>(
    'rewards_panel',
  );
  static const ValueKey<String> rewardsCoinsLabelKey = ValueKey<String>(
    'rewards_coins_label',
  );
  static const ValueKey<String> rewardsSuccessTextKey = ValueKey<String>(
    'rewards_success_text',
  );
  static ValueKey<String> rewardItemCard(String itemId) =>
      ValueKey<String>('reward_item_$itemId');
  static ValueKey<String> rewardBuyButton(String itemId) =>
      ValueKey<String>('reward_buy_$itemId');
  static const ValueKey<String> inventoryPanelKey = ValueKey<String>(
    'inventory_panel',
  );
  static const ValueKey<String> inventorySuccessTextKey = ValueKey<String>(
    'inventory_success_text',
  );
  static ValueKey<String> inventoryItemCard(String itemId) =>
      ValueKey<String>('inventory_item_$itemId');
  static ValueKey<String> inventoryUseButton(String itemId) =>
      ValueKey<String>('inventory_use_$itemId');
  static const ValueKey<String> inventoryConfirmUseButtonKey = ValueKey<String>(
    'inventory_confirm_use',
  );
  static const ValueKey<String> profileCoinsTileKey = ValueKey<String>(
    'profile_coins_tile',
  );

  static const ValueKey<String> voiceJoinButtonKey = ValueKey<String>(
    'voice_join_button',
  );
  static const ValueKey<String> voiceMessageFieldKey = ValueKey<String>(
    'voice_message_field',
  );
  static const ValueKey<String> voiceSendButtonKey = ValueKey<String>(
    'voice_send_button',
  );
  static const ValueKey<String> voiceLeaveButtonKey = ValueKey<String>(
    'voice_leave_button',
  );
  static const ValueKey<String> voiceErrorBannerKey = ValueKey<String>(
    'voice_error_banner',
  );
}
