import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/pixel_typography.dart';
import '../features/auth/immersive_onboarding_page.dart';
import '../features/game/game_shell_page.dart';
import '../state/providers.dart';

class TheBitAndBondApp extends ConsumerWidget {
  const TheBitAndBondApp({super.key, this.enableDevicePreview = false});

  final bool enableDevicePreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettings = ref.watch(appSettingsProvider);
    final strings = ref.watch(appStringsProvider);
    PixelTypography.setPixelMode(appSettings.pixelFontEnabled);

    return MaterialApp(
      title: strings.appTitle,
      debugShowCheckedModeBanner: false,
      locale: enableDevicePreview
          ? DevicePreview.locale(context)
          : appSettings.locale,
      builder: enableDevicePreview ? DevicePreview.appBuilder : null,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: AppTheme.cozyGuildTheme(
        pixelFontEnabled: appSettings.pixelFontEnabled,
      ),
      home: AppStringsScope(strings: strings, child: const _AuthGate()),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      loading: () => const _AuthLoadingView(),
      error: (error, _) => _AuthLandingWithRouting(errorMessage: '$error'),
      data: (session) {
        if (session == null) {
          return const _AuthLandingWithRouting();
        }
        return const GameShellPage();
      },
    );
  }
}

class _AuthLandingWithRouting extends StatelessWidget {
  const _AuthLandingWithRouting({this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return ImmersiveOnboardingPage(errorMessage: errorMessage);
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ColoredBox(
        color: Color(0xFF7CB342),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF3E2723),
          ),
        ),
      ),
    );
  }
}
