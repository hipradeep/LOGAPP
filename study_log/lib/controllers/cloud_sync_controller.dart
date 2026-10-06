import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/database_backup_service.dart';
import '../services/google_auth_service.dart';
import '../services/google_drive_service.dart';
import '../services/service_locator.dart';
import 'courses_controller.dart';
import 'ongoing_modules_controller.dart';
import 'progress_controller.dart';
import 'revision_controller.dart';

/// Controller coordinating Google Sign-In and Google Drive Cloud Sync.
///
/// Backs up the entire SQLite state to the user's private Google Drive `appDataFolder`
/// without requiring server infrastructure or Firebase Auth.
class CloudSyncController extends ChangeNotifier {
  final GoogleAuthService _authService;
  final GoogleDriveService _driveService;
  final DatabaseBackupService _backupService;

  bool _isSigningIn = false;
  bool _isSyncing = false;
  bool _isRestoring = false;
  bool _isExportingFile = false;
  bool _isImportingFile = false;
  String? _errorMessage;
  DateTime? _lastBackupDate;

  CloudSyncController({
    GoogleAuthService? authService,
    GoogleDriveService? driveService,
    DatabaseBackupService? backupService,
  })  : _authService = authService ?? getIt<GoogleAuthService>(),
        _driveService = driveService ?? getIt<GoogleDriveService>(),
        _backupService = backupService ?? getIt<DatabaseBackupService>() {
    _authService.onCurrentUserChanged.listen((account) {
      if (account != null) {
        _fetchLastBackupTime();
      } else {
        _lastBackupDate = null;
      }
      notifyListeners();
    });
    unawaited(init());
  }

  bool get isSigningIn => _isSigningIn;
  bool get isSyncing => _isSyncing;
  bool get isRestoring => _isRestoring;
  bool get isExportingFile => _isExportingFile;
  bool get isImportingFile => _isImportingFile;
  bool get isBusy => _isSigningIn || _isSyncing || _isRestoring || _isExportingFile || _isImportingFile;
  String? get errorMessage => _errorMessage;
  DateTime? get lastBackupDate => _lastBackupDate;

  bool get isSignedIn => _authService.isSignedIn;
  String? get userEmail => _authService.currentUser?.email;
  String? get displayName => _authService.currentUser?.displayName;
  String? get photoUrl => _authService.currentUser?.photoUrl;

  Future<void> init() async {
    try {
      final account = await _authService.signInSilently();
      if (account != null) {
        await _fetchLastBackupTime();
      }
    } catch (_) {}
  }

  Future<void> _fetchLastBackupTime() async {
    try {
      final timestamp = await _driveService.getLastBackupTimestamp();
      if (timestamp != null) {
        _lastBackupDate = timestamp;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Sign in with Google account and grant Drive AppData scope.
  Future<bool> signIn() async {
    _isSigningIn = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final account = await _authService.signIn();
      if (account != null) {
        await _fetchLastBackupTime();
        _isSigningIn = false;
        notifyListeners();
        return true;
      }
      _isSigningIn = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isSigningIn = false;
      _errorMessage = 'Sign in failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Signs out from Google on this device.
  Future<void> signOut() async {
    _errorMessage = null;
    try {
      await _authService.signOut();
      _lastBackupDate = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Sign out error: $e';
      notifyListeners();
    }
  }

  /// Backs up the local SQLite database to Google Drive `appDataFolder`.
  Future<bool> backupToDrive() async {
    if (!isSignedIn) {
      final signedIn = await signIn();
      if (!signedIn) return false;
    }

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = await _backupService.exportAllToJson();
      await _driveService.backupDatabase(payload);
      _lastBackupDate = DateTime.now();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSyncing = false;
      _errorMessage = 'Cloud backup failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Restores the SQLite database from the Google Drive `appDataFolder`.
  Future<bool> restoreFromDrive() async {
    if (!isSignedIn) {
      final signedIn = await signIn();
      if (!signedIn) return false;
    }

    _isRestoring = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _driveService.restoreDatabase();
      if (data == null) {
        _isRestoring = false;
        _errorMessage = 'No existing backup found in your Google Drive.';
        notifyListeners();
        return false;
      }

      await _backupService.importAllFromJson(data);

      // Trigger full UI controller refresh
      if (getIt.isRegistered<CoursesController>()) {
        getIt<CoursesController>().refresh();
      }
      if (getIt.isRegistered<OngoingModulesController>()) {
        await getIt<OngoingModulesController>().refresh();
      }
      if (getIt.isRegistered<RevisionController>()) {
        await getIt<RevisionController>().reconcile();
      }
      if (getIt.isRegistered<ProgressController>()) {
        await getIt<ProgressController>().refresh();
      }

      _isRestoring = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isRestoring = false;
      _errorMessage = 'Cloud restore failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Exports local database snapshot to a file chosen by the user.
  Future<String?> exportToLocalFile() async {
    _isExportingFile = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final path = await _backupService.exportToFile();
      _isExportingFile = false;
      notifyListeners();
      return path;
    } catch (e) {
      _isExportingFile = false;
      _errorMessage = 'Export failed: $e';
      notifyListeners();
      return null;
    }
  }

  /// Imports database snapshot from a local file chosen by the user.
  Future<bool> importFromLocalFile() async {
    _isImportingFile = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _backupService.importFromFile();
      if (success) {
        if (getIt.isRegistered<CoursesController>()) {
          getIt<CoursesController>().refresh();
        }
        if (getIt.isRegistered<OngoingModulesController>()) {
          await getIt<OngoingModulesController>().refresh();
        }
        if (getIt.isRegistered<RevisionController>()) {
          await getIt<RevisionController>().reconcile();
        }
        if (getIt.isRegistered<ProgressController>()) {
          await getIt<ProgressController>().refresh();
        }
      }
      _isImportingFile = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isImportingFile = false;
      _errorMessage = 'Import failed: $e';
      notifyListeners();
      return false;
    }
  }
}
