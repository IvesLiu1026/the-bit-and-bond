import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:the_bit_and_bond_client/app/app.dart';
import 'package:the_bit_and_bond_client/core/auth/auth_session.dart';
import 'package:the_bit_and_bond_client/core/auth/google_federated_auth_service.dart';
import 'package:the_bit_and_bond_client/core/network/auth_api_client.dart';
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
