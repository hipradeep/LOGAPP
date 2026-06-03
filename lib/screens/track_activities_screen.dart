import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_icons.dart';
import '../widgets/add_activity_sheet.dart';
import '../models/activity.dart';
import '../services/firebase_service.dart';

class TrackActivitiesScreen extends StatefulWidget {
  const TrackActivitiesScreen({Key? key}) : super(key: key);

  @override
  State<TrackActivitiesScreen> createState() => _TrackActivitiesScreenState();
}

class _TrackActivitiesScreenState extends State<TrackActivitiesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _useMockData = false;
  List<Activity> get _mockActivities => FirebaseService.mockActivities;

  @override
  void initState() {
    super.initState();
    // If Firebase isn't configured, default to offline simulator mode automatically
    _useMockData = Firebase.apps.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      showScaffold: true,
      isScrollable: true,
      title: 'Track Activities',
      showBackButton: true,
      padding: EdgeInsets.zero, // We want full-width grid padding custom-handled
      actions: [
        GestureDetector(
          onTap: _showAddActivityBottomSheet,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ],
      backgroundWidgets: const [
        GlowBlob(
          top: -40,
          left: -40,
          size: 240,
          color: AppTheme.primaryColor,
          opacity: 0.1,
        ),
        GlowBlob(
          bottom: -50,
          right: -50,
          size: 280,
          color: AppTheme.secondaryColor,
          opacity: 0.05,
        ),
      ],
      children: [
        // Subheader indicating mode
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Select activities to show on homepage'.toUpperCase(),
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const HGapSm(),
              GestureDetector(
                onTap: () {
                  // Only allow toggling if Firebase is actually configured
                  if (Firebase.apps.isNotEmpty) {
                    setState(() {
                      _useMockData = !_useMockData;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_useMockData 
                            ? 'Switched to local offline simulator mode.' 
                            : 'Switched to Firebase live stream mode.'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Firebase is not initialized. Locked in offline simulator mode.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _useMockData 
                        ? AppTheme.warningColor.withOpacity(0.15) 
                        : AppTheme.successColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _useMockData 
                          ? AppTheme.warningColor.withOpacity(0.4) 
                          : AppTheme.successColor.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _useMockData ? AppTheme.warningColor : AppTheme.successColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const HGapSm(),
                      Text(
                        _useMockData ? 'OFFLINE' : 'LIVE',
                        style: TextStyle(
                          color: _useMockData ? AppTheme.warningColor : AppTheme.successColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const VGapMd(),
        
        // 2-Column Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _useMockData ? _buildLocalGrid() : _buildFirestoreGrid(),
        ),
      ],
    );
  }

  // FIRESTORE GRID STREAM
  Widget _buildFirestoreGrid() {
    return StreamBuilder<List<Activity>>(
      stream: _firebaseService.getActivitiesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_useMockData) {
              setState(() {
                _useMockData = true;
              });
            }
          });
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        final activities = snapshot.data ?? [];
        if (activities.isEmpty) {
          return _buildEmptyState();
        }

        return _buildGrid(activities, isLive: true);
      },
    );
  }

  // LOCAL OFFLINE GRID
  Widget _buildLocalGrid() {
    if (_mockActivities.isEmpty) {
      return _buildEmptyState();
    }
    return _buildGrid(_mockActivities, isLive: false);
  }

  // THE GRID BUILDERS WITH SEPARATED SECTIONS
  Widget _buildGrid(List<Activity> activities, {required bool isLive}) {
    final active = activities.where((a) => a.checked).toList();
    final completed = activities.where((a) => !a.checked).toList();

    // Sort active by timestamp ascending (creation order)
    active.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    // Sort completed by timestamp descending (newest completed first)
    completed.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (active.isEmpty && completed.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isNotEmpty) ...[
          _buildSectionHeader('Active Activities (${active.length})'),
          const VGapSm(),
          _buildActivityGrid(active, isLive),
          const VGapLg(),
        ],
        if (completed.isNotEmpty) ...[
          _buildSectionHeader('Completed Activities (${completed.length})'),
          const VGapSm(),
          _buildActivityGrid(completed, isLive),
          const VGapLg(),
        ],
        const VGapXxl(),
        const VGapXxl(),
        const VGapXxl(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.primaryLight,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildActivityGrid(List<Activity> activities, bool isLive) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.1, // Adjusted ratio to fit text and subtitle
      ),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityCard(activity, isLive);
      },
    );
  }

  // CARD LAYOUT FOR SINGLE ACTIVITY WITH CUSTOM CHECKBOX
  Widget _buildActivityCard(Activity activity, bool isLive) {
    return GestureDetector(
      onTap: () => _showActivityOptions(activity, isLive),
      onLongPress: () => _showActivityOptions(activity, isLive),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: activity.checked
              ? AppTheme.primaryColor.withOpacity(0.12)
              : AppTheme.successColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          border: Border.all(
            color: activity.checked
                ? AppTheme.primaryColor.withOpacity(0.6)
                : AppTheme.successColor.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: activity.checked
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Circular Custom Checkbox (both active/completed show checked icon with respective theme color)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activity.checked ? AppTheme.primaryColor : AppTheme.successColor,
                border: Border.all(
                  color: activity.checked ? AppTheme.primaryColor : AppTheme.successColor,
                  width: 2,
                ),
              ),
              child: const Icon(Icons.check, size: 14, color: Colors.white),
            ),
            const HGapSm(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.name,
                    style: AppTheme.bodyMedium.copyWith(
                      color: activity.checked ? Colors.white : AppTheme.textSecondary,
                      fontWeight: activity.checked ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (activity.checked) ...[
                    const VGapXs(),
                    Text(
                      'Added: ${DateFormat('MMM d').format(activity.timestamp)}',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.55),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    const VGapXs(),
                    Text(
                      'Completed: ${DateFormat('MMM d').format(activity.timestamp)}',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.55),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // EMPTY CHECKLIST WIDGET
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_add,
            size: 64,
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
          const VGapMd(),
          Text(
            'No Activities Tracked',
            style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const VGapSm(),
          Text(
            'Tap the (+) button to create an activity checklist item.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ADD NEW ACTIVITY BOTTOM SHEET
  void _showAddActivityBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddActivitySheet(
        onAdd: (name, trackingType, targetCount) {
          _addActivity(name, trackingType, targetCount, _useMockData);
        },
      ),
    );
  }

  // SHOW LONG-PRESS ACTIVITY OPTIONS MENU
  void _showActivityOptions(Activity activity, bool isLive) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        ),
        title: Text(activity.name, style: AppTheme.headingSmall),
        content: const Text('Choose an action for this activity:'),
        actions: [
          // Edit option
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditActivityBottomSheet(activity, isLive);
            },
            child: const Text('Edit', style: TextStyle(color: AppTheme.primaryLight)),
          ),
          // Toggle Track/Check state option
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleActivity(activity, isLive);
            },
            child: Text(
              activity.checked ? 'Completed' : 'Check / Show on Home',
              style: TextStyle(
                color: activity.checked ? AppTheme.successColor : Colors.white70,
                fontWeight: activity.checked ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // Delete option
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteActivity(activity, isLive);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
          // Cancel
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  // EDIT ACTIVITY BOTTOM SHEET
  void _showEditActivityBottomSheet(Activity activity, bool isLive) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddActivitySheet(
        onAdd: (_, __, ___) {}, // Unused when editing
        initialActivity: activity,
        onEdit: (name, trackingType, targetCount) {
          _editActivity(activity.id, name, trackingType, targetCount, isLive);
        },
      ),
    );
  }

  // OPERATIONS
  void _addActivity(String name, String trackingType, int targetCount, bool isMock) async {
    if (isMock) {
      setState(() {
        _mockActivities.add(
          Activity(
            id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            checked: false,
            timestamp: DateTime.now(),
            trackingType: trackingType,
            targetCount: targetCount,
          ),
        );
      });
      FirebaseService.notifyActivitiesChanged();
    } else {
      try {
        await _firebaseService.createActivity(name, trackingType: trackingType, targetCount: targetCount);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add activity: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _editActivity(String id, String name, String trackingType, int targetCount, bool isLive) async {
    if (!isLive) {
      setState(() {
        final idx = _mockActivities.indexWhere((item) => item.id == id);
        if (idx != -1) {
          _mockActivities[idx] = _mockActivities[idx].copyWith(
            name: name,
            trackingType: trackingType,
            targetCount: targetCount,
          );
        }
      });
      FirebaseService.notifyActivitiesChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity updated locally.')),
      );
    } else {
      try {
        await _firebaseService.updateActivity(id, name, trackingType, targetCount);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity updated in Firestore.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update activity: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _toggleActivity(Activity activity, bool isLive) async {
    final newChecked = !activity.checked;
    if (!isLive) {
      setState(() {
        final idx = _mockActivities.indexWhere((item) => item.id == activity.id);
        if (idx != -1) {
          _mockActivities[idx] = _mockActivities[idx].copyWith(
            checked: newChecked,
            timestamp: DateTime.now(),
          );
        }
      });
      FirebaseService.notifyActivitiesChanged();
    } else {
      try {
        await _firebaseService.toggleActivity(activity.id, newChecked);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update activity: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _confirmDeleteActivity(Activity activity, bool isLive) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Delete "${activity.name}"?', style: AppTheme.headingSmall),
        content: const Text('Are you sure you want to delete this activity? All associated daily progress will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTheme.bodyMedium),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!isLive) {
        setState(() {
          _mockActivities.removeWhere((item) => item.id == activity.id);
        });
        FirebaseService.notifyActivitiesChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity deleted locally.')),
        );
      } else {
        try {
          await _firebaseService.deleteActivity(activity.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activity deleted from Firestore.')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete activity: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }
}
