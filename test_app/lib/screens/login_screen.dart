import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';

class LoginScreen extends StatelessWidget {
  final AuthController authController;

  const LoginScreen({
    super.key,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _LoginHeader(),
                const VGapXl(),
                const _FeaturesCard(),
                const VGapXl(),
                _SignInSection(authController: authController),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.cloud_sync_rounded,
            size: 56,
            color: AppTheme.primaryLight,
          ),
        ),
        const VGapMd(),
        const Text(
          'Drive Sync App',
          style: AppTheme.headingLarge,
          textAlign: TextAlign.center,
        ),
        const VGapXs(),
        const Text(
          'Firebase Authentication & Google Drive Sync',
          style: AppTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.6),
        ),
      ),
      child: const Column(
        children: [
          _FeatureRow(
            icon: Icons.shield_outlined,
            title: 'Firebase Identity',
            subtitle: 'Secure sign-in with your Google Account',
          ),
          VGapMd(),
          _FeatureRow(
            icon: Icons.folder_special_outlined,
            title: 'Hidden AppData Drive',
            subtitle: 'Backups are stored safely in your private Drive folder',
          ),
          VGapMd(),
          _FeatureRow(
            icon: Icons.devices_outlined,
            title: 'Cross-Device Restore',
            subtitle: 'Access and restore your data on any Android device',
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingSm),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, color: AppTheme.accentColor, size: 20),
        ),
        const HGapMd(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.headingSmall),
              const VGapXs(),
              Text(subtitle, style: AppTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignInSection extends StatelessWidget {
  final AuthController authController;

  const _SignInSection({required this.authController});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        if (authController.isLoading) {
          return const Column(
            children: [
              CircularProgressIndicator(color: AppTheme.primaryLight),
              VGapMd(),
              Text('Connecting to Google...', style: AppTheme.bodyMedium),
            ],
          );
        }

        return Column(
          children: [
            if (authController.errorMessage != null) ...[
              _ErrorBanner(
                message: authController.errorMessage!,
                onDismiss: authController.clearError,
              ),
              const VGapMd(),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: authController.signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.login_rounded, size: 22),
                label: const Text(
                  'Sign In with Google',
                  style: AppTheme.buttonText,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
          const HGapSm(),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppTheme.error),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
