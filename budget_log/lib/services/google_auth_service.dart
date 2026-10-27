import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleAuthService {
  static const String webClientId =
      '946718224112-nnsndg46igdloksr9fvg8q0nk9e5ra47.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? webClientId : null,
    serverClientId: webClientId,
    scopes: <String>['email', drive.DriveApi.driveAppdataScope],
  );
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  GoogleSignIn get googleSignIn => _googleSignIn;
  FirebaseAuth get firebaseAuth => _firebaseAuth;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;
  Stream<User?> get onAuthStateChanged => _firebaseAuth.authStateChanges();

  bool get isSignedIn =>
      _googleSignIn.currentUser != null || _firebaseAuth.currentUser != null;

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        await _authenticateWithFirebase(account);
      }
      return account;
    } catch (error) {
      debugPrint('[GoogleAuthService] Silent sign-in error: $error');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    debugPrint('[GoogleAuthService] Initiating Google Sign-In...');
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        debugPrint('[GoogleAuthService] Signed in as: ${account.email}');
        await _authenticateWithFirebase(account);
      } else {
        debugPrint('[GoogleAuthService] Sign-in cancelled by user.');
      }
      return account;
    } catch (error) {
      debugPrint('[GoogleAuthService] Google Sign-In error: $error');
      final message = error.toString();
      if (message.contains('ApiException: 10') ||
          message.contains('status 10') ||
          message.contains('code 10')) {
        throw Exception(
          'Developer Error (ApiException 10):\n'
          'Register an Android OAuth client for this app in Google Cloud.\n\n'
          'Package name: in.logapp.budget_log\n'
          'SHA-1: 85:44:F8:1E:1B:15:B6:08:DA:3F:27:24:5C:DA:FC:E4:68:F4:C7:9C',
        );
      }
      if (message.contains('12500')) {
        throw Exception(
          'Google Sign-In failed (ApiException 12500).\n'
          'Ensure the OAuth consent screen is configured and this Google '
          'account is listed under Test Users.',
        );
      }
      rethrow;
    }
  }

  Future<UserCredential?> _authenticateWithFirebase(
    GoogleSignInAccount account,
  ) async {
    try {
      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      debugPrint(
        '[GoogleAuthService] Firebase authenticated successfully with UID: ${userCredential.user?.uid}',
      );
      return userCredential;
    } catch (e) {
      debugPrint('[GoogleAuthService] Firebase credential sign-in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      try {
        await _googleSignIn.disconnect();
      } catch (error) {
        debugPrint('[GoogleAuthService] Disconnect error (ignored): $error');
      }
      try {
        await _firebaseAuth.signOut();
      } catch (error) {
        debugPrint(
          '[GoogleAuthService] Firebase sign-out error (ignored): $error',
        );
      }
      debugPrint('[GoogleAuthService] Signed out.');
    } catch (error) {
      debugPrint('[GoogleAuthService] Sign-out error: $error');
      rethrow;
    }
  }
}
