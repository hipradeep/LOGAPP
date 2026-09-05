import 'package:flutter/widgets.dart';

/// Zero-dependency custom state wrapper based on [InheritedNotifier].
class AppProvider<T extends Listenable> extends InheritedNotifier<T> {
  const AppProvider({
    super.key,
    required T super.notifier,
    required super.child,
  });

  /// Obtain and listen to changes from [T].
  static T watch<T extends Listenable>(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppProvider<T>>();
    assert(provider != null, 'No AppProvider<$T> found in the widget tree.');
    return provider!.notifier!;
  }

  /// Obtain [T] without subscribing to rebuilds.
  static T read<T extends Listenable>(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppProvider<T>>();
    final widget = element?.widget as AppProvider<T>?;
    assert(widget != null, 'No AppProvider<$T> found in the widget tree.');
    return widget!.notifier!;
  }
}
