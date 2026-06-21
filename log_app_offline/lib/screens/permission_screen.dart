import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import 'main_navigation_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with WidgetsBindingObserver {
  bool _isNotificationGranted = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final notificationStatus = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _isNotificationGranted = notificationStatus.isGranted;
      });
    }
  }

  Future<void> _requestPushNotificationPermission() async {
    setState(() => _isChecking = true);
    try {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        await _checkPermissions();
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    } catch (_) {
      // Fail silently
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _navigateToMain() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    }
  }

  void _handlePrimaryAction() {
    if (!_isNotificationGranted) {
      _requestPushNotificationPermission();
    } else {
      _navigateToMain();
    }
  }

  Widget _buildPermissionCards() {
    return _PermissionCard(
      title: 'Push Notifications',
      description: 'LOG triggers system banner notifications exactly when your scheduled reminders are due, keeping you on track throughout the day.',
      icon: Icons.notifications_active_rounded,
      isGranted: _isNotificationGranted,
      onTap: _requestPushNotificationPermission,
    );
  }

  Widget _buildActionButtons() {
    final String buttonText = _isNotificationGranted
        ? 'Continue to LOG'
        : 'Enable Push Notifications';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: AppTheme.buttonHeight,
          child: ElevatedButton(
            onPressed: _isChecking ? null : _handlePrimaryAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
              elevation: 8,
            ),
            child: _isChecking
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(buttonText),
          ),
        ),
        const VGapMd(),
        TextButton(
          onPressed: _navigateToMain,
          child: Text(
            'Skip for Now',
            style: TextStyle(
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      showScaffold: true,
      isScrollable: true,
      alignment: PageAlignment.center,
      children: [
        const _PermissionHeader(),
        const VGapXl(),
        _buildPermissionCards(),
        const VGapXl(),
        _buildActionButtons(),
      ],
    );
  }
}

class _PermissionHeader extends StatelessWidget {
  const _PermissionHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
          ),
          child: Icon(
            Icons.notifications_active_rounded,
            color: AppTheme.primaryColor,
            size: 64,
          ),
        ),
        const VGapXl(),
        Text(
          'Enable App Permissions',
          style: AppTheme.headingLarge.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const VGapSm(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'LOG requires notification permission to keep you on track with scheduled reminders.',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? AppTheme.successColor.withValues(alpha: 0.4)
              : AppTheme.borderColor(context).withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isGranted ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isGranted ? AppTheme.successColor : AppTheme.primaryColor)
                        .withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    icon,
                    color: isGranted ? AppTheme.successColor : AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const VGapSm(),
                      Text(
                        description,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const HGapSm(),
                _buildStatusBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (isGranted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 12),
            HGapSm(),
            Text(
              'Active',
              style: TextStyle(
                color: AppTheme.successColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Configure',
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
