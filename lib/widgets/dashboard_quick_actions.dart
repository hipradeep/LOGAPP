import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/cache_service.dart';
import 'app_spacers.dart';

class DashboardQuickActions extends StatefulWidget {
  final VoidCallback onFocus;
  final VoidCallback onLogFood;
  final VoidCallback onWater;
  final VoidCallback onNewJournal;

  const DashboardQuickActions({
    super.key,
    required this.onFocus,
    required this.onLogFood,
    required this.onWater,
    required this.onNewJournal,
  });

  @override
  State<DashboardQuickActions> createState() => _DashboardQuickActionsState();
}

class _DashboardQuickActionsState extends State<DashboardQuickActions> {
  final CacheService _cacheService = CacheService();
  List<String>? _enabledActions;
  StreamSubscription<List<String>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadActions();
    _subscription = _cacheService.quickActionsStream.listen((actions) {
      if (mounted) {
        setState(() {
          _enabledActions = actions;
        });
      }
    });
  }

  Future<void> _loadActions() async {
    final actions = await _cacheService.getQuickActions();
    if (mounted) {
      setState(() {
        _enabledActions = actions;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Widget _buildActionCard({
    required String title,
    required String emoji,
    required String subtitle,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.01),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: accentColor.withValues(alpha: 0.1),
            highlightColor: accentColor.withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.1),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const VGapMd(),
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _getActionCard(String action) {
    if (action == 'Focus 25m') {
      return _buildActionCard(
        title: 'Focus 25m',
        emoji: '🎯',
        subtitle: 'Start Pomodoro',
        accentColor: AppTheme.primaryColor,
        onTap: widget.onFocus,
      );
    } else if (action == 'Log Food') {
      return _buildActionCard(
        title: 'Log Food',
        emoji: '🍎',
        subtitle: 'Track calories',
        accentColor: AppTheme.successColor,
        onTap: widget.onLogFood,
      );
    } else if (action == 'Water 250ml') {
      return _buildActionCard(
        title: 'Water 250ml',
        emoji: '💧',
        subtitle: 'Log hydration',
        accentColor: AppTheme.secondaryColor,
        onTap: widget.onWater,
      );
    } else if (action == 'New Journal' || action == 'New note') {
      return _buildActionCard(
        title: 'New Journal',
        emoji: '📝',
        subtitle: 'Daily reflection',
        accentColor: AppTheme.primaryLight,
        onTap: widget.onNewJournal,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final enabledActions = _enabledActions;
    if (enabledActions == null || enabledActions.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Widget> cards = [];
    for (var action in enabledActions) {
      final card = _getActionCard(action);
      if (card != null) {
        cards.add(card);
      }
    }

    final List<Widget> rows = [];
    for (int i = 0; i < cards.length; i += 2) {
      if (i + 1 < cards.length) {
        rows.add(
          Row(
            children: [
              Expanded(child: cards[i]),
              const HGapSm(),
              Expanded(child: cards[i + 1]),
            ],
          ),
        );
      } else {
        rows.add(
          Row(
            children: [
              Expanded(child: cards[i]),
            ],
          ),
        );
      }
      if (i + 2 < cards.length) {
        rows.add(const VGapSm());
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions'.toUpperCase(),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.primaryLight,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const VGapSm(),
          ...rows,
        ],
      ),
    );
  }
}
