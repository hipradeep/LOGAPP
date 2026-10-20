import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standard list tile divider across settings and list views.
class TileDivider extends StatelessWidget {
  final double indent;
  final double endIndent;

  const TileDivider({
    super.key,
    this.indent = 48,
    this.endIndent = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: indent,
      endIndent: endIndent,
      color: AppTheme.borderColor(context),
    );
  }
}
