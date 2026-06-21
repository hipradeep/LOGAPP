import 'dart:ui';
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
import 'services/service_locator.dart';
import 'services/activity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture Flutter framework errors (e.g. layout, widget build errors)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // CrashReportingService.logCrash(details.exception, details.stack); // Temporarily disabled
  };

  // Capture asynchronous and Dart zone-level errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    // CrashReportingService.logCrash(error, stack); // Temporarily disabled
    return false; // Let the error print to console normally
  };

  setupLocator();

  // Initialize Firebase (fails gracefully if google-services.json is a dummy)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed/bypassed: $e");
  }

  runApp(const MyApp());

  // Non-essential services initialization runs asynchronously in the background
  _initBackgroundServices();
}

void _initBackgroundServices() {
  Future.microtask(() async {
    // Deactivate finished activities on startup
    try {
      await getIt<ActivityService>().deactivateFinishedActivities();
    } catch (e) {
      debugPrint("Failed to deactivate finished activities on startup: $e");
    }

    // Initialize Notification Service for banner reminders
    try {
      await NotificationService.init();
    } catch (e) {
      debugPrint("Failed to initialize Notification Service: $e");
    }

    // Start syncing activities/subtasks with native local notifications
    try {
      ActivityNotificationSync.init();
    } catch (e) {
      debugPrint("Failed to init ActivityNotificationSync: $e");
    }

    // Start notification transaction scanner if permission is granted
    try {
      final hasScannerPermission = await NotificationTransactionService.isPermissionGranted();
      if (hasScannerPermission) {
        await NotificationTransactionService.startService();
      }
    } catch (e) {
      debugPrint("Failed to auto-start Notification Transaction Service: $e");
    }
  });
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
    // Resolve isDark dynamically based on the current theme type
    final resolvedBrightness = _themeController.themeType == AppThemeType.system
        ? MediaQuery.platformBrightnessOf(context)
        : ((_themeController.themeType == AppThemeType.dark || _themeController.themeType == AppThemeType.orix || _themeController.themeType == AppThemeType.logo) ? Brightness.dark : Brightness.light);

    // Update activeThemeType dynamically
    if (_themeController.themeType == AppThemeType.system) {
      AppTheme.activeThemeType = resolvedBrightness == Brightness.dark
          ? AppThemeType.dark
          : AppThemeType.light;
    } else {
      AppTheme.activeThemeType = _themeController.themeType;
    }
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
