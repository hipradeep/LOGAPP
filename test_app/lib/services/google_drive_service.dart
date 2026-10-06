import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../models/test_item.dart';

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

class GoogleDriveService {
  final GoogleSignIn _googleSignIn;
  static const String backupFileName = 'test_app_drive_sync.json';

  GoogleDriveService(this._googleSignIn);

  Future<drive.DriveApi?> _getDriveApi() async {
    debugPrint('📁 [GoogleDriveService] Getting Google Drive API client...');
    final GoogleSignInAccount? account =
        _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) {
      debugPrint('❌ [GoogleDriveService] User is not signed in with Google.');
      throw StateError('User is not signed in with Google');
    }

    debugPrint('📁 [GoogleDriveService] Obtaining auth headers from account: ${account.email}');
    final authHeaders = await account.authHeaders;
    debugPrint('📁 [GoogleDriveService] Headers obtained: ${authHeaders.keys.toList()}');
    final authenticatedClient = _GoogleAuthClient(authHeaders);
    return drive.DriveApi(authenticatedClient);
  }

  /// Syncs / uploads test items to Google Drive in the hidden appDataFolder
  Future<String> syncTestItemsToDrive(List<TestItem> items) async {
    debugPrint('==================================================');
    debugPrint('🚀 [GoogleDriveService] Starting Sync to Drive...');
    debugPrint('   - Items to sync: ${items.length}');

    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw StateError('Drive API client is unavailable');
    }

    final payload = {
      'version': 1,
      'syncedAt': DateTime.now().toIso8601String(),
      'itemCount': items.length,
      'items': items.map((i) => i.copyWith(isSynced: true).toJson()).toList(),
    };

    final jsonString = jsonEncode(payload);
    final bytes = utf8.encode(jsonString);
    debugPrint('📦 [GoogleDriveService] Payload JSON size: ${bytes.length} bytes');

    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    // Search for existing file in appDataFolder
    final query = "name = '$backupFileName' and 'appDataFolder' in parents and trashed = false";
    debugPrint('🔍 [GoogleDriveService] Searching appDataFolder: $query');
    
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: query,
      $fields: 'files(id, name, modifiedTime)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final existingId = fileList.files!.first.id!;
      debugPrint('🔄 [GoogleDriveService] Existing file found (ID: $existingId). Updating content...');
      
      final updatedFile = await driveApi.files.update(
        drive.File(),
        existingId,
        uploadMedia: media,
      );
      final finalId = updatedFile.id ?? existingId;
      debugPrint('✅ [GoogleDriveService] File successfully updated on Drive: $finalId');
      debugPrint('==================================================');
      return finalId;
    } else {
      debugPrint('🆕 [GoogleDriveService] No existing file found. Creating new file in appDataFolder...');
      final newFile = drive.File()
        ..name = backupFileName
        ..parents = <String>['appDataFolder'];

      final createdFile = await driveApi.files.create(
        newFile,
        uploadMedia: media,
      );
      final finalId = createdFile.id ?? 'created';
      debugPrint('✅ [GoogleDriveService] New file successfully created on Drive: $finalId');
      debugPrint('==================================================');
      return finalId;
    }
  }

  /// Restores test items from Google Drive appDataFolder
  Future<List<TestItem>> restoreTestItemsFromDrive() async {
    debugPrint('==================================================');
    debugPrint('📥 [GoogleDriveService] Starting Restore from Drive...');

    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw StateError('Drive API client is unavailable');
    }

    final query = "name = '$backupFileName' and 'appDataFolder' in parents and trashed = false";
    debugPrint('🔍 [GoogleDriveService] Searching appDataFolder: $query');

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: query,
      $fields: 'files(id, name, modifiedTime)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      debugPrint('⚠️ [GoogleDriveService] No backup file found in Drive appDataFolder.');
      debugPrint('==================================================');
      return <TestItem>[];
    }

    final fileId = fileList.files!.first.id!;
    debugPrint('⬇️ [GoogleDriveService] Downloading backup file (ID: $fileId)...');
    
    final drive.Media downloadedMedia = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final List<int> dataBytes = <int>[];
    await for (final chunk in downloadedMedia.stream) {
      dataBytes.addAll(chunk);
    }

    final jsonString = utf8.decode(dataBytes);
    debugPrint('📦 [GoogleDriveService] Downloaded ${dataBytes.length} bytes of backup data');
    
    final Map<String, dynamic> data = jsonDecode(jsonString) as Map<String, dynamic>;
    final List<dynamic> itemsJson = data['items'] as List<dynamic>? ?? [];

    final result = itemsJson
        .map((e) => TestItem.fromJson(e as Map<String, dynamic>))
        .toList();

    debugPrint('✅ [GoogleDriveService] Successfully parsed ${result.length} items from Drive backup.');
    debugPrint('==================================================');
    return result;
  }
}
