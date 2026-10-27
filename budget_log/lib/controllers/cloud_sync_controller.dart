import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/database_backup_service.dart';
import '../services/database_service.dart';
import '../services/google_auth_service.dart';
import '../services/google_drive_service.dart';

class CloudSyncController extends ChangeNotifier with WidgetsBindingObserver {
  CloudSyncController({
    required GoogleAuthService authService,
    required GoogleDriveService driveService,
    required DatabaseBackupService backupService,
    required DatabaseService dbService,
  }) : _authService = authService,
       _driveService = driveService,
       _backupService = backupService,
       _dbService = dbService {
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _authService.onCurrentUserChanged.listen((account) {
      if (account != null) {
        _cachedActiveEmail = account.email.trim().toLowerCase();
        _cachedDisplayName = account.displayName?.trim();
        _cachedPhotoUrl = account.photoUrl;
        unawaited(_fetchLastBackupTime());
      } else {
        _cachedActiveEmail = null;
        _cachedDisplayName = null;
        _cachedPhotoUrl = null;
        _lastBackupDate = null;
      }
      notifyListeners();
    });
    _dbChangeSubscription = _dbService.onDatabaseChanged.listen(
      _onDatabaseChanged,
    );
  }

  final GoogleAuthService _authService;
  final GoogleDriveService _driveService;
  final DatabaseBackupService _backupService;
  final DatabaseService _dbService;

  static const Duration _debounceDuration = Duration(seconds: 4);

  Timer? _debounceTimer;
  StreamSubscription<String>? _dbChangeSubscription;
  StreamSubscription<GoogleSignInAccount?>? _authSubscription;

  bool _isSigningIn = false;
  bool _isSyncing = false;
  bool _isRestoring = false;
  bool _isAutoSyncing = false;
  bool _isExportingFile = false;
  bool _isImportingFile = false;
  bool _isCheckingAuth = true;
  String? _cachedActiveEmail;
  String? _cachedDisplayName;
  String? _cachedPhotoUrl;
  String? _errorMessage;
  DateTime? _lastBackupDate;

  bool get isSigningIn => _isSigningIn;
  bool get isSyncing => _isSyncing;
  bool get isRestoring => _isRestoring;
  bool get isAutoSyncing => _isAutoSyncing;
  bool get isExportingFile => _isExportingFile;
  bool get isImportingFile => _isImportingFile;
  bool get isCheckingAuth => _isCheckingAuth;
  bool get isBusy =>
      _isSigningIn ||
      _isSyncing ||
      _isRestoring ||
      _isExportingFile ||
      _isImportingFile;
  bool get isSignedIn => _authService.isSignedIn;
  String? get errorMessage => _errorMessage;
  DateTime? get lastBackupDate => _lastBackupDate;
  String? get userEmail =>
      _authService.currentUser?.email ?? _cachedActiveEmail;
  String? get displayName =>
      _authService.currentUser?.displayName ?? _cachedDisplayName;
  String? get photoUrl => _authService.currentUser?.photoUrl ?? _cachedPhotoUrl;

  Future<void> init() async {
    try {
      _cachedActiveEmail = await _dbService.getSetting('active_account_email');
      final account = await _authService.signInSilently();
      if (account != null) {
        await _handlePostSignIn(account);
      }
    } catch (error) {
      debugPrint('[CloudSyncController] Init error: $error');
    } finally {
      _isCheckingAuth = false;
      notifyListeners();
    }
  }

  Future<bool> signIn() async {
    _isSigningIn = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final account = await _authService.signIn();
      if (account == null) {
        _isSigningIn = false;
        _errorMessage = 'No Google account selected.';
        notifyListeners();
        return false;
      }
      await _handlePostSignIn(account);
      _isSigningIn = false;
      notifyListeners();
      return true;
    } catch (error) {
      _isSigningIn = false;
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (isSignedIn) {
        try {
          final payload = await _backupService.exportAllToJson();
          await _driveService.backupDatabase(payload);
        } catch (error) {
          debugPrint(
            '[CloudSyncController] Backup before sign-out failed: $error',
          );
        }
      }
      await _authService.signOut();
      _cachedActiveEmail = null;
      _cachedDisplayName = null;
      _cachedPhotoUrl = null;
      _lastBackupDate = null;
    } catch (error) {
      _errorMessage = 'Sign out error: $error';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

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
      await _dbService.setSetting(
        'last_backup_at',
        _lastBackupDate!.toIso8601String(),
        notify: false,
      );
      return true;
    } catch (error) {
      _errorMessage = 'Cloud backup failed: $error';
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

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
        _errorMessage = 'No existing backup found in your Google Drive.';
        return false;
      }

      final account = _authService.currentUser;
      await _backupService.importAllFromJson(data);
      if (account != null) {
        await _dbService.setSetting(
          'active_account_email',
          account.email.trim().toLowerCase(),
          notify: false,
        );
      }
      await _dbService.setSetting(
        'database_initialized',
        'true',
        notify: false,
      );
      await _dbService.reloadAllStreams();
      await _fetchLastBackupTime();
      return true;
    } catch (error) {
      _errorMessage = 'Cloud restore failed: $error';
      return false;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<String?> exportToLocalFile() async {
    _isExportingFile = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _backupService.exportToFile();
    } catch (error) {
      _errorMessage = 'Export failed: $error';
      return null;
    } finally {
      _isExportingFile = false;
      notifyListeners();
    }
  }

  Future<bool> importFromLocalFile() async {
    _isImportingFile = true;
    _errorMessage = null;
    notifyListeners();

    final activeEmail = await _dbService.getSetting('active_account_email');

    try {
      final success = await _backupService.importFromFile();
      if (success) {
        if (activeEmail != null && activeEmail.isNotEmpty) {
          await _dbService.setSetting(
            'active_account_email',
            activeEmail,
            notify: false,
          );
        }
        await _dbService.setSetting(
          'database_initialized',
          'true',
          notify: false,
        );
        await _dbService.reloadAllStreams();
      }
      return success;
    } catch (error) {
      _errorMessage = 'Import failed: $error';
      return false;
    } finally {
      _isImportingFile = false;
      notifyListeners();
    }
  }

  Future<void> _handlePostSignIn(GoogleSignInAccount account) async {
    final newEmail = account.email.trim().toLowerCase();
    final previousEmail = await _dbService.getSetting('active_account_email');
    final isInitialized =
        await _dbService.getSetting('database_initialized') == 'true';
    final isAccountSwitch =
        previousEmail != null &&
        previousEmail.isNotEmpty &&
        previousEmail != newEmail;
    final shouldRestore =
        isAccountSwitch || (!isInitialized && !(await _hasLocalData()));

    _isRestoring = shouldRestore;

    try {
      if (isAccountSwitch) {
        await _dbService.clearAllData();
      }

      if (shouldRestore) {
        final cloudBackup = await _driveService.restoreDatabase();
        if (cloudBackup != null) {
          await _backupService.importAllFromJson(cloudBackup);
        }
      }

      _cachedActiveEmail = newEmail;
      _cachedDisplayName = account.displayName?.trim();
      _cachedPhotoUrl = account.photoUrl;

      await _dbService.setSetting(
        'active_account_email',
        newEmail,
        notify: false,
      );
      await _dbService.setSetting(
        'database_initialized',
        'true',
        notify: false,
      );
      await _dbService.reloadAllStreams();
      await _fetchLastBackupTime();
    } finally {
      _isRestoring = false;
    }
  }

  Future<bool> _hasLocalData() async {
    final transactions = await _dbService.getTransactions();
    if (transactions.isNotEmpty) return true;
    final budgets = await _dbService.getBudgets();
    if (budgets.isNotEmpty) return true;
    final contacts = await _dbService.getContacts();
    if (contacts.isNotEmpty) return true;
    final debts = await _dbService.getDebtRecords();
    if (debts.isNotEmpty) return true;
    final subscriptions = await _dbService.getSubscriptions();
    if (subscriptions.isNotEmpty) return true;
    final stagedSms = await _dbService.getStagedSmsTransactions();
    return stagedSms.isNotEmpty;
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

  void _onDatabaseChanged(String _) {
    if (!isSignedIn ||
        _isRestoring ||
        _isSyncing ||
        _isAutoSyncing ||
        _isImportingFile) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(_executeBackgroundDrivePush());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_debounceTimer?.isActive == true) {
        _debounceTimer?.cancel();
        unawaited(_executeBackgroundDrivePush());
      }
    }
  }

  Future<void> _executeBackgroundDrivePush() async {
    if (!isSignedIn || _isSyncing || _isRestoring || _isAutoSyncing) {
      return;
    }

    _isAutoSyncing = true;
    notifyListeners();

    try {
      final payload = await _backupService.exportAllToJson();
      await _driveService.backupDatabase(payload);
      _lastBackupDate = DateTime.now();
    } catch (error) {
      debugPrint('[CloudSyncController] Background Drive push failed: $error');
    } finally {
      _isAutoSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _dbChangeSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
