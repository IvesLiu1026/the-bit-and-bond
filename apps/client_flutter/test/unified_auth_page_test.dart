import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:chen_leveling_client/core/auth/auth_session.dart';
import 'package:chen_leveling_client/core/network/auth_api_client.dart';
import 'package:chen_leveling_client/features/auth/unified_auth_page.dart';
import 'package:chen_leveling_client/state/auth_controller.dart';
import 'package:chen_leveling_client/state/providers.dart';

void main() {
  testWidgets('shows inline validation error for empty login input', (
    WidgetTester tester,
  ) async {
    final fake = _FakeAuthController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith((ref) => fake)],
        child: const MaterialApp(home: UnifiedAuthPage()),
      ),
    );

    await tester.tap(find.text('登入遊戲'));
    await tester.pump();

    expect(find.text('請輸入帳號（玩家ID或Email）'), findsOneWidget);
    expect(fake.loginCalled, isFalse);
  });

  testWidgets('register mode validates player id and pin format', (
    WidgetTester tester,
  ) async {
    final fake = _FakeAuthController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith((ref) => fake)],
        child: const MaterialApp(home: UnifiedAuthPage()),
      ),
    );

    await tester.tap(find.text('註冊'));
    await tester.pump();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'test@example.com');
    await tester.enterText(fields.at(1), '1234');
    await tester.enterText(fields.at(2), '測試玩家');
    await tester.ensureVisible(find.text('註冊並開始'));
    await tester.tap(find.text('註冊並開始'));
    await tester.pump();

    expect(find.text('註冊請使用玩家 ID，不要使用 Email'), findsOneWidget);
    expect(fake.registerCalled, isFalse);
  });

  testWidgets('register mode can submit valid payload', (
    WidgetTester tester,
  ) async {
    final fake = _FakeAuthController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith((ref) => fake)],
        child: const MaterialApp(home: UnifiedAuthPage()),
      ),
    );

    await tester.tap(find.text('註冊'));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'demo_member');
    await tester.enterText(fields.at(1), '1357');
    await tester.enterText(fields.at(2), 'Demo Member');
    await tester.ensureVisible(find.text('註冊並開始'));
    await tester.tap(find.text('註冊並開始'));
    await tester.pump();

    expect(fake.registerCalled, isTrue);
    expect(find.text('註冊請使用玩家 ID，不要使用 Email'), findsNothing);
  });
}

class _NeverHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw StateError('Network should not be called in widget tests');
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController()
    : super(
        authApi: AuthApiClient(
          baseUrl: 'http://127.0.0.1:18080',
          httpClient: _NeverHttpClient(),
        ),
        storage: const FlutterSecureStorage(),
        restoreOnInit: false,
      );

  bool loginCalled = false;
  bool registerCalled = false;

  @override
  Future<AuthSession> loginPlayer({
    required String playerId,
    required String pinCode,
  }) async {
    loginCalled = true;
    return const AuthSession(
      accessToken: 'token',
      guildId: 'guild',
      hunterId: 'hunter',
      guildRole: GuildRole.member,
    );
  }

  @override
  Future<AuthSession> registerPlayer({
    required String playerId,
    required String pinCode,
    required String displayName,
    String? avatarType,
  }) async {
    registerCalled = true;
    return const AuthSession(
      accessToken: 'token',
      guildId: 'guild',
      hunterId: 'hunter',
      guildRole: GuildRole.member,
    );
  }
}
