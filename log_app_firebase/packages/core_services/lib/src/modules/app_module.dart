import 'package:flutter/material.dart';

abstract class AppModule {
  String get id;
  String get name;
  String get description;
  bool get isPremium;

  Future<void> initialize();
  Future<void> shutdown();

  Widget buildDashboardWidget(BuildContext context);
  List<NavigationItem> getNavigationItems(BuildContext context);
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;
  final WidgetBuilder builder;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.builder,
  });
}
