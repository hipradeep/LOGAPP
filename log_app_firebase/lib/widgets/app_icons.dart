import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Extra Small Icon (16.0 px)
/// 
/// Use for: Inline status indicators, small chips, or fine details.
class IconXs extends StatelessWidget {
  final IconData icon;
  final Color? color;

  /// Extra Small Icon (16.0 px)
  const IconXs(this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: AppTheme.iconSizeXs, color: color);
  }
}

/// Small Icon (20.0 px)
/// 
/// Use for: Alerts, secondary action buttons, or dense list items.
class IconSm extends StatelessWidget {
  final IconData icon;
  final Color? color;

  /// Small Icon (20.0 px)
  const IconSm(this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: AppTheme.iconSizeSm, color: color);
  }
}

/// Medium Icon (24.0 px)
/// 
/// Standard size. Use for: Main navigation, toolbar actions, and primary list icons.
class IconMd extends StatelessWidget {
  final IconData icon;
  final Color? color;

  /// Medium Icon (24.0 px)
  const IconMd(this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: AppTheme.iconSizeMd, color: color);
  }
}

/// Large Icon (32.0 px)
/// 
/// Use for: Major feature icons, large selection cards, or section headers.
class IconLg extends StatelessWidget {
  final IconData icon;
  final Color? color;

  /// Large Icon (32.0 px)
  const IconLg(this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: AppTheme.iconSizeLg, color: color);
  }
}

/// Extra Large Icon (48.0 px)
/// 
/// Use for: Empty state illustrations or prominent logo placements.
class IconXl extends StatelessWidget {
  final IconData icon;
  final Color? color;

  /// Extra Large Icon (48.0 px)
  const IconXl(this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: AppTheme.iconSizeXl, color: color);
  }
}

/// Double Extra Large Icon (64.0 px)
/// 
/// Use for: Main hero logos or splash screen branding.
class IconXxl extends StatelessWidget {
  final IconData icon;
  final Color? color;

  /// Double Extra Large Icon (64.0 px)
  const IconXxl(this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: AppTheme.iconSizeXxl, color: color);
  }
}
