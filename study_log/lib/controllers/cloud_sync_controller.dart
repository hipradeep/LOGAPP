import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';
import '../services/database_backup_service.dart';
import '../services/database_service.dart';
import '../services/google_auth_service.dart';
import '../services/google_drive_service.dart';
import '../services/service_locator.dart';
import 'courses_controller.dart';
import 'notification_controller.dart';
import 'ongoing_modules_controller.dart';
import 'progress_controller.dart';
import 'revision_controller.dart';

/// Controller coordinating Google Sign-In and Google Drive Cloud Sync.
///
/// Ensures clean data isolation when switching accounts:
/// • Automatically restores incoming account's Google Drive backup.
/// • If incoming account has no backup, clears previous user's data to start fresh.
/// • Updates SQLite UserProfile and all UI controllers seamlessly.
class CloudSyncController extends ChangeNotifier {
  final GoogleAuthService _authService;
  final GoogleDriveService _driveService;
  final DatabaseBackupService _backupService;
  final DatabaseService _dbService;

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
    DatabaseService? dbService,
  })  : _authService = authService ?? getIt<GoogleAuthService>(),
        _driveService = driveService ?? getIt<GoogleDriveService>(),
        _backupService = backupService ?? getIt<DatabaseBackupService>(),
        _dbService = dbService ?? getIt<DatabaseService>() {
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
  bool get isBusy =>
      _isSigningIn ||
      _isSyncing ||
      _isRestoring ||
      _isExportingFile ||
      _isImportingFile;
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
        final activeEmail = await _getActiveEmail();
        final newEmail = account.email.trim().toLowerCase();
        if (activeEmail != null && activeEmail.isNotEmpty && activeEmail != newEmail) {
          await _handlePostSignIn(account);
        } else {
          await _fetchLastBackupTime();
        }
      }
    } catch (_) {}
  }

  Future<String?> _getActiveEmail() async {
    final saved = await _dbService.getSetting('active_account_email');
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim().toLowerCase();
    }
    final profile = await _dbService.getUserProfile();
    return profile?.email?.trim().toLowerCase();
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

  /// Sign in with Google account and isolate data if switching account.
  Future<bool> signIn() async {
    _isSigningIn = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final account = await _authService.signIn();
      if (account != null) {
        await _handlePostSignIn(account);
        _isSigningIn = false;
        notifyListeners();
        return true;
      }
      _isSigningIn = false;
      _errorMessage = 'No Google account selected.';
      notifyListeners();
      return false;
    } catch (e) {
      _isSigningIn = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Handles account data isolation, cloud backup restoration, and profile sync.
  Future<void> _handlePostSignIn(GoogleSignInAccount account) async {
    final newEmail = account.email.trim().toLowerCase();
    final previousEmail = await _getActiveEmail();
    final isAccountSwitch = previousEmail != null &&
        previousEmail.isNotEmpty &&
        previousEmail != newEmail;

    debugPrint('[CloudSyncController] Signed in: $newEmail (prev: $previousEmail, switch: $isAccountSwitch)');

    if (isAccountSwitch) {
      // 1. Wipe previous account's data so there is zero leakage
      await _dbService.clearAllData();
      _resetControllersInMemory();

      // 2. Fetch the incoming account's Google Drive backup
      final cloudBackup = await _driveService.restoreDatabase();
      if (cloudBackup != null) {
        debugPrint('[CloudSyncController] Restoring cloud backup for $newEmail');
        await _backupService.importAllFromJson(cloudBackup);
      } else {
        debugPrint('[CloudSyncController] No existing cloud backup found for $newEmail. Initialized clean state.');
      }
    } else {
      // Not an account switch: check if local database is currently empty
      final localCourses = await _dbService.getCourses();
      if (localCourses.isEmpty) {
        final cloudBackup = await _driveService.restoreDatabase();
        if (cloudBackup != null) {
          debugPrint('[CloudSyncController] Hydrating empty device from cloud backup for $newEmail');
          await _backupService.importAllFromJson(cloudBackup);
        }
      }
    }

    // Ensure the SQLite user_profile matches the active Google account details
    final existingProfile = await _dbService.getUserProfile();
    final nowTime = DateTime.now();
    final updatedProfile = (existingProfile ??
            UserProfile(
              id: 'profile',
              createdAt: nowTime,
              updatedAt: nowTime,
            ))
        .copyWith(
      name: (account.displayName != null && account.displayName!.trim().isNotEmpty)
          ? account.displayName!.trim()
          : (existingProfile?.name.isNotEmpty == true ? existingProfile!.name : 'Student'),
      headline: (existingProfile?.headline.isNotEmpty == true)
          ? existingProfile!.headline
          : 'Learner',
      email: account.email,
      avatarUrl: account.photoUrl ?? existingProfile?.avatarUrl,
      updatedAt: nowTime,
    );

    await _dbService.saveUserProfile(updatedProfile);
    await _dbService.setSetting('active_account_email', newEmail);

    // Refresh all reactive controllers so the UI updates instantly
    await _refreshAllControllers();
    await _fetchLastBackupTime();
  }

  void _resetControllersInMemory() {
    if (getIt.isRegistered<CoursesController>()) {
      getIt<CoursesController>().clear();
    }
    if (getIt.isRegistered<ProgressController>()) {
      getIt<ProgressController>().reset();
    }
  }

  Future<void> _refreshAllControllers() async {
    if (getIt.isRegistered<CoursesController>()) {
      await getIt<CoursesController>().loadCourses();
    }
    if (getIt.isRegistered<OngoingModulesController>()) {
      await getIt<OngoingModulesController>().refresh();
    }
    if (getIt.isRegistered<RevisionController>()) {
      await getIt<RevisionController>().reconcile();
    }
    if (getIt.isRegistered<ProgressController>()) {
      await getIt<ProgressController>().load();
    }
    if (getIt.isRegistered<NotificationController>()) {
      await getIt<NotificationController>().syncAllNotifications();
    }
  }

  /// Signs out from Google on this device:
  /// 1. Automatically pushes latest study data to Google Drive.
  /// 2. Clears all local SQLite data and resets in-memory controllers.
  /// 3. Signs out and disconnects Google session.
  Future<void> signOut() async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Automatically push to Google Drive before clearing local
      if (isSignedIn) {
        try {
          final payload = await _backupService.exportAllToJson();
          await _driveService.backupDatabase(payload);
          debugPrint('[CloudSyncController] Auto-backup pushed to Drive before logout.');
        } catch (e) {
          debugPrint('[CloudSyncController] Drive push before logout non-fatal error: $e');
        }
      }

      // 2. Clear local SQLite data so device is clean
      await _dbService.clearAllData();
      await _dbService.deleteSetting('active_account_email');
      _resetControllersInMemory();
      await _refreshAllControllers();

      // 3. Sign out and disconnect Google account
      await _authService.signOut();
      _lastBackupDate = null;
      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _isSyncing = false;
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
      await _refreshAllControllers();

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
        await _refreshAllControllers();
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
