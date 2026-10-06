import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '901601418143-8fsjfc9qu09bll6416r60cffknj651h3.apps.googleusercontent.com',
    scopes: <String>[
      'email',
      drive.DriveApi.driveAppdataScope,
    ],
  );

  GoogleSignIn get googleSignIn => _googleSignIn;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  GoogleSignInAccount? get currentGoogleAccount => _googleSignIn.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    debugPrint('==================================================');
    debugPrint('🔑 [GoogleAuthService] Initiating Google Sign-In...');
    debugPrint('🔑 [GoogleAuthService] Scopes: ${[
      'email',
      drive.DriveApi.driveAppdataScope
    ]}');

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ [GoogleAuthService] Sign-in was cancelled by user.');
        debugPrint('==================================================');
        return null;
      }

      debugPrint('✅ [GoogleAuthService] Account Selected:');
      debugPrint('   - Name: ${googleUser.displayName}');
      debugPrint('   - Email: ${googleUser.email}');
      debugPrint('   - ID: ${googleUser.id}');

      debugPrint('🔑 [GoogleAuthService] Fetching authentication tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      debugPrint('✅ [GoogleAuthService] Tokens received:');
      debugPrint('   - Has Access Token: ${googleAuth.accessToken != null}');
      debugPrint('   - Has ID Token: ${googleAuth.idToken != null}');

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('🔥 [GoogleAuthService] Signing into Firebase Auth with credentials...');
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      debugPrint('✅ [GoogleAuthService] Firebase User Authenticated:');
      debugPrint('   - UID: ${userCredential.user?.uid}');
      debugPrint('   - Email: ${userCredential.user?.email}');
      debugPrint('==================================================');
      return userCredential;
    } catch (e) {
      debugPrint('❌ [GoogleAuthService] Error during Google Sign-In: $e');
      if (e.toString().contains('ApiException: 10')) {
        debugPrint('🚨 [GoogleAuthService] DEVELOPER ERROR (ApiException: 10):');
        debugPrint('   This occurs because the SHA-1 fingerprint has not been added to');
        debugPrint('   your Firebase Console project settings or Google Cloud Console!');
      }
      debugPrint('==================================================');
      rethrow;
    }
  }

  Future<void> signOut() async {
    debugPrint('👋 [GoogleAuthService] Signing out...');
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      debugPrint('✅ [GoogleAuthService] Successfully signed out.');
    } catch (e) {
      debugPrint('❌ [GoogleAuthService] Sign-out error: $e');
      rethrow;
    }
  }
}
