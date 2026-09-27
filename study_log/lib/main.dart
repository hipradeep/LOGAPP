import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'controllers/theme_controller.dart';
import 'services/service_locator.dart';
import 'services/navigation_service.dart';
import 'widgets/app_provider.dart';
import 'screens/home_screen.dart';

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

  // Configure system UI overlay matching the minimalist theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.backgroundColor,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

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
  void dispose() {
    // Note: getIt singletons are disposed on app termination if needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppProvider<ThemeController>(
      notifier: _themeController,
      child: MaterialApp(
        title: 'Study/log',
        debugShowCheckedModeBanner: false,
        navigatorKey: NavigationService.navigatorKey,
        theme: AppTheme.themeData,
        home: const HomeScreen(),
      ),
    );
  }
}
