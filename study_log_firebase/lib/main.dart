import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'controllers/theme_controller.dart';
import 'services/service_locator.dart';
import 'services/navigation_service.dart';
import 'services/notification_service.dart';
import 'widgets/app_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with native google-services configuration
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization failed/bypassed: $e');
  }

  // Global Flutter error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Asynchronous error handling
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    return false;
  };

  setupLocator();

  // Resolve the saved theme before the first frame so the very first paint
  // already uses the right brightness.
  await getIt<ThemeController>().load();

  // Pre-load data in background immediately on startup so it is ready on launch
  unawaited(warmupControllers());

  // Register the local notifications plugin early so test/scheduled reminders
  // can be delivered without waiting for a user interaction.
  unawaited(getIt<NotificationService>().init());

  runApp(const StudyLogApp());
}

class StudyLogApp extends StatefulWidget {
  const StudyLogApp({super.key});

  @override
  State<StudyLogApp> createState() => _StudyLogAppState();
}

class _StudyLogAppState extends State<StudyLogApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = getIt<ThemeController>();
  }

  @override
  Widget build(BuildContext context) {
    return AppProvider<ThemeController>(
      notifier: _themeController,
      child: ListenableBuilder(
        listenable: _themeController,
        builder: (context, _) {
          final isDark = _themeController.effectiveBrightness == Brightness.dark;

          // Status bar icons must contrast with the active background.
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: AppTheme.background(context),
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            ),
          );

          return MaterialApp(
            title: 'Study',
            debugShowCheckedModeBanner: false,
            navigatorKey: NavigationService.navigatorKey,
            theme: AppTheme.themeData,
            darkTheme: AppTheme.darkThemeData,
            themeMode: _themeController.themeMode,
            home: const SplashScreen(appName: 'Study'),
          );
        },
      ),
    );
  }
}
