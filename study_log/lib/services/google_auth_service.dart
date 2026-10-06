import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Service managing native Google Sign-In without requiring Firebase Auth.
///
/// Requests authentication and authorization for the hidden Google Drive
/// [drive.DriveApi.driveAppdataScope] to sync SQLite backups to the user's
/// private cloud storage for free.
class GoogleAuthService {
  /// Web Client ID used as serverClientId on Android and clientId on Web.
  static const String webClientId =
      '946718224112-nnsndg46igdloksr9fvg8q0nk9e5ra47.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? webClientId : null,
    serverClientId: webClientId,
    scopes: <String>[
      'email',
      drive.DriveApi.driveAppdataScope,
    ],
  );

  GoogleSignIn get googleSignIn => _googleSignIn;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  bool get isSignedIn => _googleSignIn.currentUser != null;

  /// Attempts silent sign-in if the user previously authorized the app.
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('[GoogleAuthService] Silent sign-in error: $e');
      return null;
    }
  }

  /// Initiates interactive Google Sign-In with Drive AppData scope.
  Future<GoogleSignInAccount?> signIn() async {
    debugPrint('[GoogleAuthService] Initiating Google Sign-In...');
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        debugPrint('[GoogleAuthService] Signed in as: ${account.email}');
      } else {
        debugPrint('[GoogleAuthService] Sign-in cancelled by user.');
      }
      return account;
    } catch (e) {
      debugPrint('[GoogleAuthService] Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Disconnects and signs out from Google on this device.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('[GoogleAuthService] Signed out.');
    } catch (e) {
      debugPrint('[GoogleAuthService] Sign-out error: $e');
      rethrow;
    }
  }
}
