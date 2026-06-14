import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import 'main_navigation_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isChecking = false;

  Future<void> _requestNotificationPermission() async {
    setState(() => _isChecking = true);
    try {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        _navigateToMain();
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    } catch (e) {
      // Fail silently
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _navigateToMain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      showScaffold: true,
      isScrollable: false,
      alignment: PageAlignment.center,
      backgroundWidgets: _buildBackgroundBlobs(),
      children: [
        _buildHeaderIcon(),
        const VGapXl(),
        _buildTextContent(),
        const VGapXl(),
        _buildActionButtons(),
      ],
    );
  }

  List<Widget> _buildBackgroundBlobs() {
    return const [
      GlowBlob(
        top: -40,
        left: -40,
        size: 220,
        color: AppTheme.primaryColor,
        opacity: 0.12,
      ),
      GlowBlob(
        bottom: -50,
        right: -50,
        size: 260,
        color: AppTheme.secondaryColor,
        opacity: 0.08,
      ),
    ];
  }

  Widget _buildHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
      ),
      child: const Icon(
        Icons.notifications_active_rounded,
        color: AppTheme.primaryColor,
        size: 64,
      ),
    );
  }

  Widget _buildTextContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enable Notifications',
          style: AppTheme.headingLarge.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const VGapSm(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'LOG triggers system banner notifications exactly when your scheduled reminders are due, keeping you on track throughout the day.',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: AppTheme.buttonHeight,
          child: ElevatedButton(
            onPressed: _isChecking ? null : _requestNotificationPermission,
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
                : const Text('Grant Notification Permission'),
          ),
        ),
        const VGapMd(),
        TextButton(
          onPressed: _navigateToMain,
          child: Text(
            'Skip for Now',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
