import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/course.dart';
import '../models/module.dart';
import '../services/local_course_storage.dart';
import '../services/local_module_storage.dart';
import '../models/topic.dart';
import '../models/study_log.dart';
import '../services/local_topic_storage.dart';
import '../services/local_study_log_storage.dart';
import '../services/service_locator.dart';
import '../services/firestore_service.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/revision_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';

/// Upload JSON Screen: lets the user pick a JSON file from their device and
/// bulk-import Courses or Modules → Topics into local cache.
class UploadJsonScreen extends StatefulWidget {
  final String? targetCourseId;
  final String? targetCourseTitle;

  const UploadJsonScreen({
    super.key,
    this.targetCourseId,
    this.targetCourseTitle,
  });

  @override
  State<UploadJsonScreen> createState() => _UploadJsonScreenState();
}

class _UploadJsonScreenState extends State<UploadJsonScreen> {
  bool _isImporting = false;
  String? _resultMessage;
  bool _isSuccess = false;

  String get _coursePrompt {
    final courseName = (widget.targetCourseTitle != null &&
            widget.targetCourseTitle!.trim().isNotEmpty)
        ? widget.targetCourseTitle!.trim()
        : '[COURSE_NAME]';

    return '{\n'
        '  "courseTitle": "$courseName",\n'
        '  "modules": [\n'
        '    {\n'
        '      "title": "Module Title",\n'
        '      "description": "Module description",\n'
        '      "topics": [\n'
        '        {\n'
        '          "title": "Topic Title",\n'
        '          "description": "Topic description"\n'
        '        }\n'
        '      ]\n'
        '    }\n'
        '  ]\n'
        '}\n\n'
        'Create a complete course structure in the above JSON format and provide a downloadable JSON file for $courseName';
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: _coursePrompt));
    if (!mounted) return;
    final courseName = (widget.targetCourseTitle != null &&
            widget.targetCourseTitle!.trim().isNotEmpty)
        ? widget.targetCourseTitle!.trim()
        : '[COURSE_NAME]';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Prompt for $courseName copied to clipboard!'),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  Future<void> _pickAndImport() async {
    setState(() {
      _isImporting = true;
      _resultMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

      final path = result.files.single.path;
      if (path == null) throw Exception('Could not read file path.');

      final content = await File(path).readAsString();
      final dynamic data = jsonDecode(content);

      final stats = await _importData(data);
      final bool fbSynced = stats['firebaseSynced'] == true;
      final String? fbError = stats['firebaseError'] as String?;

      setState(() {
        _isSuccess = true;
        final baseMsg =
            'Imported ${stats['courses']} course(s), '
            '${stats['modules']} module(s), '
            '${stats['topics']} topic(s) successfully.';
        if (fbSynced) {
          _resultMessage =
              '$baseMsg\n\n☁️ Synced to Firebase Firestore successfully.';
        } else if (fbError != null) {
          _resultMessage =
              '$baseMsg\n\n⚠️ Saved locally, but Firebase sync failed: $fbError';
        } else {
          _resultMessage = '$baseMsg\n\n💾 Saved to local database.';
        }
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _resultMessage = 'Import failed: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<Map<String, dynamic>> _importData(dynamic data) async {
    int courseCount = 0, moduleCount = 0, topicCount = 0;

    final now = DateTime.now();
    List<dynamic> coursesList = [];
    List<dynamic> standaloneModules = [];

    if (data is List) {
      standaloneModules = data;
    } else if (data is Map) {
      if (data['courses'] is List) {
        coursesList = data['courses'] as List<dynamic>;
      }
      if (data['modules'] is List) {
        standaloneModules = data['modules'] as List<dynamic>;
      } else if (data['sections'] is List) {
        standaloneModules = data['sections'] as List<dynamic>;
      }
    }

    // Load existing local courses so we can merge / upsert
    final existingCourses = await LocalCourseStorage.loadCourses();
    final existingIds = existingCourses.map((c) => c.id).toSet();

    final newCourses = List<Course>.from(existingCourses);
    final allImportedModules = <Module>[];
    final allImportedTopics = <Topic>[];

    // 1. Process courses if present
    for (final rawCourse in coursesList) {
      if (rawCourse is! Map) continue;
      final courseMap = Map<String, dynamic>.from(rawCourse);

      // Build Course entity (strip "modules" key — not part of Course model)
      final courseId = courseMap['id']?.toString() ??
          'course_${now.millisecondsSinceEpoch}_$courseCount';
      final course = Course(
        id: courseId,
        title: courseMap['title']?.toString() ?? 'Untitled Course',
        description: courseMap['description']?.toString() ?? '',
        status: courseMap['status']?.toString() ?? 'active',
        deadline: null,
        iconCodePoint: (courseMap['iconCodePoint'] as num?)?.toInt(),
        colorValue: (courseMap['colorValue'] as num?)?.toInt(),
        createdAt: now,
        updatedAt: now,
      );

      if (!existingIds.contains(courseId)) {
        newCourses.add(course);
        existingIds.add(courseId);
      }
      courseCount++;

      // "sections" is the pre-rename key; still accepted so older exports import.
      final rawModules = (courseMap['modules'] ?? courseMap['sections'])
              as List<dynamic>? ??
          [];
      final courseModules = <Module>[];

      int sIdx = 0;
      for (final rawModule in rawModules) {
        if (rawModule is! Map) continue;
        final moduleMap = Map<String, dynamic>.from(rawModule);

        final moduleId = moduleMap['id']?.toString() ??
            '${courseId}_module_$sIdx';
        final module = Module(
          id: moduleId,
          courseId: courseId,
          title: moduleMap['title']?.toString() ?? 'Untitled Module',
          description: moduleMap['description']?.toString() ?? '',
          orderIndex: (moduleMap['orderIndex'] as num?)?.toInt() ?? sIdx,
          status: moduleMap['status']?.toString() ?? 'active',
          createdAt: now,
          updatedAt: now,
        );
        courseModules.add(module);
        allImportedModules.add(module);
        moduleCount++;

        // "subsections" is the pre-rename key; still accepted.
        final rawTopics = (moduleMap['topics'] ?? moduleMap['subsections'])
                as List<dynamic>? ??
            [];
        final topicItems = <Topic>[];

        int ssIdx = 0;
        for (final rawSub in rawTopics) {
          if (rawSub is! Map) continue;
          final subMap = Map<String, dynamic>.from(rawSub);

          final subItem = Topic(
            id: subMap['id']?.toString() ?? '${moduleId}_topic_$ssIdx',
            courseId: courseId,
            moduleId: moduleId,
            title: subMap['title']?.toString() ?? 'Untitled Topic',
            description: subMap['description']?.toString() ?? '',
            orderIndex: (subMap['orderIndex'] as num?)?.toInt() ?? ssIdx,
            status: Topic.parseStatus(subMap['status']?.toString() ?? 'notStarted'),
            completedAt: Topic.parseStatus(subMap['status']?.toString() ?? 'notStarted') ==
                    TopicStatus.completed
                ? (Topic.parseDateTime(subMap['completedAt']) ?? now)
                : null,
            iconCodePoint: (subMap['iconCodePoint'] as num?)?.toInt(),
            colorValue: (subMap['colorValue'] as num?)?.toInt(),
          );
          topicItems.add(subItem);
          allImportedTopics.add(subItem);
          topicCount++;
          ssIdx++;
        }

        if (topicItems.isNotEmpty) {
          await LocalTopicStorage.saveTopics(moduleId, topicItems);
          if (module.title.isNotEmpty) {
            await LocalTopicStorage.saveTopics(module.title, topicItems);
          }
        }

        sIdx++;
      }

      if (courseModules.isNotEmpty) {
        await LocalModuleStorage.saveModulesForCourse(
            courseId, courseModules);
      }
    }

    // 2. Process standalone modules if present
    if (standaloneModules.isNotEmpty) {
      String courseId = widget.targetCourseId ?? '';
      String courseTitle = widget.targetCourseTitle ?? '';

      if (data is Map) {
        if (courseId.isEmpty && data['courseId'] != null) {
          courseId = data['courseId'].toString();
        }
        if (courseTitle.isEmpty) {
          final rawTitle =
              data['courseTitle'] ?? data['courseName'] ?? data['title'];
          if (rawTitle != null && rawTitle.toString().trim().isNotEmpty) {
            courseTitle = rawTitle.toString().trim();
          }
        }
      }

      if (courseId.isEmpty) {
        final matchingCourse = courseTitle.isNotEmpty
            ? existingCourses
                .where((c) =>
                    c.title.trim().toLowerCase() ==
                    courseTitle.trim().toLowerCase())
                .firstOrNull
            : null;

        if (matchingCourse != null) {
          courseId = matchingCourse.id;
          courseTitle = matchingCourse.title;
        } else if (courseTitle.isNotEmpty && courseTitle != '[COURSE_NAME]') {
          courseId = 'course_${now.millisecondsSinceEpoch}';
          final newCourse = Course(
            id: courseId,
            title: courseTitle,
            description: '',
            status: 'active',
            createdAt: now,
            updatedAt: now,
          );
          newCourses.add(newCourse);
          existingIds.add(courseId);
          courseCount++;
        } else if (existingCourses.isNotEmpty) {
          courseId = existingCourses.first.id;
          courseTitle = existingCourses.first.title;
        } else {
          courseId = 'course_${now.millisecondsSinceEpoch}';
          courseTitle = 'Imported Course';
          final newCourse = Course(
            id: courseId,
            title: courseTitle,
            description: '',
            status: 'active',
            createdAt: now,
            updatedAt: now,
          );
          newCourses.add(newCourse);
          existingIds.add(courseId);
          courseCount++;
        }
      } else if (!existingIds.contains(courseId)) {
        final newCourse = Course(
          id: courseId,
          title: courseTitle.isNotEmpty ? courseTitle : 'Imported Course',
          description: '',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        );
        newCourses.add(newCourse);
        existingIds.add(courseId);
        courseCount++;
      }

      final existingModules = await LocalModuleStorage.loadModules(courseId);
      final existingModuleIds = existingModules.map((m) => m.id).toSet();
      final courseModules = List<Module>.from(existingModules);

      int sIdx = existingModules.length;
      for (final rawModule in standaloneModules) {
        if (rawModule is! Map) continue;
        final moduleMap = Map<String, dynamic>.from(rawModule);

        final moduleId = moduleMap['id']?.toString() ?? '${courseId}_module_$sIdx';
        final module = Module(
          id: moduleId,
          courseId: courseId,
          title: moduleMap['title']?.toString() ?? 'Untitled Module',
          description: moduleMap['description']?.toString() ?? '',
          orderIndex: (moduleMap['orderIndex'] as num?)?.toInt() ?? sIdx,
          status: moduleMap['status']?.toString() ?? 'active',
          createdAt: now,
          updatedAt: now,
        );

        if (!existingModuleIds.contains(moduleId)) {
          courseModules.add(module);
          existingModuleIds.add(moduleId);
        }
        allImportedModules.add(module);
        moduleCount++;

        final rawTopics = (moduleMap['topics'] ?? moduleMap['subsections'])
                as List<dynamic>? ??
            [];
        final topicItems = <Topic>[];

        int ssIdx = 0;
        for (final rawSub in rawTopics) {
          if (rawSub is! Map) continue;
          final subMap = Map<String, dynamic>.from(rawSub);

          final subItem = Topic(
            id: subMap['id']?.toString() ?? '${moduleId}_topic_$ssIdx',
            courseId: courseId,
            moduleId: moduleId,
            title: subMap['title']?.toString() ?? 'Untitled Topic',
            description: subMap['description']?.toString() ?? '',
            orderIndex: (subMap['orderIndex'] as num?)?.toInt() ?? ssIdx,
            status: Topic.parseStatus(subMap['status']?.toString() ?? 'notStarted'),
            completedAt: Topic.parseStatus(subMap['status']?.toString() ?? 'notStarted') ==
                    TopicStatus.completed
                ? (Topic.parseDateTime(subMap['completedAt']) ?? now)
                : null,
            iconCodePoint: (subMap['iconCodePoint'] as num?)?.toInt(),
            colorValue: (subMap['colorValue'] as num?)?.toInt(),
          );
          topicItems.add(subItem);
          allImportedTopics.add(subItem);
          topicCount++;
          ssIdx++;
        }

        if (topicItems.isNotEmpty) {
          await LocalTopicStorage.saveTopics(moduleId, topicItems);
          if (module.title.isNotEmpty) {
            await LocalTopicStorage.saveTopics(module.title, topicItems);
          }
        }

        sIdx++;
      }

      if (courseModules.isNotEmpty) {
        await LocalModuleStorage.saveModulesForCourse(courseId, courseModules);
      }
    }

    await LocalCourseStorage.saveCourses(newCourses);

    // Create StudyLog entries for all completed topics in the import
    final List<StudyLog> importedStudyLogs = [];
    for (final t in allImportedTopics) {
      if (t.isCompleted) {
        final completedTime = t.completedAt ?? now;
        importedStudyLogs.add(StudyLog(
          id: '${t.id}_${completedTime.millisecondsSinceEpoch}',
          type: StudyLogType.topicCompleted,
          courseId: t.courseId,
          courseTitle: '',
          moduleId: t.moduleId,
          moduleTitle: '',
          topicId: t.id,
          topicTitle: t.title,
          timestamp: completedTime,
          createdAt: completedTime,
        ));
      }
    }

    if (importedStudyLogs.isNotEmpty) {
      final currentLogs = await LocalStudyLogStorage.loadAll();
      final currentIds = currentLogs.map((e) => e.id).toSet();
      final newLogs = importedStudyLogs.where((l) => !currentIds.contains(l.id)).toList();
      if (newLogs.isNotEmpty) {
        await LocalStudyLogStorage.saveAll([...currentLogs, ...newLogs]);
      }
    }

    // Sync imported course tree and study logs to Firestore atomically via high-speed batch commit
    bool firestoreSynced = false;
    String? firestoreError;

    if (getIt.isRegistered<FirestoreService>()) {
      final firestore = getIt<FirestoreService>();
      if (firestore.isAvailable) {
        try {
          await firestore.batchSave(
            courses: newCourses,
            modules: allImportedModules,
            topics: allImportedTopics,
            studyLogs: importedStudyLogs.isNotEmpty ? importedStudyLogs : null,
          );
          firestoreSynced = true;
        } catch (e) {
          firestoreError = e.toString();
          debugPrint('Error syncing imported data to Firestore: $e');
        }
      } else {
        firestoreError = 'Firestore offline / not initialized on this platform';
      }
    } else {
      firestoreError = 'FirestoreService not registered';
    }

    if (getIt.isRegistered<CoursesController>()) {
      await getIt<CoursesController>().loadCourses();
    }
    if (getIt.isRegistered<OngoingModulesController>()) {
      await getIt<OngoingModulesController>().refresh();
    }
    if (getIt.isRegistered<RevisionController>()) {
      await getIt<RevisionController>().reconcile();
    }

    return {
      'courses': courseCount,
      'modules': moduleCount,
      'topics': topicCount,
      'firebaseSynced': firestoreSynced,
      'firebaseError': firestoreError,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _UploadHeader(),
              const VGapLg(),
              const _InfoCard(),
              const VGapLg(),
              const _ModuleLabel(label: 'AI Course Prompt'),
              const VGapSm(),
              _AiPromptCard(
                promptText: _coursePrompt,
                onCopy: _copyPrompt,
              ),
              const VGapLg(),
              const _ModuleLabel(label: 'Import from File'),
              const VGapSm(),
              _ImportButton(
                isImporting: _isImporting,
                onTap: _pickAndImport,
              ),
              if (_resultMessage != null) ...[
                const VGapMd(),
                _ResultBanner(
                  message: _resultMessage!,
                  isSuccess: _isSuccess,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadHeader extends StatelessWidget {
  const _UploadHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
        const HGapMd(),
        Text(
          'Upload JSON',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pastelPurple(context),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.pastelPurpleBorder(context)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppTheme.primaryColor, size: 20),
          HGapSm(),
          Expanded(
            child: Text(
              'Upload a JSON file containing your courses, modules, and topics. '
              'Existing courses with the same ID will not be duplicated.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleLabel extends StatelessWidget {
  final String label;

  const _ModuleLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondaryColor(context),
        letterSpacing: 0.4,
      ),
    );
  }
}

class _AiPromptCard extends StatefulWidget {
  final String promptText;
  final VoidCallback onCopy;

  const _AiPromptCard({
    required this.promptText,
    required this.onCopy,
  });

  @override
  State<_AiPromptCard> createState() => _AiPromptCardState();
}

class _AiPromptCardState extends State<_AiPromptCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: const Color(0xFF2E2A44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2640),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTheme.defaultBorderRadius),
                  topRight: const Radius.circular(AppTheme.defaultBorderRadius),
                  bottomLeft: Radius.circular(
                      _isExpanded ? 0 : AppTheme.defaultBorderRadius),
                  bottomRight: Radius.circular(
                      _isExpanded ? 0 : AppTheme.defaultBorderRadius),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Color(0xFFB4A5FF),
                  ),
                  const HGapSm(),
                  const Expanded(
                    child: Text(
                      'Prompt for AI',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB4A5FF),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onCopy,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 12, color: Color(0xFFB4A5FF)),
                          HGapXs(),
                          Text(
                            'Copy Prompt',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB4A5FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const HGapXs(),
                  Tooltip(
                    message: _isExpanded ? 'Hide prompt' : 'Show prompt',
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF322D4A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3D3760)),
                      ),
                      child: AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: Color(0xFFD4D0FF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: SelectableText(
                widget.promptText,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Color(0xFFD4D0FF),
                  height: 1.5,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _isExpanded = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF25213B),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppTheme.defaultBorderRadius),
                    bottomRight: Radius.circular(AppTheme.defaultBorderRadius),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 16,
                      color: Color(0xFFB4A5FF),
                    ),
                    HGapXs(),
                    Text(
                      'Hide Prompt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB4A5FF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  final bool isImporting;
  final VoidCallback onTap;

  const _ImportButton({required this.isImporting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppTheme.buttonHeight,
      child: ElevatedButton.icon(
        onPressed: isImporting ? null : onTap,
        icon: isImporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_file_rounded, size: 20),
        label: Text(isImporting ? 'Importing…' : 'Choose JSON File'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const _ResultBanner({required this.message, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? AppTheme.successColor : AppTheme.errorColor;
    final bgColor =
        isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final icon =
        isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const HGapSm(),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
