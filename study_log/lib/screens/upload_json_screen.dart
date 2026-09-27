import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/course.dart';
import '../models/module.dart';
import '../services/local_course_storage.dart';
import '../services/local_module_storage.dart';
import '../services/local_topic_storage.dart';
import '../models/topic.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';

// Sample JSON shown on screen (copyable, not downloadable)
const String _kSampleJson = r'''
{
  "courses": [
    {
      "id": "course_001",
      "title": "Flutter Development",
      "description": "Complete Flutter & Dart course from basics to advanced.",
      "status": "active",
      "modules": [
        {
          "id": "module_001",
          "title": "Dart Basics",
          "description": "Variables, functions, OOP in Dart.",
          "orderIndex": 0,
          "status": "active",
          "topics": [
            {
              "id": "topic_001",
              "title": "Variables & Types",
              "description": "int, String, bool, dynamic.",
              "orderIndex": 0,
              "status": "notStarted"
            },
            {
              "id": "topic_002",
              "title": "Functions & Lambdas",
              "description": "Named, anonymous, arrow functions.",
              "orderIndex": 1,
              "status": "notStarted"
            }
          ]
        },
        {
          "id": "module_002",
          "title": "Flutter Widgets",
          "description": "Stateless vs Stateful, layout widgets.",
          "orderIndex": 1,
          "status": "active",
          "topics": [
            {
              "id": "topic_003",
              "title": "StatelessWidget",
              "description": "Immutable UI blocks.",
              "orderIndex": 0,
              "status": "notStarted"
            }
          ]
        }
      ]
    }
  ]
}
''';

// Screen

/// Upload JSON Screen: lets the user pick a JSON file from their device and
/// bulk-import Courses → Modules → Topics into local cache.
/// Also displays a copyable sample JSON so the user knows the expected format.
class UploadJsonScreen extends StatefulWidget {
  const UploadJsonScreen({super.key});

  @override
  State<UploadJsonScreen> createState() => _UploadJsonScreenState();
}

class _UploadJsonScreenState extends State<UploadJsonScreen> {
  bool _isImporting = false;
  String? _resultMessage;
  bool _isSuccess = false;

  Future<void> _copySampleJson() async {
    await Clipboard.setData(const ClipboardData(text: _kSampleJson));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sample JSON copied to clipboard!'),
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
      final data = jsonDecode(content) as Map<String, dynamic>;

      final stats = await _importData(data);

      setState(() {
        _isSuccess = true;
        _resultMessage =
            'Imported ${stats['courses']} course(s), '
            '${stats['modules']} module(s), '
            '${stats['topics']} topic(s) successfully.';
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

  Future<Map<String, int>> _importData(Map<String, dynamic> data) async {
    int courseCount = 0, moduleCount = 0, topicCount = 0;

    final now = DateTime.now();
    final coursesList = data['courses'] as List<dynamic>? ?? [];

    // Load existing local courses so we can merge / upsert
    final existingCourses = await LocalCourseStorage.loadCourses();
    final existingIds = existingCourses.map((c) => c.id).toSet();

    final newCourses = List<Course>.from(existingCourses);

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
        createdAt: now,
        updatedAt: now,
      );

      if (!existingIds.contains(courseId)) {
        newCourses.add(course);
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
            status: Topic.parseStatus(subMap['status']),
            // A completed topic must carry a completion date, otherwise the
            // activity feed silently skips it. Default to import time.
            completedAt: Topic.parseStatus(subMap['status']) ==
                    TopicStatus.completed
                ? (Topic.parseDateTime(subMap['completedAt']) ?? now)
                : null,
            iconCodePoint: (subMap['iconCodePoint'] as num?)?.toInt(),
            colorValue: (subMap['colorValue'] as num?)?.toInt(),
          );
          topicItems.add(subItem);
          topicCount++;
          ssIdx++;
        }

        if (topicItems.isNotEmpty) {
          await LocalTopicStorage.saveTopics(
              moduleId, topicItems);
        }

        sIdx++;
      }

      if (courseModules.isNotEmpty) {
        await LocalModuleStorage.saveModulesForCourse(
            courseId, courseModules);
      }
    }

    await LocalCourseStorage.saveCourses(newCourses);

    return {
      'courses': courseCount,
      'modules': moduleCount,
      'topics': topicCount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
              const _ModuleLabel(label: 'Sample JSON Format'),
              const VGapSm(),
              _SampleJsonCard(onCopy: _copySampleJson),
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

// Sub-components

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
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const HGapMd(),
        const Text(
          'Upload JSON',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
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
        color: const Color(0xFFF0EEFF),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: const Color(0xFFE2DCFF)),
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
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _SampleJsonCard extends StatefulWidget {
  final VoidCallback onCopy;

  const _SampleJsonCard({required this.onCopy});

  @override
  State<_SampleJsonCard> createState() => _SampleJsonCardState();
}

/// Collapsed by default so the card is just a bar with a Copy action; the caret
/// on the right reveals the raw JSON without needing a horizontal scroll.
class _SampleJsonCardState extends State<_SampleJsonCard> {
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
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2640),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.defaultBorderRadius),
                topRight: Radius.circular(AppTheme.defaultBorderRadius),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.data_object_rounded,
                    size: 16, color: Color(0xFF9CA3AF)),
                const HGapSm(),
                const Text(
                  'sample.json',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onCopy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              AppTheme.primaryColor.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded,
                            size: 13, color: Color(0xFFB4A5FF)),
                        HGapXs(),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB4A5FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const HGapXs(),
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF322D4A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3D3760)),
                    ),
                    child: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: const Color(0xFFD4D0FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  _kSampleJson.trim(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Color(0xFFD4D0FF),
                    height: 1.6,
                  ),
                ),
              ),
            ),
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
