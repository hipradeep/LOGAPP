# Local Crash Reporting in Flutter

Yes, we can generate and save crash reports directly to a local file when the app runs locally (or is installed on a device).

This guide describes how to implement a local crash logging system in Flutter using standard APIs and `path_provider`.

---

## 1. Overview of the Solution

To capture all uncaught exceptions in Flutter:
1. **Flutter Framework Errors**: Handled via `FlutterError.onError`.
2. **Platform & Asynchronous Errors**: Handled via `PlatformDispatcher.instance.onError`.
3. **Local File Writing**: Using `path_provider` to access the safe app document directory (e.g., `getApplicationDocumentsDirectory()`) and writing/appending the crash details.
4. **Local Verification UI (Optional)**: A simple screen or bottom sheet to read, clear, and share the log file contents for easier debugging.

---

## 2. Implementation Steps

### A. The Crash Reporting Service
Create a dedicated service to manage reading, writing, and clearing crash logs.

**File:** `lib/services/crash_reporting_service.dart`

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashReportingService {
  static const String _logFileName = 'local_crash_log.txt';

  /// Gets the reference to the local crash log file
  static Future<File> get _logFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_logFileName');
  }

  /// Logs a crash exception and its stack trace to the local file
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

  /// Reads the entire crash log file
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
```

---

### B. Hooking up Error Handlers in `main()`
Integrate the logging callbacks in the app's `main()` function inside `lib/main.dart`.

**File:** `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/crash_reporting_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Capture Flutter framework errors (Layout errors, build errors, etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    // Forward to default console logging
    FlutterError.presentError(details);
    
    // Save locally
    CrashReportingService.logCrash(details.exception, details.stack);
  };

  // 2. Capture asynchronous or platform-dispatcher level errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    CrashReportingService.logCrash(error, stack);
    return true; // Returns true to notify that the error has been handled
  };

  // Rest of initialization code...
  runApp(const MyApp());
}
```

---

### C. Creating a Crash Log Viewer UI (Optional but Recommended)
A simple full-screen screen (adhering to `FullScreenPage` and the custom state rules) to view, refresh, and clear logs.

**File:** `lib/screens/crash_log_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../services/crash_reporting_service.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart'; // Or default screen structure

class CrashLogScreen extends StatefulWidget {
  const CrashLogScreen({super.key});

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  String _logContent = 'Loading crash reports...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final content = await CrashReportingService.readCrashLog();
    if (mounted) {
      setState(() {
        _logContent = content;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Crash Logs?'),
        content: const Text('This will permanently delete all saved crash logs on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CrashReportingService.clearCrashLog();
      await _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Crash Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                _logContent,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.0,
                ),
              ),
            ),
    );
  }
}
```

---

## 3. How to Test / Trigger a Crash

You can verify that crashes are correctly captured and written to the file by adding a temporary button that triggers an exception or asynchronous error:

```dart
// Synchronous UI Exception
ElevatedButton(
  onPressed: () {
    throw Exception("Test Synchronous Flutter Crash!");
  },
  child: const Text("Trigger Sync Crash"),
);

// Asynchronous Background Exception
ElevatedButton(
  onPressed: () {
    Future.delayed(const Duration(milliseconds: 100), () {
      throw Exception("Test Asynchronous App Crash!");
    });
  },
  child: const Text("Trigger Async Crash"),
);
```
