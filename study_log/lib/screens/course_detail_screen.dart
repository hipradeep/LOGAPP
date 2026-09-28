import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../widgets/module_options_sheet.dart';
import '../controllers/modules_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../services/service_locator.dart';
import 'module_detail_screen.dart';
import 'add_module_screen.dart';

/// Redesigned Course Detail (Modules) screen matching the reference design:
/// - Top bar with back button, course title (e.g. "DSA"), and "+ Add Module" button
/// - Top Progress banner: "6 / 20 modules", "30%", and full-width purple progress bar
/// - "Modules (20)" and "Overview" tabs
/// - Clean vertical list of syllabus modules with cycling pastel number badges
///   (Green, Cyan, Orange, Purple), titles, topics count, and trailing chevrons
/// - Tapping "+ Add Module" opens the standalone AddModuleScreen
class CourseDetailScreen extends StatefulWidget {
  final Course course;

  const CourseDetailScreen({
    super.key,
    required this.course,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late final ModulesController _modulesController;
  final ValueNotifier<int> _activeTab = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _modulesController = ModulesController(courseId: widget.course.id);
  }

  @override
  void dispose() {
    _modulesController.dispose();
    _activeTab.dispose();
    super.dispose();
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  void _openModuleDetail(Module module, int orderIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleDetailScreen(
          moduleTitle: module.title,
          courseTitle: widget.course.title,
          courseId: widget.course.id,
          moduleId: module.id,
          moduleOrderIndex: orderIndex,
        ),
      ),
    );
  }

  void _openAddModuleScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddModuleScreen(
          courseId: widget.course.id,
          courseTitle: widget.course.title,
          modulesController: _modulesController,
        ),
      ),
    );
  }

  void _handleTabSelected(int index) {
    if (_activeTab.value == index) return;
    _activeTab.value = index;
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _CourseDetailTopBar(
              title: widget.course.title,
              onBack: _handleBack,
              onAddModule: _openAddModuleScreen,
            ),
            ListenableBuilder(
              listenable: Listenable.merge([
                _modulesController,
                if (getIt.isRegistered<OngoingModulesController>())
                  getIt<OngoingModulesController>(),
              ]),
              builder: (context, _) {
                final modules = _modulesController.modules;
                final ongoing = getIt.isRegistered<OngoingModulesController>()
                    ? getIt<OngoingModulesController>()
                    : null;
                // Derive module completion from real topic state rather than the
                // Module's stored `status` string alone.
                var completedCount = 0;
                for (final s in modules) {
                  final complete = (ongoing != null && ongoing.isModuleComplete(s.id)) ||
                      s.status.toLowerCase() == 'completed';
                  if (complete) completedCount++;
                }
                final totalCount = modules.length;
                final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.pastelPurple(context),
                              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                              border: Border.all(color: AppTheme.pastelPurpleBorder(context)),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.school_rounded,
                              color: AppTheme.pastelPurpleText(context),
                              size: 22,
                            ),
                          ),
                          const HGapSm(),
                          Expanded(
                            child: Text(
                              widget.course.title,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimaryColor(context),
                                letterSpacing: -0.5,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VGapXs(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: _CourseProgressHeader(
                        completedModules: completedCount,
                        totalModules: totalCount,
                        progress: progress,
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _activeTab,
                      builder: (context, activeIdx, _) {
                        return _CourseTabsRow(
                          activeIndex: activeIdx,
                          modulesCount: totalCount,
                          onTabSelected: _handleTabSelected,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            const VGapSm(),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _activeTab,
                builder: (context, activeIdx, _) {
                  if (activeIdx == 1) {
                    return _CourseOverviewView(
                      course: widget.course,
                      bottomPadding: bottomSafe + 24,
                    );
                  }
                  return _CourseModulesListView(
                    course: widget.course,
                    modulesController: _modulesController,
                    onModuleTap: _openModuleDetail,
                    onAddModule: _openAddModuleScreen,
                    bottomPadding: bottomSafe + 24,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseDetailTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onAddModule;

  const _CourseDetailTopBar({
    required this.title,
    required this.onBack,
    required this.onAddModule,
  });

  static const String _eyebrow = 'Course';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 16.0, 8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.textPrimaryColor(context),
              size: 28,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          const HGapXs(),
          Expanded(
            child: Text(
              _eyebrow.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryColor(context),
                letterSpacing: 1.0,
              ),
            ),
          ),
          AddPillButton(
            label: 'Add Module',
            onPressed: onAddModule,
          ),
        ],
      ),
    );
  }
}

class _CourseTabsRow extends StatelessWidget {
  final int activeIndex;
  final int modulesCount;
  final ValueChanged<int> onTabSelected;

  const _CourseTabsRow({
    required this.activeIndex,
    required this.modulesCount,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: Container(
        decoration:  BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            _TabItem(
              label: 'Modules ($modulesCount)',
              isActive: activeIndex == 0,
              onTap: () => onTabSelected(0),
            ),
            const HGapLg(),
            _TabItem(
              label: 'Overview',
              isActive: activeIndex == 1,
              onTap: () => onTabSelected(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          border: isActive
              ? const Border(
                  bottom: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2.5,
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}

class _CourseOverviewView extends StatelessWidget {
  final Course course;
  final double bottomPadding;

  const _CourseOverviewView({
    required this.course,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bottomPadding),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About This Course',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const VGapSm(),
              Text(
                course.description.isNotEmpty
                    ? course.description
                    : 'Comprehensive syllabus and curriculum tracking for ${course.title}. Progress through modules and topics to complete your study goals.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseProgressHeader extends StatelessWidget {
  final int completedModules;
  final int totalModules;
  final double progress;

  const _CourseProgressHeader({
    required this.completedModules,
    required this.totalModules,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = totalModules > 0 && completedModules >= totalModules;
    final percent = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$completedModules / $totalModules modules',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isComplete
                    ? AppTheme.successColor
                    : AppTheme.textSecondaryColor(context),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isComplete
                    ? AppTheme.successColor
                    : AppTheme.textPrimaryColor(context),
              ),
            ),
          ],
        ),
        const VGapSm(),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: const Color(0xFFECEEF6),
            valueColor: AlwaysStoppedAnimation<Color>(
              isComplete ? AppTheme.successColor : AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseModulesListView extends StatelessWidget {
  final Course course;
  final ModulesController modulesController;
  final void Function(Module, int) onModuleTap;
  final VoidCallback onAddModule;
  final double bottomPadding;

  const _CourseModulesListView({
    required this.course,
    required this.modulesController,
    required this.onModuleTap,
    required this.onAddModule,
    required this.bottomPadding,
  });

  static const List<Color> _badgeColorCycle = [
    AppTheme.successColor,
    Color(0xFF38BDF8),
    Color(0xFFFB923C),
    Color(0xFF818CF8),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        modulesController,
        if (getIt.isRegistered<OngoingModulesController>())
          getIt<OngoingModulesController>(),
      ]),
      builder: (context, _) {
        final dynamicModules = modulesController.modules;
        final ongoing = getIt.isRegistered<OngoingModulesController>()
            ? getIt<OngoingModulesController>()
            : null;

        if (dynamicModules.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.layers_clear_outlined,
                    size: 48,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                  const VGapMd(),
                  Text(
                    'No modules yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    'Tap "+ Add Module" to add topics to this course.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                  const VGapMd(),
                  ElevatedButton.icon(
                    onPressed: onAddModule,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Module'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
          itemCount: dynamicModules.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            indent: 72,
            endIndent: 20,
            color: Color(0xFFF3F4F6),
          ),
          itemBuilder: (context, index) {
            final Module module = dynamicModules[index];
            final color = _badgeColorCycle[index % _badgeColorCycle.length];
            final topicCount = ongoing?.topicCountForModule(module.id) ?? 0;
            final completedTopics =
                ongoing?.completedTopicCountForModule(module.id) ?? 0;
            final isComplete = (ongoing != null && ongoing.isModuleComplete(module.id)) ||
                (topicCount > 0 && completedTopics >= topicCount) ||
                module.status.toLowerCase() == 'completed';
            final topicInfo = topicCount > 0
                ? '$completedTopics / $topicCount topics'
                : 'No topics yet';
            final subtitle = module.description.isNotEmpty
                ? '${module.description} • $topicInfo'
                : topicInfo;
            return _ModuleListItem(
              number: index + 1,
              title: module.title,
              subtitle: subtitle,
              isComplete: isComplete,
              badgeColor: isComplete ? AppTheme.successColor : color,
              onTap: () => onModuleTap(module, index),
              onLongPress: () => ModuleOptionsSheet.show(
                context,
                module: module,
                courseTitle: course.title,
                courseId: course.id,
                modulesController: modulesController,
                isCompleted: isComplete,
              ),
              onOptionsTap: () => ModuleOptionsSheet.show(
                context,
                module: module,
                courseTitle: course.title,
                courseId: course.id,
                modulesController: modulesController,
                isCompleted: isComplete,
              ),
            );
          },
        );
      },
    );
  }
}

class _ModuleListItem extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final Color badgeColor;
  final bool isComplete;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionsTap;

  const _ModuleListItem({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.badgeColor,
    this.isComplete = false,
    this.onTap,
    this.onLongPress,
    this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                // Circular numbered badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isComplete
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : Text(
                          '$number',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
                const HGapMd(),
                // Title & Topics Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isComplete
                              ? AppTheme.textSecondaryColor(context)
                              : AppTheme.textPrimaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Row(
                        children: [
                          if (isComplete) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:  AppTheme.successColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'COMPLETED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.successColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const HGapXs(),
                          ],
                          Expanded(
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Trailing Chevron
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOptionsTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMutedColor(context),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
