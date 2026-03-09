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
