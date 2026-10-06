import 'dart:async';
import '../models/module.dart';
import 'database_service.dart';

/// Local storage for Module entities backed by SQLite [DatabaseService].
class LocalModuleStorage {
  /// Loads all modules for a given [courseId] from SQLite.
  static Future<List<Module>> loadModules(String courseId) {
    return DatabaseService.instance.getModules(courseId: courseId);
  }

  /// Loads all modules across all courses from SQLite.
  static Future<List<Module>> loadAllModules() {
    return DatabaseService.instance.getAllModules();
  }

  /// Saves or updates modules for a specific [courseId].
  static Future<void> saveModulesForCourse(
    String courseId,
    List<Module> courseModules,
  ) {
    return DatabaseService.instance.saveModules(courseId, courseModules);
  }

  /// Overwrites all modules.
  static Future<void> saveAllModules(List<Module> modules) async {
    for (final module in modules) {
      await DatabaseService.instance.addModule(module);
    }
  }

  /// Looks up a single module by id.
  static Future<Module?> getModuleById(String moduleId) {
    return DatabaseService.instance.getModuleById(moduleId);
  }

  /// Clears all modules from SQLite.
  static Future<void> clearAll() {
    return DatabaseService.instance.clearModules();
  }
}
