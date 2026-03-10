import 'package:flutter/widgets.dart';

import '../settings/app_settings.dart';

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get _en => language == AppLanguage.english;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh', 'TW'),
    Locale('en'),
  ];

  factory AppStrings.fromLocale(Locale locale) {
    return AppStrings(
      locale.languageCode.toLowerCase().startsWith('en')
          ? AppLanguage.english
          : AppLanguage.traditionalChinese,
    );
  }

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStringsScope>();
    if (scope != null) {
      return scope.strings;
    }
    return const AppStrings(AppLanguage.traditionalChinese);
  }

  String get appTitle => 'The Bit and Bond';

  String tr({required String zh, required String en}) => _en ? en : zh;

  List<String> get onboardingSteps => _en
      ? const <String>['Knock', 'Style', 'Sign']
      : const <String>['敲門', '捏角', '契約'];

  String languageName(AppLanguage language) {
    return switch (language) {
      AppLanguage.traditionalChinese => '繁體中文',
      AppLanguage.english => 'English',
    };
  }

  String currentSpace(String label) =>
      _en ? 'Current Space: $label' : '目前空間：$label';

  String get spaceMap => _en ? 'Map' : '地圖';
  String get openMap => _en ? 'Open space map' : '打開空間平面圖';
  String get closeMap => _en ? 'Close space map' : '收起空間平面圖';
  String get mainMenu => _en ? 'Menu' : '選單';
  String get tasks => _en ? 'Tasks' : '任務';
  String get familyCenter => _en ? 'Family' : '家庭';
  String get rewards => _en ? 'Rewards' : '獎勵';
  String get bag => _en ? 'Bag' : '背包';
  String get voiceRoom => _en ? 'Voice' : '語音';
  String get profile => _en ? 'Profile' : '個人';
  String get settings => _en ? 'Settings' : '設定';
  String get habits => _en ? 'Habits' : '習慣';
  String get directMessages => _en ? 'DM' : '私訊';
  String get dmSendImage => _en ? 'Image' : '圖片';
  String get dmSendOneTimeImage => _en ? 'One-Time' : '閃照';
  String get dmSendMessage => _en ? 'Send' : '送出';
  String get dmViewed => _en ? 'Viewed' : '已查看';
  String get dmImagePreview => _en ? '[Photo]' : '[照片]';
  String get dmOneTimeImagePreview => _en ? '[One-time Photo]' : '[一次照片]';
  String get dmImageSent => _en ? 'Photo sent.' : '照片已送出。';
  String get dmOneTimeImageSent => _en ? 'One-time photo sent.' : '一次照片已送出。';
  String get dmImagePickCanceled => _en ? 'No image selected.' : '尚未選擇圖片。';
  String get dmImageSendFailed => _en ? 'Failed to send image.' : '圖片送出失敗。';
  String get dmImageOpenFailed => _en ? 'Failed to open photo.' : '照片開啟失敗。';
  String get dmImageUploading => _en ? 'Uploading photo...' : '正在上傳圖片...';
  String get dmOneTimeImageUploading =>
      _en ? 'Sending one-time photo...' : '正在送出閃照...';
  String get dmUploadingShort => _en ? 'Uploading' : '上傳中';
  String get dmSendingShort => _en ? 'Sending' : '送出中';
  String get dmOpeningShort => _en ? 'Opening' : '開啟中';
  String get dmOneTimeViewed =>
      _en ? 'This one-time photo was already viewed.' : '這張閃照已經看過。';
  String get dmOneTimeRequiresSecure => _en
      ? 'One-time photos require secure devices on both sides.'
      : '閃照需要雙方都啟用安全裝置。';
  String get encrypted => _en ? 'Encrypted' : '已加密';
  String get encryptionReady => _en ? 'Ready' : '可加密';
  String get notEncrypted => _en ? 'Plain' : '未加密';
  String get encryptedSubtitle => _en
      ? 'Only devices in this thread can read new messages.'
      : '這條聊天線的新訊息只有此對話中的裝置看得懂。';
  String get encryptionReadySubtitle => _en
      ? 'This thread can upgrade to end-to-end encryption.'
      : '這條聊天線已準備好升級成端對端加密。';
  String get plaintextSubtitle => _en
      ? 'Messages on this thread are still stored as plaintext.'
      : '這條聊天線的訊息目前仍以明文模式傳送。';
  String get encryptedMessageUnavailable =>
      _en ? '[Encrypted message unavailable]' : '[此裝置目前無法解開加密訊息]';
  String get photoDump => _en ? 'Photo Dump' : '照片牆';
  String get photoVault => _en ? 'Vault' : '收藏庫';
  String get photoOneTime => _en ? 'One-Time' : '一次照片';
  String get photoExports => _en ? 'Exports' : '匯出';
  String get photoDumpUpload => _en ? 'Upload' : '上傳';
  String get photoDumpCamera => _en ? 'Camera' : '相機';
  String get photoDumpGallery => _en ? 'Gallery' : '相簿';
  String get photoDumpCaptionHint =>
      _en ? 'Write a short note...' : '寫一段照片備註...';
  String get photoDumpRecipientHint => _en ? 'Recipient player ID' : '收件者玩家 ID';
  String get photoDumpEmptyVault =>
      _en ? 'No photos yet. Upload your first memory.' : '目前還沒有照片，先上傳第一張回憶吧。';
  String get photoDumpEmptyInbox =>
      _en ? 'No one-time photos right now.' : '目前沒有一次照片。';
  String get photoDumpExportSelected => _en ? 'Export selected' : '匯出已選照片';
  String get photoDumpLoadFailed =>
      _en ? 'Failed to load photo data.' : '照片資料載入失敗。';
  String get photoDumpUploadSuccess =>
      _en ? 'Photo uploaded to vault.' : '照片已加入收藏庫。';
  String get photoDumpVaultUploading =>
      _en ? 'Uploading to vault...' : '正在上傳到收藏庫...';
  String get photoDumpSendSuccess => _en ? 'One-time photo sent.' : '一次照片已送出。';
  String get photoDumpSendSuccessEncrypted =>
      _en ? 'Encrypted one-time photo sent.' : '已送出端對端加密的一次照片。';
  String get photoDumpOneTimeSending =>
      _en ? 'Sending one-time photo...' : '正在送出一次照片...';
  String get photoDumpRefresh => _en ? 'Refresh' : '重新整理';
  String get photoDumpOpenFailed =>
      _en ? 'Failed to open one-time photo.' : '一次照片開啟失敗。';
  String get photoDumpAlreadyViewed =>
      _en ? 'This one-time photo was already viewed.' : '這張一次照片已經看過。';
  String get photoDumpInboxTitle => _en ? 'Incoming' : '收件匣';
  String get photoDumpVaultTitle => _en ? 'My Vault' : '我的收藏';
  String photoDumpSelectedCount(int count) =>
      _en ? '$count selected' : '已選 $count 張';
  String photoDumpFrom(String sender) => _en ? 'From $sender' : '來自 $sender';
  String photoDumpExpiresAt(String value) =>
      _en ? 'Expires $value' : '$value 到期';
  String get photoDumpOpenOnce => _en ? 'Open Once' : '開啟一次';
  String get photoDumpOneTimeRule =>
      _en ? 'One-time photos expire after opening.' : '一次照片開啟後就會失效。';
  String get photoDumpExportHint => _en
      ? 'Select photos and export a LockIt/Retro style dump.'
      : '勾選照片後可匯出成 LockIt / Retro 風格 Photo Dump。';
  String get photoDumpPickFirst => _en ? 'Pick a photo first.' : '請先挑選一張照片。';
  String get photoDumpNeedRecipient =>
      _en ? 'Recipient player ID is required.' : '請輸入收件者玩家 ID。';
  String get photoDumpNeedFriendForSecureSend => _en
      ? 'Recipient must be in your friend list for secure photo sending.'
      : '安全照片寄送需要先成為好友。';
  String get photoDumpE2eeUnavailable => _en
      ? 'Secure photo send unavailable: both sides need active secure devices.'
      : '目前無法安全寄送：雙方都需要啟用中的安全裝置。';
  String get photoDumpAuthRequired =>
      _en ? 'Please log in again to continue.' : '請重新登入後再試一次。';
  String get photoDumpNoSelection =>
      _en ? 'Select at least one photo to export.' : '請至少選一張照片再匯出。';
  String get photoDumpOpenExpired =>
      _en ? 'This one-time photo has expired.' : '這張一次照片已過期。';
  String get photoDumpViewCountdown => _en ? 'Viewing once...' : '一次查看中...';
  String get comingSoon => _en ? 'Coming Soon' : '即將推出';
  String get openMainMenu => _en ? 'Open main menu' : '打開主選單';
  String get closeMenu => _en ? 'Close menu' : '關閉選單';
  String get closeSettings => _en ? 'Close settings' : '關閉設定';
  String get gameplayMenuTitle => _en ? 'Life Space Menu' : '生活空間選單';
  String get gameplayMenuSubtitle =>
      _en ? 'All core systems live here.' : '主要功能都收進這裡。';
  String get settingsTitle => _en ? 'Settings' : '設定';
  String get settingsSubtitle =>
      _en ? 'System language and experience options.' : '系統語言與體驗設定。';
  String get systemLanguage => _en ? 'System Language' : '系統語言';
  String get soundEffects => _en ? 'Sound Effects' : '音效';
  String get music => _en ? 'Music' : '音樂';
  String get haptics => _en ? 'Haptics' : '震動';
  String get uiScale => _en ? 'UI Scale' : '介面比例';
  String get pixelFx => _en ? 'Pixel FX' : '像素特效';
  String get visualTheme => _en ? 'Visual Theme' : '場景主題';
  String currentTheme(String label) =>
      _en ? 'Current theme: $label' : '目前主題：$label';
  String get cycleTheme => _en ? 'Cycle Theme' : '切換主題';
  String get logout => _en ? 'Log Out' : '登出';
  String get openProfile => _en ? 'Open profile' : '打開個人資料';
  String get yes => _en ? 'On' : '開';
  String get no => _en ? 'Off' : '關';
  String get taskBoard => _en ? 'Task Board' : '任務板';
  String get rewardShelf => _en ? 'Reward Shelf' : '獎勵架';
  String get familyDesk => _en ? 'Family Center' : '家庭中心';
  String get campfireRoom => _en ? 'Voice Room' : '語音房';
  String get leftJoystickHint =>
      _en ? 'Use the bottom-left joystick to move.' : '左下固定搖桿可 360 度移動';
}

class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  @override
  bool updateShouldNotify(covariant AppStringsScope oldWidget) {
    return oldWidget.strings.language != strings.language;
  }
}
