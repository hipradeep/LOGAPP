import 'package:flutter/widgets.dart';

class Responsive {
  // Get the full height of the screen
  static double height(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  // Get the full width of the screen
  static double width(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  // Get a percentage of the screen height (e.g., heightPercent(context, 50) = 50% height)
  static double heightPercent(BuildContext context, double percent) {
    return MediaQuery.of(context).size.height * (percent / 100);
  }

  // Get a percentage of the screen width
  static double widthPercent(BuildContext context, double percent) {
    return MediaQuery.of(context).size.width * (percent / 100);
  }

  // Check if device is considered small (e.g., older iPhones)
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }
}
