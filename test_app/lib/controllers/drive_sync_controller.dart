import 'package:flutter/foundation.dart';
import '../models/test_item.dart';
import '../services/google_drive_service.dart';

class DriveSyncController extends ChangeNotifier {
  final GoogleDriveService _driveService;

  final List<TestItem> _items = [];
  bool _isSyncing = false;
  bool _isRestoring = false;
  DateTime? _lastSyncTime;
  String? _statusMessage;
  String? _errorMessage;

  DriveSyncController(this._driveService);

  List<TestItem> get items => List.unmodifiable(_items);
  bool get isSyncing => _isSyncing;
  bool get isRestoring => _isRestoring;
  bool get isBusy => _isSyncing || _isRestoring;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;

  void addTestItem(String content) {
    if (content.trim().isEmpty) return;
    final newItem = TestItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content.trim(),
      createdAt: DateTime.now(),
      isSynced: false,
    );
    _items.insert(0, newItem);
    _statusMessage = 'Added "${newItem.content}". Tap Sync to backup to Drive.';
    _errorMessage = null;
    notifyListeners();
  }

  void removeTestItem(String id) {
    _items.removeWhere((item) => item.id == id);
    _statusMessage = 'Item removed. Remember to sync to update Drive.';
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> syncToDrive() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _errorMessage = null;
    _statusMessage = 'Uploading backup to Google Drive...';
    notifyListeners();

    try {
      final fileId = await _driveService.syncTestItemsToDrive(_items);
      
      // Mark all items as synced
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(isSynced: true);
      }

      _lastSyncTime = DateTime.now();
      _statusMessage = 'Successfully synced ${_items.length} items to Drive (File: $fileId)';
    } catch (e) {
      _errorMessage = 'Sync failed: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> restoreFromDrive() async {
    if (_isRestoring) return;

    _isRestoring = true;
    _errorMessage = null;
    _statusMessage = 'Fetching backup from Google Drive...';
    notifyListeners();

    try {
      final restoredItems = await _driveService.restoreTestItemsFromDrive();
      _items.clear();
      _items.addAll(restoredItems);
      _lastSyncTime = DateTime.now();
      _statusMessage = 'Restored ${restoredItems.length} items from Drive backup';
    } catch (e) {
      _errorMessage = 'Restore failed: $e';
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  void clearStatus() {
    _statusMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _items.clear();
    _lastSyncTime = null;
    _statusMessage = null;
    _errorMessage = null;
    _isSyncing = false;
    _isRestoring = false;
    notifyListeners();
  }
}
