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
      final errStr = e.toString();
      if (errStr.contains('ApiException: 10') || errStr.contains('status 10') || errStr.contains('code 10')) {
        throw Exception(
          'Developer Error (ApiException 10):\n'
          'Your Android OAuth Client ID is not registered in Google Cloud.\n\n'
          'Go to Google Cloud Console > Credentials for project study-log-365ee and add an Android Client ID with:\n'
          '• Package name: com.logapp.studylog\n'
          '• SHA-1: 85:44:F8:1E:1B:15:B6:08:DA:3F:27:24:5C:DA:FC:E4:68:F4:C7:9C',
        );
      } else if (errStr.contains('12500')) {
        throw Exception(
          'Google Sign-In failed (ApiException 12500).\n'
          'Please ensure OAuth consent screen is configured and your Google account is added under Test Users.',
        );
      }
      rethrow;
    }
  }

  /// Disconnects and signs out from Google on this device.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      try {
        await _googleSignIn.disconnect();
      } catch (e) {
        debugPrint('[GoogleAuthService] Disconnect error (ignored): $e');
      }
      debugPrint('[GoogleAuthService] Signed out.');
    } catch (e) {
      debugPrint('[GoogleAuthService] Sign-out error: $e');
      rethrow;
    }
  }
}
