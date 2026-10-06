import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'google_auth_service.dart';

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

/// Service managing cloud backup and restore with Google Drive API v3.
///
/// Stores files in the user's private, hidden `appDataFolder` space.
/// Does NOT count against developer quotas or billing, and is invisible to
/// ordinary Google Drive browsing (preventing accidental user deletion).
class GoogleDriveService {
  final GoogleAuthService _authService;
  static const String backupFileName = 'study_log_backup.json';

  GoogleDriveService(this._authService);

  Future<drive.DriveApi> _getDriveApi() async {
    final GoogleSignInAccount? account =
        _authService.currentUser ?? await _authService.signInSilently();

    if (account == null) {
      throw StateError('User is not signed in with Google');
    }

    final authHeaders = await account.authHeaders;
    final authenticatedClient = _GoogleAuthClient(authHeaders);
    return drive.DriveApi(authenticatedClient);
  }

  /// Uploads or updates the current database payload in the Drive `appDataFolder`.
  Future<String> backupDatabase(Map<String, dynamic> payload) async {
    debugPrint('[GoogleDriveService] Starting backup to Google Drive...');
    final driveApi = await _getDriveApi();

    final jsonString = jsonEncode(payload);
    final bytes = utf8.encode(jsonString);

    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    final query =
        "name = '$backupFileName' and 'appDataFolder' in parents and trashed = false";

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: query,
      $fields: 'files(id, name, modifiedTime)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final existingId = fileList.files!.first.id!;
      debugPrint('[GoogleDriveService] Updating existing backup (ID: $existingId)...');

      final updated = await driveApi.files.update(
        drive.File(),
        existingId,
        uploadMedia: media,
      );
      return updated.id ?? existingId;
    } else {
      debugPrint('[GoogleDriveService] Creating new backup file in appDataFolder...');
      final fileMetadata = drive.File()
        ..name = backupFileName
        ..parents = ['appDataFolder']
        ..mimeType = 'application/json';

      final created = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
        $fields: 'id, name, modifiedTime',
      );
      return created.id!;
    }
  }

  /// Downloads and parses the backup JSON from the Drive `appDataFolder`.
  /// Returns null if no previous backup exists.
  Future<Map<String, dynamic>?> restoreDatabase() async {
    debugPrint('[GoogleDriveService] Searching for backup in Google Drive...');
    final driveApi = await _getDriveApi();

    final query =
        "name = '$backupFileName' and 'appDataFolder' in parents and trashed = false";

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: query,
      $fields: 'files(id, name, modifiedTime)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      debugPrint('[GoogleDriveService] No existing backup found in appDataFolder.');
      return null;
    }

    final fileId = fileList.files!.first.id!;
    debugPrint('[GoogleDriveService] Downloading backup (ID: $fileId)...');

    final response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (response is! drive.Media) {
      throw StateError('Expected Media stream from Drive file download');
    }

    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
    }

    final jsonString = utf8.decode(bytes);
    final decoded = jsonDecode(jsonString);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    } else if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  /// Fetches the last modified timestamp of the cloud backup file, if present.
  Future<DateTime?> getLastBackupTimestamp() async {
    try {
      final driveApi = await _getDriveApi();
      final query =
          "name = '$backupFileName' and 'appDataFolder' in parents and trashed = false";

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: query,
        $fields: 'files(id, name, modifiedTime)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.modifiedTime;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
