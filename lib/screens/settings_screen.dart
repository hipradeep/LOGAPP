import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_icons.dart';
import 'track_activities_screen.dart';
import 'manage_budget_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      title: 'Settings',
      isScrollable: true,
      backgroundWidgets: const [
        GlowBlob(
          top: -40,
          left: -40,
          size: 240,
          color: AppTheme.primaryColor,
          opacity: 0.1,
        ),
      ],
      children: [
        const VGapMd(),
        // Menu container card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Menu option: Track Activities
              _buildMenuItem(
                context,
                icon: Icons.check_circle_outline_rounded,
                title: 'Track Activities',
                subtitle: 'Manage and select active habits/tasks',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TrackActivitiesScreen(),
                    ),
                  );
                },
              ),
              _buildDivider(),
              _buildMenuItem(
                context,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Manage Budget',
                subtitle: 'Set salary, limits, and view expenses',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageBudgetScreen(),
                    ),
                  );
                },
              ),
              _buildDivider(),
              // Dummy menu item: Profile Settings (helps establish a premium settings feel)
              _buildMenuItem(
                context,
                icon: Icons.person_outline_rounded,
                title: 'Profile Settings',
                subtitle: 'Customize name and avatar settings',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile settings coming soon!')),
                  );
                },
              ),
              _buildDivider(),
              // Dummy menu item: About LOG
              _buildMenuItem(
                context,
                icon: Icons.info_outline_rounded,
                title: 'About LOG',
                subtitle: 'Version 1.0.0',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'LOG',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Text('🚀', style: TextStyle(fontSize: 32)),
                    children: const [
                      Text('A premium daily journal and activity tracker for Android.'),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: IconMd(icon, color: AppTheme.primaryLight),
            ),
            const HGapMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const IconSm(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.05),
      indent: 20,
      endIndent: 20,
    );
  }
}
