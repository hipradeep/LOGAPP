import 'package:flutter/widgets.dart';

class Responsive {
  static double height(BuildContext context) => MediaQuery.sizeOf(context).height;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static double heightPercent(BuildContext context, double percent) =>
      MediaQuery.sizeOf(context).height * (percent / 100);

  static double widthPercent(BuildContext context, double percent) =>
      MediaQuery.sizeOf(context).width * (percent / 100);

  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;
}
