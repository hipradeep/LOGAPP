import 'package:flutter/material.dart';

class GlobalOverlayRegistry {
  static final ValueNotifier<bool> showBannerNotifier = ValueNotifier<bool>(false);
  static WidgetBuilder? bannerBuilder;
  static double bannerHeight = 38.0;
}
