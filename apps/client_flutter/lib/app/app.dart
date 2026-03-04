import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_landing_page.dart';
import '../features/auth/hunter_login_page.dart';
import '../features/auth/master_auth_page.dart';
import '../features/game/game_shell_page.dart';
import '../state/providers.dart';

class ChenLevelingApp extends ConsumerWidget {
  const ChenLevelingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Chen Leveling',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.cozyGuildTheme,
      home: const _AuthGate(),
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
    return Stack(
      children: [
        AuthLandingPage(
          onMasterTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MasterAuthPage()),
            );
          },
          onHunterTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HunterLoginPage()),
            );
          },
        ),
        if (errorMessage != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB71C1C), width: 2),
                ),
                child: Text(
                  'Auth error: $errorMessage',
                  style: const TextStyle(
                    color: Color(0xFFB71C1C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
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
