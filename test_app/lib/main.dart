import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'controllers/auth_controller.dart';
import 'controllers/drive_sync_controller.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/google_auth_service.dart';
import 'services/google_drive_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp warning/error: $e');
  }

  final authService = GoogleAuthService();
  final authController = AuthController(authService);
  final driveService = GoogleDriveService(authService.googleSignIn);
  final driveSyncController = DriveSyncController(driveService);

  // Automatically isolate data per user: clear on sign-out, restore on new sign-in
  String? activeUserId = authController.currentUser?.uid;
  authController.addListener(() {
    final newUserId = authController.currentUser?.uid;
    if (newUserId != activeUserId) {
      activeUserId = newUserId;
      debugPrint('👤 [Main] User switched to: ${newUserId ?? "Signed Out"}');
      driveSyncController.reset();
      if (newUserId != null) {
        debugPrint('📥 [Main] Automatically restoring data for new user...');
        driveSyncController.restoreFromDrive();
      }
    }
  });

  runApp(TestApp(
    authController: authController,
    driveSyncController: driveSyncController,
  ));
}

class TestApp extends StatelessWidget {
  final AuthController authController;
  final DriveSyncController driveSyncController;

  const TestApp({
    super.key,
    required this.authController,
    required this.driveSyncController,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drive Sync Test',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _RootNavigation(
        authController: authController,
        driveSyncController: driveSyncController,
      ),
    );
  }
}

class _RootNavigation extends StatelessWidget {
  final AuthController authController;
  final DriveSyncController driveSyncController;

  const _RootNavigation({
    required this.authController,
    required this.driveSyncController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        if (authController.isAuthenticated) {
          return HomeScreen(
            authController: authController,
            driveSyncController: driveSyncController,
          );
        }
        return LoginScreen(
          authController: authController,
        );
      },
    );
  }
}
