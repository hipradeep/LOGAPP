import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_provider.dart';
import 'app_spacers.dart';
import 'app_premium_fab.dart';

class BaseManagementTab<T extends ChangeNotifier> extends StatelessWidget {
  final T controller;
  final bool Function(T) isLoading;
  final String? Function(T) errorMessage;
  final bool Function(T) isEmpty;
  final IconData emptyIcon;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onFabPressed;
  final Widget Function(BuildContext context, T controller) builder;

  const BaseManagementTab({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.errorMessage,
    required this.isEmpty,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onFabPressed,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AppProvider<T>(
      notifier: controller,
      child: Builder(
        builder: (context) {
          // IMPORTANT: We use AppProvider.read to avoid rebuilding the entire stack,
          // including the FAB, on every controller change.
          final ctrl = AppProvider.read<T>(context);

          return Stack(
            children: [
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: ctrl,
                  builder: (context, child) {
                    return _buildBody(context, ctrl);
                  },
                ),
              ),
              AppPremiumFab(
                onPressed: onFabPressed,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, T ctrl) {
    if (isLoading(ctrl)) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final error = errorMessage(ctrl);
    if (error != null) {
      return Center(
        child: Text(
          'Failed to load data:\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.errorColor),
        ),
      );
    }

    if (isEmpty(ctrl)) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.surfaceColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(emptyIcon, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                      const VGapMd(),
                      Text(
                        emptyMessage,
                        style: AppTheme.headingSmall.copyWith(color: AppTheme.textSecondary),
                      ),
                      const VGapSm(),
                      const Text(
                        'Tap the + button to create your first entry.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      child: builder(context, ctrl),
    );
  }
}
