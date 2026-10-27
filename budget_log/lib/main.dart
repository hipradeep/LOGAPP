import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/cloud_sync_controller.dart';
import 'controllers/finance_controller.dart';
import 'controllers/theme_controller.dart';
import 'screens/main_navigation_screen.dart';
import 'services/service_locator.dart';
import 'theme/app_theme.dart';
import 'widgets/app_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  setupLocator();
  await initializeServices();
  runApp(const BudgetLogApp());
  unawaited(getIt<CloudSyncController>().init());
}

class BudgetLogApp extends StatelessWidget {
  const BudgetLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = getIt<ThemeController>();
    final financeController = getIt<FinanceController>();

    return AppProvider<ThemeController>(
      notifier: themeController,
      child: AppProvider<FinanceController>(
        notifier: financeController,
        child: ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            final isDark =
                themeController.effectiveBrightness == Brightness.dark;

            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness: isDark
                    ? Brightness.dark
                    : Brightness.light,
                systemNavigationBarColor: isDark
                    ? AppTheme.darkBackgroundColor
                    : AppTheme.lightBackgroundColor,
                systemNavigationBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
              ),
            );

            return MaterialApp(
              title: 'Budget Log',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.themeData,
              darkTheme: AppTheme.darkThemeData,
              themeMode: themeController.themeMode,
              home: const MainNavigationScreen(),
            );
          },
        ),
      ),
    );
  }
}
