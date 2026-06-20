import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GridToggleButton extends StatelessWidget {
  final bool isGridView;
  final VoidCallback onTap;

  const GridToggleButton({
    super.key,
    required this.isGridView,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.transparent,
        child: Icon(
          isGridView ? Icons.view_agenda_outlined : Icons.grid_view_outlined,
          color: AppTheme.textSecondaryColor(context),
          size: 20,
        ),
      ),
    );
  }
}
