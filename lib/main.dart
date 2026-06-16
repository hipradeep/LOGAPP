import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_provider.dart';
import 'controllers/theme_controller.dart';

import 'services/notification_service.dart';
import 'services/activity_notification_sync.dart';
import 'services/notification_transaction_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (fails gracefully if google-services.json is a dummy)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed/bypassed: $e");
  }

  // Initialize Notification Service for banner reminders
  await NotificationService.init();

  // Start syncing activities/subtasks with native local notifications
  ActivityNotificationSync.init();

  // Start notification transaction scanner if permission is granted
  try {
    final hasScannerPermission = await NotificationTransactionService.isPermissionGranted();
    if (hasScannerPermission) {
      await NotificationTransactionService.startService();
    }
  } catch (e) {
    debugPrint("Failed to auto-start Notification Transaction Service: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController();
    _themeController.addListener(_onThemeChanged);
    // Apply initial system UI style for dark default
    _applySystemUiStyle(isDark: true);
  }

  void _onThemeChanged() {
    final bool resolvedDark;
    if (_themeController.themeMode == ThemeMode.system) {
      resolvedDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    } else {
      resolvedDark = _themeController.isDark;
    }
    _applySystemUiStyle(isDark: resolvedDark);
    setState(() {});
  }

  void _applySystemUiStyle({required bool isDark}) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          isDark ? AppTheme.backgroundColor : AppTheme.lightBackgroundColor,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Resolve isDark dynamically based on the current theme mode and system settings
    final resolvedBrightness = _themeController.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context)
        : (_themeController.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);
    AppTheme.isDark = resolvedBrightness == Brightness.dark;

    return AppProvider<ThemeController>(
      notifier: _themeController,
      child: MaterialApp(
        title: 'LOG',
        debugShowCheckedModeBanner: false,
        themeMode: _themeController.themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
