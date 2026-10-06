import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VGapXs extends StatelessWidget {
  const VGapXs({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingXs);
}

class VGapSm extends StatelessWidget {
  const VGapSm({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingSm);
}

class VGapMd extends StatelessWidget {
  const VGapMd({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingMd);
}

class VGapLg extends StatelessWidget {
  const VGapLg({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingLg);
}

class VGapXl extends StatelessWidget {
  const VGapXl({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: AppTheme.spacingXl);
}

class HGapXs extends StatelessWidget {
  const HGapXs({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: AppTheme.spacingXs);
}

class HGapSm extends StatelessWidget {
  const HGapSm({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: AppTheme.spacingSm);
}

class HGapMd extends StatelessWidget {
  const HGapMd({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: AppTheme.spacingMd);
}

class HGapLg extends StatelessWidget {
  const HGapLg({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: AppTheme.spacingLg);
}
