import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';

class GoogleFederatedIdentity {
  const GoogleFederatedIdentity({
    required this.firebaseIdToken,
    this.displayName,
    this.email,
  });

  final String firebaseIdToken;
  final String? displayName;
  final String? email;
}

class FederatedAuthException implements Exception {
  const FederatedAuthException(
    this.message, {
    this.cancelled = false,
    this.shouldShowFallbackForm = true,
  });

  final String message;
  final bool cancelled;
  final bool shouldShowFallbackForm;

  @override
  String toString() => 'FederatedAuthException($message)';
}

class GoogleFederatedAuthService {
  const GoogleFederatedAuthService();

  static bool _initializationAttempted = false;
  static bool _firebaseReady = false;

  static bool get platformSupported {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.android => true,
      _ => false,
    };
  }

  static Future<bool> ensureFirebaseReady() async {
    if (_initializationAttempted) {
      return _firebaseReady;
    }
    _initializationAttempted = true;
    if (!platformSupported) {
      _firebaseReady = false;
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _firebaseReady = true;
      return true;
    } catch (_) {
      _firebaseReady = false;
      return false;
    }
  }

  Future<GoogleFederatedIdentity> signIn() async {
    final ready = await ensureFirebaseReady();
    if (!ready) {
      throw const FederatedAuthException('Google 紋章尚未完成 Firebase 設定，先用玩家印記簽署。');
    }

    final googleSignIn = GoogleSignIn.instance;
    try {
      await googleSignIn.initialize(clientId: _clientIdForPlatform());
      await FirebaseAuth.instance.signOut();
      await googleSignIn.signOut();
    } catch (_) {
      // Best effort; account picker should still work even if sign-out fails.
    }

    try {
      if (!googleSignIn.supportsAuthenticate()) {
        throw const FederatedAuthException('這個平台目前不支援直接拉起 Google 紋章視窗。');
      }

      final googleUser = await googleSignIn.authenticate();

      final googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw const FederatedAuthException('Google 印記沒有帶回有效憑證。');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;
      final firebaseIdToken = await user?.getIdToken(true);
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw const FederatedAuthException('Firebase 沒有回傳可用的酒館契約 token。');
      }

      return GoogleFederatedIdentity(
        firebaseIdToken: firebaseIdToken,
        displayName: user?.displayName ?? googleUser.displayName,
        email: user?.email,
      );
    } on FederatedAuthException {
      rethrow;
    } on GoogleSignInException catch (error) {
      final code = error.code.name;
      if (code == 'canceled') {
        throw const FederatedAuthException(
          '你先把契約收起來了，沒關係，準備好再按一次就好。',
          cancelled: true,
          shouldShowFallbackForm: false,
        );
      }
      if (code == 'interrupted') {
        throw const FederatedAuthException(
          'Google 紋章視窗被打斷了，重新蓋章一次就可以。',
          shouldShowFallbackForm: false,
        );
      }
      throw FederatedAuthException(
        'Google 紋章簽署失敗：${error.description ?? error.code}',
        cancelled: code == 'canceled',
        shouldShowFallbackForm: code != 'canceled',
      );
    } on FirebaseAuthException catch (error) {
      final message = switch (error.code) {
        'operation-not-allowed' => 'Firebase Auth 的 Google provider 尚未啟用。',
        'network-request-failed' => 'Google 紋章暫時連不上，請稍後再試。',
        _ => 'Google 紋章簽署失敗：${error.message ?? error.code}',
      };
      throw FederatedAuthException(message);
    } catch (error) {
      throw FederatedAuthException('Google 紋章簽署失敗：$error');
    }
  }

  Future<GoogleFederatedIdentity?> tryRestoreIdentity() async {
    final ready = await ensureFirebaseReady();
    if (!ready) {
      return null;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return null;
      }
      final firebaseIdToken = await user.getIdToken(true);
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        return null;
      }
      return GoogleFederatedIdentity(
        firebaseIdToken: firebaseIdToken,
        displayName: user.displayName,
        email: user.email,
      );
    } catch (_) {
      return null;
    }
  }

  String? _clientIdForPlatform() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => DefaultFirebaseOptions.ios.iosClientId,
      _ => null,
    };
  }
}
