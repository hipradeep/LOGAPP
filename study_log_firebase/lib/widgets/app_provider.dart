import 'package:flutter/material.dart';

/// Zero-dependency state provider relying on [InheritedNotifier].
/// Allows surgical rebuilds without third-party libraries.
class AppProvider<T extends Listenable> extends InheritedNotifier<T> {
  const AppProvider({
    super.key,
    required T super.notifier,
    required super.child,
  });

  /// [watch] registers the calling [BuildContext] to rebuild whenever [notifier] notifies listeners.
  static T watch<T extends Listenable>(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppProvider<T>>();
    assert(provider != null, 'No AppProvider<$T> found in context');
    return provider!.notifier!;
  }

  /// [read] returns the [notifier] without registering the context for rebuilds.
  /// Ideal for one-time method calls, button presses, and event handlers.
  static T read<T extends Listenable>(BuildContext context) {
    final provider = context.getElementForInheritedWidgetOfExactType<AppProvider<T>>()?.widget as AppProvider<T>?;
    assert(provider != null, 'No AppProvider<$T> found in context');
    return provider!.notifier!;
  }
}
