import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashReportingService {
  static const String _logFileName = 'local_crash_log.txt';

  /// Gets the reference to the local crash log file in the app documents directory
  static Future<File> get _logFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_logFileName');
  }

  /// Logs a crash exception and stack trace to the local file
  static Future<void> logCrash(Object error, StackTrace? stack) async {
    try {
      final file = await _logFile;
      final timestamp = DateTime.now().toLocal().toString();

      final buffer = StringBuffer();
      buffer.writeln('==================================================');
      buffer.writeln('CRASH REPORT - $timestamp');
      buffer.writeln('==================================================');
      buffer.writeln('Error Type: ${error.runtimeType}');
      buffer.writeln('Error Message: $error');
      buffer.writeln('\nStack Trace:');
      buffer.writeln(stack ?? 'No stack trace available');
      buffer.writeln('==================================================\n\n');

      // Append to the local file
      await file.writeAsString(buffer.toString(), mode: FileMode.append, flush: true);
      debugPrint("Crash logged locally to: ${file.path}");
    } catch (e) {
      debugPrint("Failed to write crash report to local file: $e");
    }
  }

  /// Reads the entire crash log file content
  static Future<String> readCrashLog() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        return await file.readAsString();
      }
      return 'No crash reports found.';
    } catch (e) {
      return 'Error reading crash log: $e';
    }
  }

  /// Clears the crash log file
  static Future<void> clearCrashLog() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Failed to clear crash log file: $e");
    }
  }
}
