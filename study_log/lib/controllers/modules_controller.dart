import 'dart:async';
import 'package:flutter/material.dart';
import '../models/module.dart';
import '../services/database_service.dart';
import '../services/local_module_storage.dart';
import '../services/service_locator.dart';
import 'ongoing_modules_controller.dart';

/// Controller managing Module entities for a given Course with local SQLite persistence.
class ModulesController extends ChangeNotifier {
  final String courseId;
  final DatabaseService _dbService;
  StreamSubscription<List<Module>>? _modulesSubscription;

  List<Module> _modules = [];
  bool _isLoading = true;
  String? _errorMessage;

  ModulesController({
    required this.courseId,
    DatabaseService? databaseService,
  }) : _dbService = databaseService ?? getIt<DatabaseService>() {
    _init();
  }

  List<Module> get modules => List.unmodifiable(_modules);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _init() async {
    // 1. Immediately hydrate from SQLite
    try {
      final cached = await _dbService.getModules(courseId: courseId);
      if (cached.isNotEmpty) {
        _modules = cached;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Local modules hydration error: $e');
    }

    // 2. Start reactive SQLite stream
    _initStream();
  }

  void _initStream() {
    _modulesSubscription?.cancel();
    _errorMessage = null;

    try {
      _modulesSubscription = _dbService.streamModules(courseId: courseId).listen(
        (remoteModules) {
          _isLoading = false;
          _errorMessage = null;
          _modules = remoteModules;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Error streaming modules from database: $error');
          _isLoading = false;
          if (_modules.isEmpty) {
            _errorMessage = error.toString();
          }
          notifyListeners();
        },
      );
    } catch (e) {
      _isLoading = false;
      if (_modules.isEmpty) {
        _errorMessage = e.toString();
      }
      notifyListeners();
    }
  }

  Future<void> addModule({
    required String title,
    required String description,
    int? orderIndex,
    String status = 'active',
  }) async {
    final now = DateTime.now();
    final newId = 'module_${now.millisecondsSinceEpoch}';
    final nextOrder = orderIndex ??
        (_modules.isEmpty
            ? 1
            : (_modules.map((s) => s.orderIndex).reduce((a, b) => a > b ? a : b) + 1));

    final newModule = Module(
      id: newId,
      courseId: courseId,
      title: title,
      description: description,
      orderIndex: nextOrder,
      status: status,
      createdAt: now,
      updatedAt: now,
    );

    _modules.removeWhere((s) => s.id == newId);
    _modules.add(newModule);
    _modules.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();

    if (getIt.isRegistered<OngoingModulesController>()) {
      getIt<OngoingModulesController>().refresh();
    }

    try {
      await _dbService.addModule(newModule);
    } catch (e) {
      debugPrint('Database addModule error: $e');
    }
  }

  Future<void> updateModule(Module module) async {
    final index = _modules.indexWhere((s) => s.id == module.id);
    if (index == -1) return;
    final updated = module.copyWith(updatedAt: DateTime.now());
    _modules[index] = updated;
    _modules.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();

    if (getIt.isRegistered<OngoingModulesController>()) {
      getIt<OngoingModulesController>().refresh();
    }

    try {
      await _dbService.updateModule(updated);
    } catch (e) {
      debugPrint('Database updateModule error: $e');
    }
  }

  Future<void> deleteModule(String moduleId) async {
    _modules.removeWhere((s) => s.id == moduleId);
    notifyListeners();

    if (getIt.isRegistered<OngoingModulesController>()) {
      getIt<OngoingModulesController>().refresh();
    }

    try {
      await _dbService.deleteModule(moduleId);
    } catch (e) {
      debugPrint('Database deleteModule error: $e');
    }
  }

  @override
  void dispose() {
    _modulesSubscription?.cancel();
    super.dispose();
  }
}
