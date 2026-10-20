import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Helper to launch URLs in the default system browser via MethodChannel
class UrlLauncherHelper {
  static const MethodChannel _channel = MethodChannel('com.logapp.studylog/share');

  static Future<void> openUrl(String rawUrl, {BuildContext? context}) async {
    var url = rawUrl.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (e) {
      debugPrint('Failed to open URL $url directly: $e');
      await Clipboard.setData(ClipboardData(text: url));
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied link: $url\nRestart the app once to enable direct browser launch.'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
