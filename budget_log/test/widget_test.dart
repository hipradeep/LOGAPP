import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_log/controllers/theme_controller.dart';
import 'package:budget_log/screens/design_system_screen.dart';
import 'package:budget_log/theme/app_theme.dart';
import 'package:budget_log/widgets/app_provider.dart';

void main() {
  testWidgets('design system renders in light and dark themes', (tester) async {
    final controller = ThemeController();

    await tester.pumpWidget(
      AppProvider<ThemeController>(
        notifier: controller,
        child: MaterialApp(
          theme: AppTheme.themeData,
          home: const DesignSystemScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Design System'), findsOneWidget);
    expect(find.text('SEMANTIC COLORS'), findsOneWidget);

    await tester.pumpWidget(
      AppProvider<ThemeController>(
        notifier: controller,
        child: MaterialApp(
          theme: AppTheme.darkThemeData,
          home: const DesignSystemScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Design System'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });
}
