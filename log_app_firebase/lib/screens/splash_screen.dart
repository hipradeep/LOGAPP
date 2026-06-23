import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import 'main_navigation_screen.dart';
import 'permission_screen.dart';
import 'pomodoro_timer_screen.dart';
import '../services/cache_service.dart';
import '../models/activity.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Wait for the animation and display duration (3 seconds total)
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;

    // Check if there is an active running Pomodoro session
    final activeSession = await CacheService().getActivePomodoroSession();
    if (activeSession != null) {
      final endTimestamp = activeSession['endTimestamp'] as int? ?? 0;
      final isRunning = activeSession['isRunning'] as bool? ?? false;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (isRunning && now < endTimestamp) {
        final activityJson = activeSession['activity'] as Map<String, dynamic>;
        final remainingQueueJson = activeSession['remainingQueue'] as List<dynamic>? ?? [];
        final initialDurationMinutes = activeSession['initialDurationMinutes'] as int?;

        final activity = Activity.fromJson(activityJson);
        final remainingQueue = remainingQueueJson
            .map((a) => Activity.fromJson(Map<String, dynamic>.from(a as Map)))
            .toList();

        final secondsRemaining = ((endTimestamp - now) / 1000).round();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PomodoroTimerScreen(
                activity: activity,
                remainingQueue: remainingQueue,
                initialDurationMinutes: initialDurationMinutes,
                initialSecondsRemaining: secondsRemaining,
              ),
            ),
          );
          return;
        }
      } else {
        await CacheService().clearActivePomodoroSession();
      }
    }

    // Check if notification permission is already granted
    final isNotificationGranted = await Permission.notification.isGranted;

    if (!mounted) return;

    if (isNotificationGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PermissionScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // CRITICAL: Registers this component to rebuild on theme switch
    return FullScreenPage(
      isScrollable: false,
      alignment: PageAlignment.center,
      children: [
        FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Logo Container
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 50,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/splash_logo.png',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                ),
                const VGapXl(),
                Text(
                  'LOG',
                  style: AppTheme.headingLarge.copyWith(
                    fontSize: 48,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                Text(
                  'TRACK YOUR LIFE',
                  style: AppTheme.bodySmall.copyWith(
                    letterSpacing: 4,
                    color: AppTheme.primaryAccentColor(context).withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const VGapXxl(),
        const VGapXxl(),
        // Loading Indicator at bottom
        FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            width: 40,
            height: 2,
            child: LinearProgressIndicator(
              backgroundColor: AppTheme.borderColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ),
      ],
    );
  }
}
