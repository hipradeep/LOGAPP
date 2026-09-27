import 'package:flutter/material.dart';
import '../../models/calendar_event.dart';
import '../../theme/app_theme.dart';
import '../../controllers/courses_controller.dart';
import '../../services/service_locator.dart';
import '../app_spacers.dart';

class CalendarFilterSheet extends StatefulWidget {
  final CalendarViewMode currentViewMode;
  final Set<int> currentLevels;
  final bool currentShowCompletions;
  final String? currentCourseId;
  final void Function({
    required CalendarViewMode viewMode,
    required Set<int> levels,
    required bool showCompletions,
    required String? courseId,
  }) onApply;

  const CalendarFilterSheet({
    super.key,
    required this.currentViewMode,
    required this.currentLevels,
    required this.currentShowCompletions,
    required this.currentCourseId,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required CalendarViewMode currentViewMode,
    required Set<int> currentLevels,
    required bool currentShowCompletions,
    required String? currentCourseId,
    required void Function({
      required CalendarViewMode viewMode,
      required Set<int> levels,
      required bool showCompletions,
      required String? courseId,
    }) onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CalendarFilterSheet(
        currentViewMode: currentViewMode,
        currentLevels: currentLevels,
        currentShowCompletions: currentShowCompletions,
        currentCourseId: currentCourseId,
        onApply: onApply,
      ),
    );
  }

  @override
  State<CalendarFilterSheet> createState() => _CalendarFilterSheetState();
}

class _CalendarFilterSheetState extends State<CalendarFilterSheet> {
  late CalendarViewMode _viewMode;
  late Set<int> _levels;
  late bool _showCompletions;
  late String? _courseId;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.currentViewMode;
    _levels = Set<int>.from(widget.currentLevels);
    _showCompletions = widget.currentShowCompletions;
    _courseId = widget.currentCourseId;
  }

  void _handleReset() {
    setState(() {
      _viewMode = CalendarViewMode.month;
      _levels = {1, 2, 3, 4, 5};
      _showCompletions = true;
      _courseId = null;
    });
  }

  void _handleApply() {
    widget.onApply(
      viewMode: _viewMode,
      levels: _levels,
      showCompletions: _showCompletions,
      courseId: _courseId,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final courses = getIt<CoursesController>().courses;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: View + Close
            Row(
              children: [
                Text(
                  'View',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppTheme.textSecondaryColor(context)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const VGapSm(),
            // Segmented View Mode Tabs: [ Month ] [ Week ] [ Agenda ]
            Row(
              children: CalendarViewMode.values.map((mode) {
                final isSelected = mode == _viewMode;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Material(
                      color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => setState(() => _viewMode = mode),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Text(
                            mode.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const VGapLg(),
            // Section: Show
            Text(
              'Show',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const VGapSm(),
            _CheckboxRow(
              label: 'Completions',
              color: const Color(0xFF10B981),
              value: _showCompletions,
              onChanged: (val) => setState(() => _showCompletions = val ?? true),
            ),
            _CheckboxRow(
              label: 'R1 (1 day)',
              color: const Color(0xFFEF4444),
              value: _levels.contains(1),
              onChanged: (val) => setState(() {
                if (val == true) {
                  _levels.add(1);
                } else {
                  _levels.remove(1);
                }
              }),
            ),
            _CheckboxRow(
              label: 'R2 (3 days)',
              color: const Color(0xFFF59E0B),
              value: _levels.contains(2),
              onChanged: (val) => setState(() {
                if (val == true) {
                  _levels.add(2);
                } else {
                  _levels.remove(2);
                }
              }),
            ),
            _CheckboxRow(
              label: 'R3 (7 days)',
              color: const Color(0xFF0284C7),
              value: _levels.contains(3),
              onChanged: (val) => setState(() {
                if (val == true) {
                  _levels.add(3);
                } else {
                  _levels.remove(3);
                }
              }),
            ),
            _CheckboxRow(
              label: 'R4 (14 days)',
              color: const Color(0xFF8B5CF6),
              value: _levels.contains(4),
              onChanged: (val) => setState(() {
                if (val == true) {
                  _levels.add(4);
                } else {
                  _levels.remove(4);
                }
              }),
            ),
            _CheckboxRow(
              label: 'R5 (30 days)',
              color: const Color(0xFF16A34A),
              value: _levels.contains(5),
              onChanged: (val) => setState(() {
                if (val == true) {
                  _levels.add(5);
                } else {
                  _levels.remove(5);
                }
              }),
            ),
            const VGapLg(),
            // Section: Filter by Course
            Text(
              'Filter by Course',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const VGapSm(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _courseId,
                  isExpanded: true,
                  hint: Text('All Courses', style: TextStyle(color: AppTheme.textPrimaryColor(context))),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondaryColor(context)),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Courses'),
                    ),
                    ...courses.map((course) {
                      return DropdownMenuItem<String?>(
                        value: course.id,
                        child: Text(course.title),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _courseId = val),
                ),
              ),
            ),
            const VGapXl(),
            // Buttons: Reset & Apply
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleReset,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ),
                ),
                const HGapMd(),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckboxRow extends StatelessWidget {
  final String label;
  final Color color;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _CheckboxRow({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const HGapSm(),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
