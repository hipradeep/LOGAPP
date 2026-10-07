import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/course.dart';
import '../models/module.dart';
import '../models/topic.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'course_icon_chip.dart';
import 'sheet_action_widgets.dart';

/// Modal bottom sheet allowing users to share, copy, or save a clean JSON
/// export of a course structure containing:
/// - Course: title, description
/// - Modules: title, description
/// - Topics: title, description
class ShareCourseJsonSheet extends StatelessWidget {
  final Course course;
  final int moduleCount;
  final int topicCount;
  final String jsonString;

  const ShareCourseJsonSheet({
    super.key,
    required this.course,
    required this.moduleCount,
    required this.topicCount,
    required this.jsonString,
  });

  /// Builds the clean JSON map and JSON string for [course].
  /// Strictly includes: course title & description, module title & description, topic title & description.
  static Future<({String jsonStr, int moduleCount, int topicCount})> buildCleanJson(Course course) async {
    final modules = await DatabaseService.instance.getModules(courseId: course.id);
    final allTopics = await DatabaseService.instance.getTopicsForCourse(courseId: course.id);

    final topicsByModule = <String, List<Topic>>{};
    for (final topic in allTopics) {
      topicsByModule.putIfAbsent(topic.moduleId, () => []).add(topic);
    }

    // Build the clean JSON structure requested by user
    final cleanJson = {
      'title': course.title,
      'description': course.description,
      'modules': modules.map((m) {
        final topics = topicsByModule[m.id] ?? topicsByModule[m.title] ?? [];
        return {
          'title': m.title,
          'description': m.description,
          'topics': topics.map((t) => {
            'title': t.title,
            'description': t.description,
          }).toList(),
        };
      }).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(cleanJson);
    return (jsonStr: jsonStr, moduleCount: modules.length, topicCount: allTopics.length);
  }

  /// Directly shares the course clean JSON to other apps (WhatsApp, Gmail, Telegram, etc.)
  /// via Android system chooser. If platform share is unavailable (e.g. app requires full restart),
  /// copies to clipboard and opens the preview & export bottom sheet.
  /// Presents the Share Course JSON bottom sheet for [course].
  static Future<void> share(BuildContext context, {required Course course}) async {
    await show(context, course: course);
  }

  /// Dialog shown when Android native code in MainActivity.kt has not been compiled yet
  /// due to only running a Hot Restart instead of a full app stop and re-run.
  static void _showRebuildDialog(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          side: BorderSide(color: AppTheme.borderColor(ctx)),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 24),
            const HGapSm(),
            Expanded(
              child: Text(
                'Full App Restart Required',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(ctx),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Sharing directly to other apps (WhatsApp, Messages, Drive, etc.) relies on native Android code in MainActivity.kt.\n\n'
          'Hot Restart only reloads Dart files and cannot compile native Android code into the running app. Please STOP the app and run "flutter run" (or press Stop then Run) to compile the native share sheet.\n\n'
          'The clean JSON has been copied to your clipboard so you can paste it directly into WhatsApp or Messages right now!',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppTheme.textSecondaryColor(ctx),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Gathers course modules and topics from local storage, builds clean JSON,
  /// and presents the bottom sheet.
  static Future<void> show(BuildContext context, {required Course course}) async {
    try {
      final data = await buildCleanJson(course);

      if (!context.mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ShareCourseJsonSheet(
          course: course,
          moduleCount: data.moduleCount,
          topicCount: data.topicCount,
          jsonString: data.jsonStr,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load course: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            ),
          ),
        );
      }
    }
  }

  Future<void> _shareViaApps(BuildContext context) async {
    const channel = MethodChannel('com.logapp.studylog/share');
    bool shared = false;
    bool needsRebuild = false;
    try {
      final sanitizedTitle = course.title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${sanitizedTitle.isNotEmpty ? sanitizedTitle : "course"}.json';

      final tempDir = await getTemporaryDirectory();
      final shareDir = Directory('${tempDir.path}/shared_courses');
      if (!await shareDir.exists()) {
        await shareDir.create(recursive: true);
      }
      final file = File('${shareDir.path}/$fileName');
      await file.writeAsString(jsonString);

      final result = await channel.invokeMethod<bool>('shareFile', {
        'filePath': file.path,
        'title': '${course.title} (Course JSON)',
        'mimeType': 'application/json',
      });
      shared = result ?? true;
    } on MissingPluginException {
      needsRebuild = true;
    } catch (_) {
      shared = false;
    }

    if (!context.mounted) return;

    if (shared) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sharing "${course.title}.json" file...'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (needsRebuild) {
      await _copyToClipboard(context);
      if (context.mounted) {
        _showRebuildDialog(context);
      }
    } else {
      await _copyToClipboard(context);
    }
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: jsonString));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Clean JSON for "${course.title}" copied to clipboard!'),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAsJsonFile(BuildContext context) async {
    final sanitizedTitle = course.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    final fileName = '${sanitizedTitle.isNotEmpty ? sanitizedTitle : 'course'}.json';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Clean Course JSON',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(jsonString),
    );

    if (savePath != null && context.mounted) {
      final file = File(savePath);
      if (!await file.exists() || (await file.length()) == 0) {
        try {
          await file.writeAsString(jsonString);
        } catch (_) {}
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to $fileName successfully!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleText = '$moduleCount ${moduleCount == 1 ? "module" : "modules"} • $topicCount ${topicCount == 1 ? "topic" : "topics"}';

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapSm(),
        SheetHeader(
          badge: SheetHeaderBadge(
            child: CourseIconChip(
              courseId: course.id,
              iconCodePoint: course.iconCodePoint,
              colorValue: course.colorValue,
              size: 38,
              radius: 10,
            ),
          ),
          title: 'Share Course JSON',
          subtitle: subtitleText,
        ),
        const VGapMd(),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                isPrimary: true,
                onTap: () => _shareViaApps(context),
              ),
            ),
            const HGapSm(),
            Expanded(
              child: _ActionButton(
                icon: Icons.copy_rounded,
                label: 'Copy JSON',
                onTap: () => _copyToClipboard(context),
              ),
            ),
            const HGapSm(),
            Expanded(
              child: _ActionButton(
                icon: Icons.file_download_outlined,
                label: 'Save File',
                onTap: () => _saveAsJsonFile(context),
              ),
            ),
          ],
        ),
        const VGapMd(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CLEAN JSON PREVIEW',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMutedColor(context),
                letterSpacing: 0.8,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant(context),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${utf8.encode(jsonString).length} bytes',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ),
          ],
        ),
        const VGapXs(),
        Container(
          width: double.infinity,
          height: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: SelectableText(
              jsonString,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.4,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ),
        ),
        const VGapMd(),
        const SheetCancelButton(),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary
        ? AppTheme.primaryColor
        : AppTheme.surfaceVariant(context);
    final fgColor = isPrimary
        ? Colors.white
        : AppTheme.textPrimaryColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: isPrimary ? null : Border.all(color: AppTheme.borderColor(context)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fgColor),
              const HGapXs(),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
