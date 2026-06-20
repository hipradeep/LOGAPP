// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:log/main.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the splash screen shows LOG branding.
    expect(find.text('LOG'), findsOneWidget);
    expect(find.text('TRACK YOUR LIFE'), findsOneWidget);

    // Advance the virtual clock by 3 seconds to resolve the splash timer and animations.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });
}
