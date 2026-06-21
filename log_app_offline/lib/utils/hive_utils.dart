import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

/// Shared Hive box helpers.
class HiveUtils {
  HiveUtils._();

  /// Converts a Hive [Box] into a broadcast [Stream] of [List<T>].
  ///
  /// Emits immediately with current box contents, then re-emits on every change.
  static Stream<List<T>> boxToStream<T>(
    Box box,
    T Function(String id, Map<String, dynamic> map) fromJson,
  ) {
    final controller = StreamController<List<T>>.broadcast();
    final listenable = box.listenable();

    void emit() {
      if (!controller.isClosed) {
        controller.add(_readAll<T>(box, fromJson));
      }
    }

    controller.onListen = () {
      listenable.addListener(emit);
      emit(); // emit immediately on subscribe
    };
    controller.onCancel = () {
      listenable.removeListener(emit);
    };

    return controller.stream;
  }

  /// Reads and converts all entries from a [Box] to [List<T>].
  static List<T> readAll<T>(
    Box box,
    T Function(String id, Map<String, dynamic> map) fromJson,
  ) =>
      _readAll(box, fromJson);

  static List<T> _readAll<T>(
    Box box,
    T Function(String id, Map<String, dynamic> map) fromJson,
  ) {
    final result = <T>[];
    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw != null) {
          result.add(fromJson(key.toString(), Map<String, dynamic>.from(raw as Map)));
        }
      } catch (_) {
        // Skip malformed entries silently
      }
    }
    return result;
  }

  /// Safe single-key read — returns null if key is missing or malformed.
  static Map<String, dynamic>? safeGet(Box box, String key) {
    try {
      final raw = box.get(key);
      if (raw == null) return null;
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }
}
