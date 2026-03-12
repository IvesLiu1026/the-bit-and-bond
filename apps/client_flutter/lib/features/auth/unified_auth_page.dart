import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/auth_api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/app_test_ids.dart';
import '../../state/providers.dart';

part 'unified/controls.part.dart';
part 'unified/form.part.dart';
part 'unified/visuals.part.dart';

enum UnifiedAuthMode { login, register }

class UnifiedAuthPage extends StatelessWidget {
  const UnifiedAuthPage({super.key, this.avatarType});

  final String? avatarType;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final media = MediaQuery.of(context);
    final compact = media.size.width < 560;

    return Scaffold(
      body: Container(
        color: const Color(0xFF6E9A39),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _PixelAuthBackdrop()),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4ECE1),
                        border: Border.all(
                          color: const Color(0xFF5D4037),
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowHard,
                            offset: Offset(0, 6),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 14 : 18,
                              compact ? 14 : 18,
                              compact ? 14 : 18,
                              12,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFE8D8B0), Color(0xFFD6BE8F)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.woodFrame,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                const _PixelTavernCrest(),
                                const SizedBox(height: 10),
                                Text(
                                  'The Bit and Bond',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.inkBrown,
                                    fontWeight: FontWeight.w900,
                                    fontSize: compact ? 24 : 30,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  strings.tr(
                                    zh: '玩家印記櫃台',
                                    en: 'Player Seal Desk',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.inkBrown.withValues(
                                      alpha: 0.82,
                                    ),
                                    fontWeight: FontWeight.w800,
                                    fontSize: compact ? 14 : 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(compact ? 14 : 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _PixelFlavorStrip(
                                  text: strings.tr(
                                    zh: '玩家 ID、PIN、Email 都從這裡進入',
                                    en: 'Enter with Player ID, PIN, or Email',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                UnifiedAuthForm(avatarType: avatarType),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
