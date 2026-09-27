import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  final ThemeController themeController;

  const SplashScreen({
    super.key,
    required this.themeController,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();

    Timer(const Duration(milliseconds: 2000), _navigateToHome);
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, animation, secondaryAnimation) =>
            FadeTransition(
          opacity: animation,
          child: MainNavigationScreen(
            themeController: widget.themeController,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.resolvedBackgroundGradient(context),
              ),
            ),
          ),

          // Background ambient lights
          GlowBlob(
            top: -60,
            left: -60,
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            size: 260,
          ),
          GlowBlob(
            bottom: -60,
            right: -60,
            color: AppTheme.primaryLight.withValues(alpha: 0.2),
            size: 280,
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryLight,
                            AppTheme.primaryColor,
                            AppTheme.primaryDark,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 28,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const VGapLg(),
                    Text(
                      'Budget',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const VGapXs(),
                    Text(
                      'Smart Cloud Financial Tracker',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Powered by Firebase Cloud Sync',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textMutedColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
