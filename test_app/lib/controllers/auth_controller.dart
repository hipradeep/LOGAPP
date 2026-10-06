import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/google_auth_service.dart';

class AuthController extends ChangeNotifier {
  final GoogleAuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthController(this._authService) {
    _currentUser = _authService.currentUser;
    _authSubscription = _authService.authStateChanges.listen((User? user) {
      _currentUser = user;
      debugPrint('🔄 [AuthController] Auth state changed: User = ${user?.email ?? "Signed Out"}');
      notifyListeners();
    });
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GoogleAuthService get authService => _authService;

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authService.signInWithGoogle();
      _isLoading = false;
      if (credential == null) {
        _errorMessage = 'Sign in was cancelled';
        notifyListeners();
        return false;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      final errorStr = e.toString();
      if (errorStr.contains('ApiException: 10')) {
        _errorMessage =
            'Developer Error (ApiException: 10): Debug SHA-1 fingerprint is not added in Firebase Console.';
      } else if (errorStr.contains('ApiException: 12500')) {
        _errorMessage =
            'OAuth Error (ApiException: 12500): Support email or consent screen missing in GCP Console.';
      } else {
        _errorMessage = errorStr;
      }
      debugPrint('🚨 [AuthController] Sign-In Failed: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signOut();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
