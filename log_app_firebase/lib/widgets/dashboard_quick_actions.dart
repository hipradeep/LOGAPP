import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/cache_service.dart';
import 'app_spacers.dart';

class DashboardQuickActions extends StatefulWidget {
  final VoidCallback onFocus;
  final VoidCallback onWater;
  final VoidCallback onNewJournal;
  final VoidCallback onAddTransaction;

  const DashboardQuickActions({
    super.key,
    required this.onFocus,
    required this.onWater,
    required this.onNewJournal,
    required this.onAddTransaction,
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

  Widget _buildActionButton({
    required BuildContext context,
    required String title,
    required String emoji,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.22),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: accentColor.withValues(alpha: 0.18),
                highlightColor: accentColor.withValues(alpha: 0.08),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
        ),
        const VGapSm(),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget? _getActionBtn(BuildContext context, String action) {
    if (action == 'Focus 25m') {
      return _buildActionButton(
        context: context,
        title: 'Focus 25m',
        emoji: '🎯',
        label: 'Focus',
        accentColor: AppTheme.primaryColor,
        onTap: widget.onFocus,
      );

    } else if (action == 'Water 250ml') {
      return _buildActionButton(
        context: context,
        title: 'Water 250ml',
        emoji: '💧',
        label: 'Water',
        accentColor: AppTheme.secondaryColor,
        onTap: widget.onWater,
      );
    } else if (action == 'New Journal' || action == 'New note') {
      return _buildActionButton(
        context: context,
        title: 'New Journal',
        emoji: '📝',
        label: 'Journal',
        accentColor: AppTheme.primaryAccentColor(context),
        onTap: widget.onNewJournal,
      );
    } else if (action == 'Add transaction') {
      return _buildActionButton(
        context: context,
        title: 'Add transaction',
        emoji: '💵',
        label: 'Expense',
        accentColor: AppTheme.successColor,
        onTap: widget.onAddTransaction,
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

    final List<Widget> actionButtons = [];
    for (var action in enabledActions) {
      final btn = _getActionBtn(context, action);
      if (btn != null) {
        actionButtons.add(btn);
      }
    }

    final List<Widget> rows = [];
    for (int i = 0; i < actionButtons.length; i += 4) {
      final List<Widget> rowItems = [];
      for (int j = 0; j < 4; j++) {
        if (i + j < actionButtons.length) {
          rowItems.add(Expanded(child: actionButtons[i + j]));
        } else {
          rowItems.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: rowItems,
      ));
      if (i + 4 < actionButtons.length) {
        rows.add(const VGapMd());
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions'.toUpperCase(),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.primaryAccentColor(context),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const VGapMd(),
          ...rows,
        ],
      ),
    );
  }
}
