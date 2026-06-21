import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_provider.dart';
import '../widgets/edit_profile_sheet.dart';
import '../controllers/settings_controller.dart';
import '../controllers/theme_controller.dart';
import 'dashboard_screen.dart';
import 'milestones_screen.dart';
import 'budget_screen.dart';
import 'notes_screen.dart';
import 'manage_notification_screen.dart';
import 'manage_budget_screen.dart';
import 'manage_quick_actions_screen.dart';
import 'track_activities_screen.dart';
import 'log_screen.dart';
import 'crash_log_screen.dart';
import 'water_log_screen.dart';
import 'theme_selection_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final SettingsController _settingsController;

  final List<Widget> _screens = [
    DashboardScreen(),
    const MilestonesScreen(),
    const BudgetScreen(),
    const NotesScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_filled,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.flag_outlined,
      activeIcon: Icons.flag,
      label: 'Milestones',
    ),
    _NavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      label: 'Budget',
    ),
    _NavItem(
      icon: Icons.book_outlined,
      activeIcon: Icons.book,
      label: 'Notes',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _settingsController = SettingsController();
  }

  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppProvider<SettingsController>(
      notifier: _settingsController,
      child: AnimatedBuilder(
        animation: _settingsController,
        builder: (context, child) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            extendBody: true,
            drawer: _buildProfileDrawer(context),
            body: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            bottomNavigationBar: _buildBottomNavigationBar(context),
          );
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 68 + bottomPadding,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: bottomPadding,
              top: 8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surface(context).withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                  color: AppTheme.borderColor(context),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor(context),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_navItems.length, (index) {
                final isActive = _currentIndex == index;
                final item = _navItems[index];
                return _buildNavItem(
                  item: item,
                  isActive: isActive,
                  onTap: () => _onTabSelected(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildNavItem({
    required _NavItem item,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              item.label,
              style: TextStyle(
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDrawer(BuildContext context) {
    final controller = _settingsController;
    final themeController = AppProvider.watch<ThemeController>(context);

    return Drawer(
      width: 320,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.resolvedBackgroundGradient(context),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
          border: Border(
            right: BorderSide(
              color: AppTheme.borderColor(context),
              width: 1.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Profile',
                  style: AppTheme.headingSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              _buildDrawerProfileCard(context, controller),
              const VGapMd(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDrawerSectionTitle(context, 'Account'),
                      _buildDrawerSectionCard(
                        context,
                        children: [
                          _buildDrawerItem(
                            context,
                            icon: Icons.person_outline_rounded,
                            title: 'Manage Profile',
                            onTap: () {
                              Navigator.pop(context);
                              _showEditProfileSheet(context, controller);
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.notifications_none_rounded,
                            title: 'Notifications',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ManageNotificationScreen(controller: controller),
                                ),
                              );
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.language_rounded,
                            title: 'Language',
                            trailingText: 'English',
                            onTap: () {
                              _showComingSoonSnackBar(context, 'Language');
                            },
                          ),
                        ],
                      ),
                      const VGapMd(),
                      _buildDrawerSectionTitle(context, 'Preferences'),
                      _buildDrawerSectionCard(
                        context,
                        children: [
                          _buildDrawerItem(
                            context,
                            icon: Icons.palette_outlined,
                            title: 'Theme',
                            trailingText: _getThemeTypeName(themeController.themeType),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ThemeSelectionScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.local_drink_rounded,
                            title: 'Water Log',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const WaterLogScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.check_circle_outline_rounded,
                            title: 'Track Activities',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TrackActivitiesScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Manage Budget',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ManageBudgetScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.bolt_rounded,
                            title: 'Quick Actions',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ManageQuickActionsScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.history_rounded,
                            title: 'Log & Reports',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LogScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const VGapMd(),
                      _buildDrawerSectionTitle(context, 'Support & Data'),
                      _buildDrawerSectionCard(
                        context,
                        children: [
                          _buildDrawerItem(
                            context,
                            icon: Icons.cloud_sync_outlined,
                            title: 'Cloud Backup',
                            isSoon: true,
                            onTap: () {
                              _showProUpgradeDialog(context);
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.delete_outline_rounded,
                            title: 'Clear Cache & Reset',
                            onTap: () {
                              _resetCache(context, controller);
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.bug_report_outlined,
                            title: 'Local Crash Logs',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CrashLogScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.info_outline_rounded,
                            title: 'About LOG',
                            onTap: () {
                              showAboutDialog(
                                context: context,
                                applicationName: 'LOG',
                                applicationVersion: '1.1.0',
                                applicationIcon: const Text('🚀', style: TextStyle(fontSize: 32)),
                                children: const [
                                  Text('A premium daily note and activity tracker for Android.'),
                                ],
                              );
                            },
                          ),
                          _buildDrawerDivider(context),
                          _buildDrawerItem(
                            context,
                            icon: Icons.star_outline_rounded,
                            title: 'Review LOG App',
                            onTap: () {
                              _showReviewSnackBar(context);
                            },
                          ),
                        ],
                      ),
                      const VGapLg(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerProfileCard(BuildContext context, SettingsController controller) {
    final generatedEmail = '${controller.userName.toLowerCase().replaceAll(' ', '')}@gmail.com';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.background(context),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                controller.userAvatar,
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const HGapMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.userName,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const VGapXs(),
                Text(
                  generatedEmail,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppTheme.primaryAccentColor(context),
            onPressed: () => _showEditProfileSheet(context, controller),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, SettingsController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileSheet(
        initialName: controller.userName,
        initialAvatar: controller.userAvatar,
        onSave: controller.updateProfile,
      ),
    );
  }

  String _getThemeTypeName(AppThemeType type) {
    switch (type) {
      case AppThemeType.light:
        return 'Light';
      case AppThemeType.dark:
        return 'Classic Dark';
      case AppThemeType.orix:
        return 'Orix Theme';
      case AppThemeType.logo:
        return 'Teal Logo';
      case AppThemeType.earth:
        return 'Forest Earth';
      case AppThemeType.system:
        return 'System';
    }
  }

  Future<void> _resetCache(BuildContext context, SettingsController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reset Profile Settings',
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to reset your profile details and toggle settings? This won\'t delete your activities or logs.',
          style: TextStyle(
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.resetCache();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings cache cleared successfully.')),
      );
    }
  }

  void _showProUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text(
              'LOG Pro Beta',
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'LOG Pro will unlock features like custom color themes, biometric app locks, automated cloud backups, and export options.\n\nAll premium features will be unlocked for early beta testers in the next build! Thank you for testing LOG.',
          style: TextStyle(
            color: AppTheme.textSecondaryColor(context),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got It',
              style: TextStyle(
                color: AppTheme.primaryAccentColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonSnackBar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature option is coming soon in LOG Pro!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _showReviewSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for testing LOG! Custom review link coming soon.'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Widget _buildDrawerSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildDrawerSectionCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? trailingText,
    bool isSoon = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.9),
              size: 20,
            ),
            const HGapMd(),
            Expanded(
              child: Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  fontSize: 13,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const HGapSm(),
            ],
            if (isSoon) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Soon',
                  style: TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const HGapSm(),
            ],
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
              size: 11,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerDivider(BuildContext context) {
    return Divider(height: 1, color: AppTheme.borderColor(context));
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
