import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../services/cache_service.dart';

class ManageQuickActionsScreen extends StatefulWidget {
  const ManageQuickActionsScreen({super.key});

  @override
  State<ManageQuickActionsScreen> createState() => _ManageQuickActionsScreenState();
}

class _ManageQuickActionsScreenState extends State<ManageQuickActionsScreen> {
  final CacheService _cacheService = CacheService();
  final List<String> _allActions = ['Focus 25m', 'Water 250ml', 'New note', 'Add transaction', 'Day planner'];
  List<String> _enabledActions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActions();
  }

  Future<void> _loadActions() async {
    final actions = await _cacheService.getQuickActions();
    if (mounted) {
      setState(() {
        _enabledActions = actions;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAction(String action, bool value) async {
    setState(() {
      if (value) {
        if (!_enabledActions.contains(action)) {
          _enabledActions.add(action);
        }
      } else {
        _enabledActions.remove(action);
      }
    });
    await _cacheService.saveQuickActions(_enabledActions);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // CRITICAL: Registers this component to rebuild on theme switch
    return FullScreenPage(
      showScaffold: true,
      isScrollable: true,
      title: 'Quick Actions',
      showBackButton: true,
      padding: EdgeInsets.zero,

      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure dashboard shortcuts'.toUpperCase(),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor(context),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const VGapSm(),
              Text(
                'Enable or disable shortcut actions appearing at the top of your dashboard screen.',
                style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const VGapLg(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _isLoading
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.borderColor(context),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: _allActions.map((action) {
                      final isEnabled = _enabledActions.contains(action);
                      final int index = _allActions.indexOf(action);
                      final String emoji;
                      final String description;
                      final Color accentColor;
                      if (action == 'Focus 25m') {
                        emoji = '🎯';
                        description = 'Focus session timer';
                        accentColor = AppTheme.primaryColor;
                      } else if (action == 'Water 250ml') {
                        emoji = '💧';
                        description = 'Hydration counter';
                        accentColor = AppTheme.secondaryColor;
                      } else if (action == 'Add transaction') {
                        emoji = '💵';
                        description = 'Log budget transaction';
                        accentColor = AppTheme.successColor;
                      } else if (action == 'Day planner') {
                        emoji = '📅';
                        description = 'Organize daily schedule';
                        accentColor = Colors.orange;
                      } else {
                        emoji = '📝';
                        description = 'note entry text log';
                        accentColor = AppTheme.primaryAccentColor(context);
                      }

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                                ),
                                const HGapMd(),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        action,
                                        style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const VGapXs(),
                                      Text(
                                        description,
                                        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondaryColor(context), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isEnabled,
                                  activeThumbColor: accentColor,
                                  activeTrackColor: accentColor.withValues(alpha: 0.4),
                                  inactiveThumbColor: AppTheme.switchInactiveThumbColor(context),
                                  inactiveTrackColor: AppTheme.switchInactiveTrackColor(context),
                                  onChanged: (val) {
                                    if (!val && _enabledActions.length <= 1) {
                                      ScaffoldMessenger.of(context).clearSnackBars();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('At least one quick action must be enabled.'),
                                          backgroundColor: AppTheme.warningColor,
                                        ),
                                      );
                                      return;
                                    }
                                    _toggleAction(action, val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (index < _allActions.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: AppTheme.borderColor(context),
                              indent: 16,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
        const VGapXxl(),
      ],
    );
  }
}
