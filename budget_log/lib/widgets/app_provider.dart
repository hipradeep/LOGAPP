import 'package:flutter/material.dart';

class AppProvider<T extends Listenable> extends InheritedNotifier<T> {
  const AppProvider({
    super.key,
    required T super.notifier,
    required super.child,
  });

  static T watch<T extends Listenable>(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<AppProvider<T>>();
    assert(provider != null, 'No AppProvider<$T> found in context');
    return provider!.notifier!;
  }

  static T read<T extends Listenable>(BuildContext context) {
    final provider =
        context
                .getElementForInheritedWidgetOfExactType<AppProvider<T>>()
                ?.widget
            as AppProvider<T>?;
    assert(provider != null, 'No AppProvider<$T> found in context');
    return provider!.notifier!;
  }
}
