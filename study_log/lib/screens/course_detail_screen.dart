import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/section.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/course_options_sheet.dart';
import '../controllers/sections_controller.dart';
import 'section_detail_screen.dart';
import 'add_section_screen.dart';

/// Redesigned Course Detail (Sections) screen matching the reference design:
/// - Top bar with back button, course title (e.g. "DSA"), "+ Add Section" button, and 3-dots options menu
/// - Top Progress banner: "6 / 20 sections", "30%", and full-width purple progress bar
/// - "Sections (20)" and "Overview" tabs
/// - Clean vertical list of syllabus sections with cycling pastel number badges
///   (Green, Cyan, Orange, Purple), titles, subsections count, and trailing chevrons
/// - Tapping "+ Add Section" opens the standalone AddSectionScreen
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
  late final SectionsController _sectionsController;
  final ValueNotifier<int> _activeTab = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _sectionsController = SectionsController(courseId: widget.course.id);
  }

  @override
  void dispose() {
    _sectionsController.dispose();
    _activeTab.dispose();
    super.dispose();
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  void _openSectionDetail(String sectionTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionDetailScreen(
          sectionTitle: sectionTitle,
          courseTitle: widget.course.title,
        ),
      ),
    );
  }

  void _openAddSectionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSectionScreen(
          courseId: widget.course.id,
          courseTitle: widget.course.title,
          sectionsController: _sectionsController,
        ),
      ),
    );
  }

  void _handleTabSelected(int index) {
    if (_activeTab.value == index) return;
    _activeTab.value = index;
  }

  void _openOptionsMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const VGapMd(),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor),
                  title: const Text('Add New Section', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _openAddSectionScreen();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppTheme.textPrimary),
                  title: const Text('Edit Course Details'),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    CourseOptionsSheet.show(context, course: widget.course);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _CourseDetailTopBar(
              title: widget.course.title,
              onBack: _handleBack,
              onAddSection: _openAddSectionScreen,
              onOptions: _openOptionsMenu,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: _CourseProgressHeader(
                completedSections: 6,
                totalSections: 20,
                progress: 0.30,
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _activeTab,
              builder: (context, activeIdx, _) {
                return _CourseTabsRow(
                  activeIndex: activeIdx,
                  sectionsCount: 20,
                  onTabSelected: _handleTabSelected,
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
                  return _CourseSectionsListView(
                    course: widget.course,
                    sectionsController: _sectionsController,
                    onSectionTap: _openSectionDetail,
                    onAddSection: _openAddSectionScreen,
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

// === Subcomponents (Rule 2 & 23: Pure, extracted StatelessWidget classes) ===

class _CourseDetailTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onAddSection;
  final VoidCallback onOptions;

  const _CourseDetailTopBar({
    required this.title,
    required this.onBack,
    required this.onAddSection,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.textPrimary,
              size: 28,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          const HGapXs(),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Material(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onAddSection,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    HGapXs(),
                    Text(
                      'Add Section',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const HGapSm(),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textPrimary,
              size: 24,
            ),
            onPressed: onOptions,
            tooltip: 'Options',
          ),
        ],
      ),
    );
  }
}

class _CourseTabsRow extends StatelessWidget {
  final int activeIndex;
  final int sectionsCount;
  final ValueChanged<int> onTabSelected;

  const _CourseTabsRow({
    required this.activeIndex,
    required this.sectionsCount,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFEEF0F5), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            _TabItem(
              label: 'Sections ($sectionsCount)',
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
            color: isActive ? AppTheme.primaryColor : const Color(0xFF6B7280),
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
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'About This Course',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const VGapSm(),
              Text(
                course.description.isNotEmpty
                    ? course.description
                    : 'Comprehensive syllabus and curriculum tracking for ${course.title}. Progress through sections and subsections to complete your study goals.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppTheme.textSecondary,
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
  final int completedSections;
  final int totalSections;
  final double progress;

  const _CourseProgressHeader({
    required this.completedSections,
    required this.totalSections,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$completedSections / $totalSections sections',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
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
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }
}

class _CourseSectionsListView extends StatelessWidget {
  final Course course;
  final SectionsController sectionsController;
  final ValueChanged<String> onSectionTap;
  final VoidCallback onAddSection;
  final double bottomPadding;

  const _CourseSectionsListView({
    required this.course,
    required this.sectionsController,
    required this.onSectionTap,
    required this.onAddSection,
    required this.bottomPadding,
  });

  static const List<_SectionPreset> _defaultPresets = [
    _SectionPreset(title: 'Arrays', subtitle: '3 / 8 subsections', badgeColor: Color(0xFF10B981)),
    _SectionPreset(title: 'Strings', subtitle: '0 / 7 subsections', badgeColor: Color(0xFF38BDF8)),
    _SectionPreset(title: 'Linked List', subtitle: '0 / 6 subsections', badgeColor: Color(0xFFFB923C)),
    _SectionPreset(title: 'Stack & Queue', subtitle: '1 / 7 subsections', badgeColor: Color(0xFF818CF8)),
    _SectionPreset(title: 'Trees', subtitle: '0 / 10 subsections', badgeColor: Color(0xFF34D399)),
    _SectionPreset(title: 'Graphs', subtitle: '0 / 8 subsections', badgeColor: Color(0xFFFB923C)),
    _SectionPreset(title: 'Dynamic Programming', subtitle: '0 / 5 subsections', badgeColor: Color(0xFFA78BFA)),
  ];

  static const List<Color> _badgeColorCycle = [
    Color(0xFF10B981),
    Color(0xFF38BDF8),
    Color(0xFFFB923C),
    Color(0xFF818CF8),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sectionsController,
      builder: (context, _) {
        final dynamicSections = sectionsController.sections;

        // If user has saved custom sections for this course, render them
        if (dynamicSections.isNotEmpty) {
          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
            itemCount: dynamicSections.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 72,
              endIndent: 20,
              color: Color(0xFFF3F4F6),
            ),
            itemBuilder: (context, index) {
              final Section section = dynamicSections[index];
              final color = _badgeColorCycle[index % _badgeColorCycle.length];
              return _SectionListItem(
                number: index + 1,
                title: section.title,
                subtitle: section.description.isNotEmpty
                    ? section.description
                    : '0 / 4 subsections',
                badgeColor: color,
                onTap: () => onSectionTap(section.title),
                onLongPress: () => sectionsController.deleteSection(section.id),
              );
            },
          );
        }

        // Default sections matching the reference screenshot
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
          itemCount: _defaultPresets.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            indent: 72,
            endIndent: 20,
            color: Color(0xFFF3F4F6),
          ),
          itemBuilder: (context, index) {
            final preset = _defaultPresets[index];
            return _SectionListItem(
              number: index + 1,
              title: preset.title,
              subtitle: preset.subtitle,
              badgeColor: preset.badgeColor,
              onTap: () => onSectionTap(preset.title),
            );
          },
        );
      },
    );
  }
}

class _SectionListItem extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final Color badgeColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _SectionListItem({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.badgeColor,
    this.onTap,
    this.onLongPress,
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
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const HGapMd(),
                // Title & Subsections Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Trailing Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionPreset {
  final String title;
  final String subtitle;
  final Color badgeColor;

  const _SectionPreset({
    required this.title,
    required this.subtitle,
    required this.badgeColor,
  });
}
