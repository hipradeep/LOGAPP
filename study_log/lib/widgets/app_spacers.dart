import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// --- Vertical Spacers ---

/// Vertical Gap: Extra Small (4.0 px)
class VGapXs extends StatelessWidget {
  const VGapXs({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingXs);
}

/// Vertical Gap: Small (8.0 px)
class VGapSm extends StatelessWidget {
  const VGapSm({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingSm);
}

/// Vertical Gap: Medium (16.0 px)
class VGapMd extends StatelessWidget {
  const VGapMd({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingMd);
}

/// Vertical Gap: Large (24.0 px)
class VGapLg extends StatelessWidget {
  const VGapLg({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingLg);
}

/// Vertical Gap: Extra Large (32.0 px)
class VGapXl extends StatelessWidget {
  const VGapXl({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingXl);
}

/// Vertical Gap: Double Extra Large (48.0 px)
class VGapXxl extends StatelessWidget {
  const VGapXxl({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingXxl);
}

// --- Horizontal Spacers ---

/// Horizontal Gap: Extra Small (4.0 px)
class HGapXs extends StatelessWidget {
  const HGapXs({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: AppTheme.spacingXs);
}

/// Horizontal Gap: Small (8.0 px)
class HGapSm extends StatelessWidget {
  const HGapSm({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: AppTheme.spacingSm);
}

/// Horizontal Gap: Medium (16.0 px)
class HGapMd extends StatelessWidget {
  const HGapMd({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: AppTheme.spacingMd);
}

/// Horizontal Gap: Large (24.0 px)
class HGapLg extends StatelessWidget {
  const HGapLg({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: AppTheme.spacingLg);
}

/// Horizontal Gap: Extra Large (32.0 px)
class HGapXl extends StatelessWidget {
  const HGapXl({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: AppTheme.spacingXl);
}

/// Horizontal Gap: Double Extra Large (48.0 px)
class HGapXxl extends StatelessWidget {
  const HGapXxl({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: AppTheme.spacingXxl);
}
