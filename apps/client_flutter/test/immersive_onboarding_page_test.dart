import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:the_bit_and_bond_client/app/app.dart';
import 'package:the_bit_and_bond_client/core/auth/auth_session.dart';
import 'package:the_bit_and_bond_client/core/auth/google_federated_auth_service.dart';
import 'package:the_bit_and_bond_client/core/config/app_config.dart';
import 'package:the_bit_and_bond_client/core/network/auth_api_client.dart';
import 'package:the_bit_and_bond_client/core/telemetry/product_analytics.dart';
import 'package:the_bit_and_bond_client/core/settings/app_settings.dart';
import 'package:the_bit_and_bond_client/core/network/api_client.dart';
import 'package:the_bit_and_bond_client/features/auth/immersive_onboarding_page.dart';
import 'package:the_bit_and_bond_client/state/auth_controller.dart';
import 'package:the_bit_and_bond_client/state/providers.dart';

void main() {
  testWidgets(
    'immersive onboarding flows to compact contract and manual sheet',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleFederatedAuthServiceProvider.overrideWith(
              (ref) => _FailingGoogleService(),
            ),
          ],
          child: const MaterialApp(home: ImmersiveOnboardingPage()),
        ),
      );

      expect(find.text('[ 點擊畫面進入空間 ]'), findsOneWidget);

      await tester.tap(find.text('[ 點擊畫面進入空間 ]'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('先決定今天的模樣。'), findsOneWidget);
      expect(find.text('前往契約'), findsOneWidget);

      await tester.ensureVisible(find.text('前往契約'));
      await tester.tap(find.text('前往契約'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('生活契約'), findsOneWidget);
      expect(find.text('[ 以 Google 紋章簽署 ]'), findsOneWidget);

      await tester.ensureVisible(find.text('[ 以 Google 紋章簽署 ]'));
      await tester.tap(find.text('[ 以 Google 紋章簽署 ]'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.textContaining('Firebase 與後端驗章流程'), findsOneWidget);
      expect(find.text('手動註冊新角色'), findsOneWidget);

      await tester.tap(find.text('手動註冊新角色'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('玩家印記註冊'), findsOneWidget);
      expect(find.text('註冊並開始'), findsOneWidget);
    },
  );

  testWidgets('app shows immersive onboarding when there is no session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => _LoggedOutAuthController(),
          ),
        ],
        child: const TheBitAndBondApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('[ 點擊畫面進入空間 ]'), findsOneWidget);
    expect(find.text('The Bit and Bond'), findsOneWidget);
  });

  testWidgets(
    'manual login does not use onboarding ref after auth gate disposes page',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => _SuccessfulAuthController(),
            ),
            productAnalyticsProvider.overrideWith(
              (ref) => _NoopProductAnalytics(),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final authState = ref.watch(authControllerProvider);
              final session = authState.valueOrNull;
              return MaterialApp(
                home: session == null
                    ? const ImmersiveOnboardingPage()
                    : const Scaffold(body: Text('signed-in')),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('[ 點擊畫面進入空間 ]'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.ensureVisible(find.text('前往契約'));
      await tester.tap(find.text('前往契約'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('已有角色，用玩家 ID 登入'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == '玩家 ID 或 Email',
        ),
        'demo_master',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == 'PIN 或密碼',
        ),
        '1111',
      );
      await tester.tap(find.text('登入遊戲'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('signed-in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FailingGoogleService extends GoogleFederatedAuthService {
  @override
  Future<GoogleFederatedIdentity> signIn() {
    throw const FederatedAuthException(
      'Google 紋章入口已預留；目前 repo 尚未接上 Firebase 與後端驗章流程，先用玩家 ID + PIN 進館。',
    );
  }
}

class _NeverHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw StateError('Network should not be called in widget tests');
  }
}

class _LoggedOutAuthController extends AuthController {
  _LoggedOutAuthController()
    : super(
        authApi: AuthApiClient(
          baseUrl: 'http://127.0.0.1:18080',
          httpClient: _NeverHttpClient(),
        ),
        storage: const FlutterSecureStorage(),
        restoreOnInit: false,
      ) {
    state = const AsyncValue.data(null);
  }

  @override
  Future<AuthSession> loginPlayer({
    required String playerId,
    required String pinCode,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> registerPlayer({
    required String playerId,
    required String pinCode,
    required String displayName,
    String? avatarType,
  }) async {
    throw UnimplementedError();
  }
}

class _SuccessfulAuthController extends AuthController {
  _SuccessfulAuthController()
    : super(
        authApi: AuthApiClient(
          baseUrl: 'http://127.0.0.1:18080',
          httpClient: _NeverHttpClient(),
        ),
        storage: const FlutterSecureStorage(),
        restoreOnInit: false,
      ) {
    state = const AsyncValue.data(null);
  }

  @override
  Future<AuthSession> loginPlayer({
    required String playerId,
    required String pinCode,
  }) async {
    final session = AuthSession(
      accessToken: 'test-token',
      guildId: '00000000-0000-0000-0000-000000000001',
      hunterId: '00000000-0000-0000-0000-000000000011',
      guildRole: GuildRole.member,
      playerId: playerId,
      displayName: 'Demo Master',
    );
    state = AsyncValue.data(session);
    return session;
  }

  @override
  Future<AuthSession> registerPlayer({
    required String playerId,
    required String pinCode,
    required String displayName,
    String? avatarType,
  }) async {
    throw UnimplementedError();
  }
}

class _NoopProductAnalytics extends ProductAnalytics {
  _NoopProductAnalytics()
    : super(
        api: ApiClient(
          baseUrl: 'http://127.0.0.1:18080',
          authSession: null,
          httpClient: _NeverHttpClient(),
        ),
        environment: AppEnvironment.local,
        language: AppLanguage.traditionalChinese,
      );

  @override
  void track(
    String eventName, {
    String status = 'ok',
    Map<String, dynamic> properties = const <String, dynamic>{},
    bool allowPublic = false,
  }) {}
}
