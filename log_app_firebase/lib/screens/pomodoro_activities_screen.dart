import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_toast.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../services/service_locator.dart';
import '../services/activity_service.dart';
import '../controllers/pomodoro_activities_controller.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_empty_state.dart';
import '../services/cache_service.dart';
import '../widgets/emoji_picker.dart';
import 'pomodoro_timer_screen.dart';
import 'pomodoro_ready_screen.dart';

class PomodoroActivitiesScreen extends StatefulWidget {
  const PomodoroActivitiesScreen({super.key});

  @override
  State<PomodoroActivitiesScreen> createState() => _PomodoroActivitiesScreenState();
}

class _PomodoroActivitiesScreenState extends State<PomodoroActivitiesScreen> {
  final CacheService _cacheService = CacheService();
  late final PomodoroActivitiesController _controller;
  bool _showAllPresets = false;
  List<Map<String, dynamic>> _customPresets = [];

  final Map<String, int> _presetDurations = {
    'meditation': 30,
    'calm': 30,
    'anger': 30,
    'deep work': 30,
  };

  List<Map<String, dynamic>> get _defaultPresets => [
    {'name': 'Meditation', 'symbol': '🧘', 'colorValue': Colors.teal.toARGB32(), 'key': 'meditation'},
    {'name': 'Calm', 'symbol': '🍃', 'colorValue': Colors.green.toARGB32(), 'key': 'calm'},
    {'name': 'Anger', 'symbol': '💢', 'colorValue': Colors.redAccent.toARGB32(), 'key': 'anger'},
    {'name': 'Deep Work', 'symbol': '💻', 'colorValue': AppTheme.primaryColor.toARGB32(), 'key': 'deep work'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = PomodoroActivitiesController();
    _loadPresetDurations();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPresetDurations() async {
    final list = await _cacheService.getCustomPresets();
    if (mounted) {
      setState(() {
        _customPresets = list;
      });
    }

    // Load default preset durations
    for (var preset in _defaultPresets) {
      final key = preset['key'] as String;
      final val = await _cacheService.getPresetDuration(key, 30);
      if (mounted) {
        setState(() {
          _presetDurations[key] = val;
        });
      }
    }

    // Load custom preset durations
    for (var preset in _customPresets) {
      final key = preset['key'] as String;
      final val = await _cacheService.getPresetDuration(key, preset['duration'] as int? ?? 30);
      if (mounted) {
        setState(() {
          _presetDurations[key] = val;
        });
      }
    }
  }

  void _startPomodoro(Activity activity, List<Activity> fullList, int currentIndex) async {
    final activeSession = await _cacheService.getActivePomodoroSession();
    if (!mounted) return;
    if (activeSession != null) {
      final endTimestamp = activeSession['endTimestamp'] as int? ?? 0;
      final isRunning = activeSession['isRunning'] as bool? ?? false;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final isPaused = !isRunning;
      final savedSeconds = activeSession['secondsRemaining'] as int? ?? 0;
      
      if ((isRunning && now < endTimestamp) || (isPaused && savedSeconds > 0)) {
        final activeActivityJson = activeSession['activity'] as Map<String, dynamic>;
        final activeActivity = Activity.fromJson(activeActivityJson);
        final remainingQueueJson = activeSession['remainingQueue'] as List<dynamic>? ?? [];
        final initialDurationMinutes = activeSession['initialDurationMinutes'] as int?;
        final remainingQueue = remainingQueueJson
            .map((a) => Activity.fromJson(Map<String, dynamic>.from(a as Map)))
            .toList();
            
        final secondsRemaining = isRunning 
            ? ((endTimestamp - now) / 1000).round()
            : savedSeconds;
            
        Task? milestoneTask;
        if (activeActivity.trackingType == 'milestone') {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );
          try {
            milestoneTask = await getIt<ActivityService>().getTaskById(activeActivity.id);
            if (!mounted) return;
          } finally {
            if (mounted) {
              Navigator.pop(context);
            }
          }
        }

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PomodoroTimerScreen(
              activity: activeActivity,
              remainingQueue: remainingQueue,
              initialDurationMinutes: initialDurationMinutes,
              initialSecondsRemaining: secondsRemaining,
              initialIsRunning: isRunning,
              initialMilestoneTask: milestoneTask,
            ),
          ),
        );
        return;
      }
    }

    final List<Activity> queue = fullList.isEmpty ? const <Activity>[] : fullList.sublist(currentIndex + 1);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PomodoroReadyScreen(
          activity: activity,
          remainingQueue: queue,
        ),
      ),
    );
  }



  void _editPresetDuration(String key, String displayName, {VoidCallback? onDelete}) async {
    final current = _presetDurations[key.toLowerCase()] ?? 30;
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _PresetDurationBottomSheet(
          name: displayName,
          initialDuration: current,
          onDelete: onDelete,
        ),
      ),
    );

    if (result != null) {
      await _cacheService.savePresetDuration(key, result);
      setState(() {
        _presetDurations[key.toLowerCase()] = result;
      });
      if (mounted) {
        AppToast.show(
          context: context,
          message: 'Saved $displayName duration as $result minutes.',
          backgroundColor: AppTheme.successColor,
        );
      }
    }
  }

  void _addNewPreset() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: const _CreatePresetBottomSheet(),
      ),
    );

    if (result != null) {
      final name = result['name'] as String;
      final symbol = result['symbol'] as String;
      final duration = result['duration'] as int;
      final key = name.toLowerCase();

      final colorsList = [
        Colors.blueAccent.toARGB32(),
        Colors.orangeAccent.toARGB32(),
        Colors.purpleAccent.toARGB32(),
        Colors.pinkAccent.toARGB32(),
        Colors.cyan.toARGB32(),
        Colors.amber.toARGB32(),
      ];
      final colorVal = colorsList[_customPresets.length % colorsList.length];

      final newPreset = {
        'name': name,
        'symbol': symbol,
        'colorValue': colorVal,
        'key': key,
        'duration': duration,
      };

      final updatedList = List<Map<String, dynamic>>.from(_customPresets);
      updatedList.removeWhere((item) => item['key'] == key);
      updatedList.add(newPreset);

      await _cacheService.saveCustomPresets(updatedList);
      await _cacheService.savePresetDuration(key, duration);

      setState(() {
        _customPresets = updatedList;
        _presetDurations[key] = duration;
      });

      if (mounted) {
        AppToast.show(
          context: context,
          message: 'Preset "$name" created successfully!',
          backgroundColor: AppTheme.successColor,
        );
      }
    }
  }

  void _removeCustomPreset(String key, String name) async {
    final updatedList = List<Map<String, dynamic>>.from(_customPresets)
      ..removeWhere((item) => item['key'] == key);

    await _cacheService.saveCustomPresets(updatedList);

    setState(() {
      _customPresets = updatedList;
      _presetDurations.remove(key);
    });

    if (mounted) {
      AppToast.show(
        context: context,
        message: 'Preset "$name" removed.',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuilds on theme switch
    return AppProvider<PomodoroActivitiesController>(
      notifier: _controller,
      child: Builder(
        builder: (context) {
          final controller = AppProvider.watch<PomodoroActivitiesController>(context);

          return FullScreenPage(
            showScaffold: true,
            isScrollable: true,
            title: 'Pomodoro Focus',
            showBackButton: true,
            padding: EdgeInsets.zero,
            children: [
              const VGapMd(),
              // Predefined Row Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'QUICK PRESETS',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryAccentColor(context),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showAllPresets = !_showAllPresets;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          _showAllPresets ? 'SHOW LESS' : 'SHOW MORE',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryAccentColor(context),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const VGapSm(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _PresetGrid(
                  defaultPresets: _defaultPresets,
                  customPresets: _customPresets,
                  presetDurations: _presetDurations,
                  showAllPresets: _showAllPresets,
                  onStartPredefined: _startPomodoro,
                  onEditPreset: _editPresetDuration,
                  onRemoveCustom: _removeCustomPreset,
                  onAddNew: _addNewPreset,
                ),
              ),
              const VGapLg(),
              // Activities List Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'YOUR ACTIVITIES',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const VGapSm(),
              controller.isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : controller.errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                          child: Text(
                            controller.errorMessage!,
                            style: const TextStyle(color: AppTheme.errorColor),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : controller.activities.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.timer_outlined,
                              title: 'Nothing Scheduled Today',
                              description: 'No active activities are scheduled for today. Add or enable activities in Track screen.',
                            )
                          : _ActivitiesList(
                              activities: controller.activities,
                              onPlay: _startPomodoro,
                            ),
            ],
          );
        }
      ),
    );
  }
}

class _PredefinedActivityCard extends StatelessWidget {
  final Activity activity;
  final Color color;
  final String presetKey;
  final void Function(Activity activity) onTap;
  final void Function(String key, String name, bool isCustom) onEdit;
  final bool isCustom;

  const _PredefinedActivityCard({
    required this.activity,
    required this.color,
    required this.presetKey,
    required this.onTap,
    required this.onEdit,
    required this.isCustom,
  });

  void _handleTap() {
    onTap(activity);
  }

  void _handleLongPress() {
    onEdit(presetKey, activity.name, isCustom);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            splashColor: color.withValues(alpha: 0.2),
            highlightColor: color.withValues(alpha: 0.08),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      activity.symbolValue ?? '🎯',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const VGapXs(),
                    Text(
                      activity.name,
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${activity.focusDuration} min',
                      style: AppTheme.bodyMicro.copyWith(
                        color: color.withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddNewPresetCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNewPresetCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            highlightColor: AppTheme.primaryColor.withValues(alpha: 0.05),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const VGapSm(),
                    Text(
                      'Add Preset',
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetDurationBottomSheet extends StatefulWidget {
  final String name;
  final int initialDuration;
  final VoidCallback? onDelete;

  const _PresetDurationBottomSheet({
    required this.name,
    required this.initialDuration,
    this.onDelete,
  });

  @override
  State<_PresetDurationBottomSheet> createState() => _PresetDurationBottomSheetState();
}

class _PresetDurationBottomSheetState extends State<_PresetDurationBottomSheet> {
  late double _duration;

  @override
  void initState() {
    super.initState();
    _duration = widget.initialDuration.toDouble();
  }

  void _handleTickTap(double val) {
    setState(() {
      _duration = val;
    });
  }

  void _handleSliderChanged(double val) {
    setState(() {
      _duration = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.borderColor(context), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const VGapMd(),
          Text(
            'Set ${widget.name} Duration',
            style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const VGapLg(),
          Text(
            '${_duration.round()} Minutes',
            style: AppTheme.headingLarge.copyWith(
              color: AppTheme.primaryAccentColor(context),
              fontSize: 36,
            ),
          ),
          const VGapMd(),
          Slider(
            value: _duration,
            min: 1,
            max: 120,
            divisions: 119,
            activeColor: AppTheme.primaryColor,
            inactiveColor: AppTheme.subtleFillColor(context),
            onChanged: _handleSliderChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RulerTick(label: '1m', value: 1, currentDuration: _duration, onTap: _handleTickTap),
                _RulerTick(label: '30m', value: 30, currentDuration: _duration, onTap: _handleTickTap),
                _RulerTick(label: '60m', value: 60, currentDuration: _duration, onTap: _handleTickTap),
                _RulerTick(label: '90m', value: 90, currentDuration: _duration, onTap: _handleTickTap),
                _RulerTick(label: '120m', value: 120, currentDuration: _duration, onTap: _handleTickTap),
              ],
            ),
          ),
          const VGapLg(),
          Row(
            children: [
              if (widget.onDelete != null) ...
              [
                SizedBox(
                  height: AppTheme.buttonHeight,
                  width: AppTheme.buttonHeight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: AppTheme.errorColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete!();
                    },
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                  ),
                ),
                const HGapSm(),
              ],
              Expanded(
                child: SizedBox(
                  height: AppTheme.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _duration.round());
                    },
                    child: const Text('Save'),
                  ),
                ),
              ),
            ],
          ),
          const VGapMd(),
        ],
      ),
    );
  }
}

class _CreatePresetBottomSheet extends StatefulWidget {
  const _CreatePresetBottomSheet();

  @override
  State<_CreatePresetBottomSheet> createState() => _CreatePresetBottomSheetState();
}

class _CreatePresetBottomSheetState extends State<_CreatePresetBottomSheet> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedSymbol = '🎯';
  double _duration = 30.0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final result = await EmojiPicker.showAsBottomSheet(
      context,
      currentEmoji: _selectedSymbol,
    );
    if (result != null) setState(() => _selectedSymbol = result);
  }

  void _handleTickTap(double val) {
    setState(() {
      _duration = val;
    });
  }

  void _handleSliderChanged(double val) {
    setState(() {
      _duration = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.borderColor(context), width: 1),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const VGapMd(),
          Center(
            child: Text(
              'Create Custom Preset',
              style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const VGapLg(),
          // ── Emoji + Name in one row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _pickEmoji,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emoji', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                    const VGapSm(),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.subtleFillColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.borderColor(context).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _selectedSymbol,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preset Name', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                    const VGapSm(),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Reading, Gaming',
                      ),
                      style: AppTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const VGapMd(),
          // ── Duration slider full width ──
          Text('Duration: ${_duration.round()} min', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
          const VGapSm(),
          Slider(
            value: _duration,
            min: 1,
            max: 120,
            divisions: 119,
            activeColor: AppTheme.primaryColor,
            inactiveColor: AppTheme.subtleFillColor(context),
            onChanged: _handleSliderChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RulerTick(label: '1m', value: 1, currentDuration: _duration, onTap: _handleTickTap),
                _RulerTick(label: '30m', value: 30, currentDuration: _duration, onTap: _handleTickTap),
                _RulerTick(label: '60m', value: 60, currentDuration: _duration, onTap: _handleTickTap),
                _RulerTick(label: '90m', value: 90, currentDuration: _duration, onTap: _handleTickTap),
                _RulerTick(label: '120m', value: 120, currentDuration: _duration, onTap: _handleTickTap),
              ],
            ),
          ),

          const VGapLg(),
          SizedBox(
            width: double.infinity,
            height: AppTheme.buttonHeight,
            child: ElevatedButton(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  AppToast.show(
                    context: context,
                    message: 'Please enter a preset name.',
                    backgroundColor: AppTheme.errorColor,
                  );
                  return;
                }
                Navigator.pop(context, {
                  'name': name,
                  'symbol': _selectedSymbol,
                  'duration': _duration.round(),
                });
              },
              child: const Text('Create Preset'),
            ),
          ),
          const VGapMd(),
        ],
        ),
      ),
    );
  }
}

class _ActivitiesList extends StatelessWidget {
  final List<Activity> activities;
  final void Function(Activity activity, List<Activity> fullList, int index) onPlay;

  const _ActivitiesList({
    required this.activities,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: 8,
        left: 24,
        right: 24,
        bottom: MediaQuery.paddingOf(context).bottom + 100,
      ),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        return _PomodoroActivityCard(
          activity: activities[index],
          activities: activities,
          index: index,
          onPlay: onPlay,
        );
      },
    );
  }
}

class _PomodoroActivityCard extends StatelessWidget {
  final Activity activity;
  final List<Activity> activities;
  final int index;
  final void Function(Activity activity, List<Activity> fullList, int index) onPlay;

  const _PomodoroActivityCard({
    required this.activity,
    required this.activities,
    required this.index,
    required this.onPlay,
  });

  void _handlePlay() {
    onPlay(activity, activities, index);
  }

  String _getTrackingTypeLabel(String trackingType) {
    switch (trackingType) {
      case 'multiple':
        return 'Routine';
      case 'milestone':
        return 'Milestone';
      case 'single':
      default:
        return 'Single';
    }
  }

  Color _getTrackingColor(String trackingType) {
    switch (trackingType) {
      case 'multiple':
        return AppTheme.secondaryColor;
      case 'milestone':
        return AppTheme.warningColor;
      case 'single':
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getTrackingColor(activity.trackingType);
    final trackingLabel = _getTrackingTypeLabel(activity.trackingType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: activity.isActive
            ? AppTheme.surface(context).withValues(alpha: 0.4)
            : AppTheme.surface(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: activity.isActive
              ? AppTheme.borderColor(context)
              : AppTheme.borderColor(context).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon / Symbol indicator
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  activity.symbolValue ?? '🎯',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const HGapMd(),
            // Title & Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.name,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: activity.isActive
                          ? AppTheme.textPrimaryColor(context)
                          : AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const VGapXs(),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          trackingLabel.toUpperCase(),
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (activity.trackingType == 'milestone' && activity.category != null && activity.category!.isNotEmpty) ...[
                        const HGapSm(),
                        Flexible(
                          child: Text(
                            activity.category!,
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (!activity.isActive) ...[
                        const HGapSm(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'INACTIVE',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const HGapMd(),
            // Play Button
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handlePlay,
                    splashColor: AppTheme.successColor.withValues(alpha: 0.25),
                    highlightColor: AppTheme.successColor.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppTheme.successColor,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetGrid extends StatelessWidget {
  final List<Map<String, dynamic>> defaultPresets;
  final List<Map<String, dynamic>> customPresets;
  final Map<String, int> presetDurations;
  final bool showAllPresets;
  final void Function(Activity activity, List<Activity> fullList, int currentIndex) onStartPredefined;
  final void Function(String key, String displayName, {VoidCallback? onDelete}) onEditPreset;
  final void Function(String key, String name) onRemoveCustom;
  final VoidCallback onAddNew;

  const _PresetGrid({
    required this.defaultPresets,
    required this.customPresets,
    required this.presetDurations,
    required this.showAllPresets,
    required this.onStartPredefined,
    required this.onEditPreset,
    required this.onRemoveCustom,
    required this.onAddNew,
  });

  void _handleTap(Activity activity) {
    onStartPredefined(activity, const [], 0);
  }

  void _handleEdit(String key, String name, bool isCustom) {
    if (isCustom) {
      onEditPreset(
        key,
        name,
        onDelete: () => onRemoveCustom(key, name),
      );
    } else {
      onEditPreset(key, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [];

    // Default presets
    for (final preset in defaultPresets) {
      final name = preset['name'] as String;
      final symbol = preset['symbol'] as String;
      final colorVal = preset['colorValue'] as int;
      final key = preset['key'] as String;
      final duration = presetDurations[key.toLowerCase()] ?? 30;

      final activity = Activity(
        id: 'predefined_${key.toLowerCase()}',
        name: name,
        isActive: true,
        timestamp: DateTime.now(),
        trackingType: 'single',
        symbolValue: symbol,
        focusDuration: duration,
      );

      cards.add(_PredefinedActivityCard(
        activity: activity,
        color: Color(colorVal),
        presetKey: key,
        onTap: _handleTap,
        onEdit: _handleEdit,
        isCustom: false,
      ));
    }

    // Custom presets
    for (final preset in customPresets) {
      final name = preset['name'] as String;
      final symbol = preset['symbol'] as String;
      final colorVal = preset['colorValue'] as int;
      final key = preset['key'] as String;
      final duration = presetDurations[key.toLowerCase()] ?? 30;

      final activity = Activity(
        id: 'predefined_${key.toLowerCase()}',
        name: name,
        isActive: true,
        timestamp: DateTime.now(),
        trackingType: 'single',
        symbolValue: symbol,
        focusDuration: duration,
      );

      cards.add(_PredefinedActivityCard(
        activity: activity,
        color: Color(colorVal),
        presetKey: key,
        onTap: _handleTap,
        onEdit: _handleEdit,
        isCustom: true,
      ));
    }

    cards.add(_AddNewPresetCard(onTap: onAddNew));

    final int limit = showAllPresets ? cards.length : 3;
    final List<Widget> gridRows = [];

    for (int i = 0; i < limit; i += 3) {
      final List<Widget> rowItems = [];
      for (int j = 0; j < 3; j++) {
        if (i + j < limit) {
          rowItems.add(Expanded(child: cards[i + j]));
        } else {
          rowItems.add(const Expanded(child: SizedBox.shrink()));
        }
        if (j < 2) {
          rowItems.add(const HGapSm());
        }
      }
      gridRows.add(Row(children: rowItems));
      if (i + 3 < limit) {
        gridRows.add(const VGapSm());
      }
    }

    return Column(
      children: gridRows,
    );
  }
}

class _RulerTick extends StatelessWidget {
  final String label;
  final int value;
  final double currentDuration;
  final ValueChanged<double> onTap;

  const _RulerTick({
    required this.label,
    required this.value,
    required this.currentDuration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentDuration.round() == value;
    return GestureDetector(
      onTap: () => onTap(value.toDouble()),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 2,
            height: 6,
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppTheme.primaryColor 
                  : AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const VGapXs(),
          Text(
            label,
            style: AppTheme.bodyMicro.copyWith(
              color: isSelected 
                  ? AppTheme.primaryColor 
                  : AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
