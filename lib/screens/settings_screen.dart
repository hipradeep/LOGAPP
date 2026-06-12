import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import '../widgets/edit_profile_sheet.dart';
import 'track_activities_screen.dart';
import 'manage_budget_screen.dart';
import '../services/cache_service.dart';
import '../services/activity_service.dart';
import '../services/log_service.dart';
import '../services/budget_service.dart';
import '../models/activity.dart';
import '../models/log_entry.dart';
import '../models/budget_item.dart';
import 'manage_quick_actions_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CacheService _cacheService = CacheService();
  final ActivityService _activityService = ActivityService();
  final LogService _logService = LogService();
  final BudgetService _budgetService = BudgetService();

  String _userName = 'Log User';
  String _userAvatar = '🦁';
  bool _dailyReminder = false;
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadCacheSettings();
  }

  Future<void> _loadCacheSettings() async {
    final name = await _cacheService.getUserName();
    final avatar = await _cacheService.getUserAvatar();
    final reminder = await _cacheService.getDailyReminder();
    if (mounted) {
      setState(() {
        _userName = name;
        _userAvatar = avatar;
        _dailyReminder = reminder;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile(String name, String avatar) async {
    await _cacheService.saveUserName(name);
    await _cacheService.saveUserAvatar(avatar);
    setState(() {
      _userName = name;
      _userAvatar = avatar;
    });
  }

  Future<void> _toggleReminder(bool enabled) async {
    await _cacheService.saveDailyReminder(enabled);
    setState(() {
      _dailyReminder = enabled;
    });
  }

  Future<void> _resetCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius)),
        title: Text('Reset Profile Settings', style: AppTheme.headingSmall),
        content: Text(
          'Are you sure you want to reset your profile details and toggle settings? This won\'t delete your activities or logs.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTheme.bodyMedium),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cacheService.clearAllCache();
      await _loadCacheSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings cache cleared successfully.')),
      );
    }
  }

  void _showComingSoonSnackBar(String featureName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName option is coming soon in LOG Pro!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _showProUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text('LOG Pro Beta', style: AppTheme.headingSmall),
          ],
        ),
        content: Text(
          'LOG Pro will unlock features like custom color themes, biometric app locks, automated cloud backups, and export options.\n\nAll premium features will be unlocked for early beta testers in the next build! Thank you for testing LOG.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got It', style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryLight)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileSheet(
        initialName: _userName,
        initialAvatar: _userAvatar,
        onSave: _updateProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const FullScreenPage(
        title: 'Settings',
        children: [
          Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
        ],
      );
    }

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
        GlowBlob(
          bottom: -60,
          right: -40,
          size: 260,
          color: AppTheme.secondaryColor,
          opacity: 0.06,
        ),
      ],
      children: [
        const VGapMd(),
        
        // 1. Profile card with stats
        _buildProfileCard(),
        
        const VGapLg(),

        // 2. Pro Upgrade Card
        _buildProUpgradeCard(),

        const VGapLg(),

        // 3. Tracking & Goals
        _buildSectionCard(
          title: 'Goals & Tracking',
          children: [
            _buildMenuItem(
              icon: Icons.check_circle_outline_rounded,
              iconBgColor: AppTheme.primaryColor,
              title: 'Track Activities',
              subtitle: 'Select habits and attendance items to track',
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
              icon: Icons.account_balance_wallet_outlined,
              iconBgColor: AppTheme.successColor,
              title: 'Manage Budget',
              subtitle: 'Set salary, item limits, and track savings',
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
            _buildMenuItem(
              icon: Icons.bolt_rounded,
              iconBgColor: AppTheme.secondaryColor,
              title: 'Manage Quick Actions',
              subtitle: 'Select which shortcut panels appear on Dashboard',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageQuickActionsScreen(),
                  ),
                );
              },
            ),
          ],
        ),

        const VGapLg(),

        // 4. Preferences & Security
        _buildSectionCard(
          title: 'Preferences & Security',
          children: [
            _buildSwitchItem(
              icon: Icons.notifications_active_outlined,
              iconBgColor: AppTheme.primaryColor,
              title: 'Daily Journal Reminder',
              subtitle: 'Receive a daily nudge to record your thoughts',
              value: _dailyReminder,
              onChanged: _toggleReminder,
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.lock_outline_rounded,
              iconBgColor: Colors.blueAccent,
              title: 'App Lock & PIN',
              subtitle: 'Secure your journal entries with a passcode',
              trailing: _buildComingSoonBadge(),
              onTap: () => _showComingSoonSnackBar('App Lock'),
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.palette_outlined,
              iconBgColor: Colors.pinkAccent,
              title: 'Custom Themes',
              subtitle: 'Tailor the application accent and gradients',
              trailing: _buildComingSoonBadge(),
              onTap: () => _showComingSoonSnackBar('Custom Themes'),
            ),
          ],
        ),

        const VGapLg(),

        // 5. Data & Sync
        _buildSectionCard(
          title: 'Data & Sync',
          children: [
            _buildMenuItem(
              icon: Icons.cloud_sync_outlined,
              iconBgColor: Colors.teal,
              title: 'Cloud Backup & Sync',
              subtitle: 'Save and synchronize settings and logs',
              trailing: _buildComingSoonBadge(),
              onTap: () => _showComingSoonSnackBar('Cloud Backup'),
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.delete_outline_rounded,
              iconBgColor: AppTheme.errorColor,
              title: 'Clear Cache & Reset',
              subtitle: 'Restore local settings, username, and toggles',
              onTap: _resetCache,
            ),
          ],
        ),

        const VGapLg(),

        // 6. App Info
        _buildSectionCard(
          title: 'Info & Support',
          children: [
            _buildMenuItem(
              icon: Icons.star_outline_rounded,
              iconBgColor: Colors.amber,
              title: 'Review LOG App',
              subtitle: 'Share feedback or rate us on Play Store',
              onTap: () {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for testing LOG! Custom review link coming soon.'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.info_outline_rounded,
              iconBgColor: AppTheme.textSecondary,
              title: 'About LOG',
              subtitle: 'Learn more about LOG developers',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'LOG',
                  applicationVersion: '1.1.0',
                  applicationIcon: const Text('🚀', style: TextStyle(fontSize: 32)),
                  children: const [
                    Text('A premium daily journal and activity tracker for Android.'),
                  ],
                );
              },
            ),
          ],
        ),
        
        const VGapXxl(),
        const VGapXxl(),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar emoji inside glowing circle
                Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(_userAvatar, style: const TextStyle(fontSize: 32)),
                  ),
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: AppTheme.headingSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'LOG Member',
                          style: TextStyle(
                            color: AppTheme.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Edit Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: AppTheme.primaryLight,
                  onPressed: _showEditProfileSheet,
                  tooltip: 'Edit Profile',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          
          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Stat 1: Habits
                Expanded(
                  child: StreamBuilder<List<Activity>>(
                    stream: _activityService.getCheckedActivitiesStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _buildStatColumn('Habits', count.toString(), Icons.check_circle_outline_rounded, AppTheme.primaryLight);
                    },
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white10),
                // Stat 2: Logs
                Expanded(
                  child: StreamBuilder<List<LogEntry>>(
                    stream: _logService.getLogsStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _buildStatColumn('Logs', count.toString(), Icons.history_rounded, Colors.tealAccent);
                    },
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white10),
                // Stat 3: Budgets
                Expanded(
                  child: StreamBuilder<List<BudgetItem>>(
                    stream: _budgetService.getBudgetsStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _buildStatColumn('Budgets', count.toString(), Icons.account_balance_wallet_outlined, AppTheme.successColor);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTheme.headingSmall.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProUpgradeCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.15),
            Colors.amber.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: _showProUpgradeDialog,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 22),
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to LOG Pro',
                      style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                    const VGapXs(),
                    Text(
                      'Unlock advanced cloud sync, app locks, and themes.',
                      style: AppTheme.bodySmall.copyWith(fontSize: 11, color: Colors.amber.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconBgColor.withValues(alpha: 0.8), size: 20),
            ),
            const HGapMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing,
            ] else ...[
              const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconBgColor.withValues(alpha: 0.8), size: 20),
          ),
          const HGapMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const VGapXs(),
                Text(
                  subtitle,
                  style: AppTheme.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.primaryColor,
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.4),
            inactiveThumbColor: AppTheme.textSecondary,
            inactiveTrackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: const Text(
        'Soon',
        style: TextStyle(
          color: AppTheme.primaryLight,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.05),
      indent: 16,
      endIndent: 16,
    );
  }
}
