import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../services/local_course_storage.dart';
import '../services/local_subsection_storage.dart';
import '../services/local_revision_storage.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
import '../controllers/revision_controller.dart';
import 'courses_screen.dart';
import 'upload_json_screen.dart';

/// Redesigned Profile Screen matching the reference design:
/// - "Profile" header with settings gear icon
/// - "Pradeep Maurya" user card with "P" purple avatar & "Software Developer"
/// - Full menu list (My Progress, Activity, Courses, Revision Settings,
///   Notifications, Appearance, Backup & Sync, Help & Support, About)
/// - Only "Courses" is interactive and links to [CoursesScreen] as requested.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openCourses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CoursesScreen()),
    );
  }

  void _openUploadJson(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadJsonScreen()),
    );
  }

  Future<void> _handleClearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Cache?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will delete all locally stored course and topic data. '  
          'Your Firestore data will remain safe.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Color(0xFFEF4444)),
            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await Future.wait([
        LocalCourseStorage.clearAll(),
        LocalSubsectionStorage.clearAll(),
        LocalRevisionStorage.clearAll(),
      ]);
      getIt<CoursesController>().refresh();
      if (getIt.isRegistered<RevisionController>()) {
        await getIt<RevisionController>().reconcile();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cache cleared successfully'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: bottomSafe + 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProfileHeader(),
              const VGapLg(),
              const _UserProfileCard(),
              const VGapLg(),
              _ProfileMenuList(
                onCoursesTap: () => _openCourses(context),
                onUploadJsonTap: () => _openUploadJson(context),
                onClearCacheTap: () => _handleClearCache(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === Subcomponents (Rule 2 & 23: Pure, extracted StatelessWidget classes) ===

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        Icon(
          Icons.settings_outlined,
          color: AppTheme.textPrimary,
          size: 24,
        ),
      ],
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        children: [
          _UserAvatar(letter: 'P'),
          HGapMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pradeep Maurya',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                VGapXs(),
                Text(
                  'Software Developer',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF9CA3AF),
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String letter;

  const _UserAvatar({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFB4A5FF),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ProfileMenuList extends StatelessWidget {
  final VoidCallback onCoursesTap;
  final VoidCallback onUploadJsonTap;
  final VoidCallback onClearCacheTap;

  const _ProfileMenuList({
    required this.onCoursesTap,
    required this.onUploadJsonTap,
    required this.onClearCacheTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ProfileMenuItem(
          icon: Icons.show_chart_rounded,
          title: 'My Progress',
        ),
        const _ProfileMenuItem(
          icon: Icons.code_rounded,
          title: 'Activity',
        ),
        // "Courses" - Highlighted with purple stroke & only active link
        _ProfileCoursesHighlightedItem(onTap: onCoursesTap),
        // "Upload JSON" - tappable import entry
        _ProfileTappableMenuItem(
          icon: Icons.upload_file_rounded,
          title: 'Upload JSON',
          onTap: onUploadJsonTap,
        ),
        // "Clear Cache" - red destructive action
        _ProfileTappableMenuItem(
          icon: Icons.cleaning_services_rounded,
          title: 'Clear Cache',
          onTap: onClearCacheTap,
          isDestructive: true,
        ),
        const _ProfileMenuItem(
          icon: Icons.settings_suggest_outlined,
          title: 'Revision Settings',
        ),
        const _ProfileMenuItem(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
        ),
        const _ProfileMenuItem(
          icon: Icons.brightness_6_outlined,
          title: 'Appearance',
        ),
        const _ProfileMenuItem(
          icon: Icons.cloud_outlined,
          title: 'Backup & Sync',
        ),
        const _ProfileMenuItem(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
        ),
        const _ProfileMenuItem(
          icon: Icons.info_outline_rounded,
          title: 'About',
        ),
      ],
    );
  }
}

class _ProfileCoursesHighlightedItem extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileCoursesHighlightedItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryColor, width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
                HGapMd(),
                Expanded(
                  child: Text(
                    'Courses',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF374151),
              size: 22,
            ),
            const HGapMd(),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable profile menu item (with ripple) for active navigation entries.
class _ProfileTappableMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileTappableMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFEF4444) : const Color(0xFF374151);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const HGapMd(),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
