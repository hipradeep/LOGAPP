import 'dart:async';
import 'package:flutter/material.dart';
import '../models/module.dart';
import '../services/firestore_service.dart';
import '../services/local_module_storage.dart';
import '../services/service_locator.dart';
import 'ongoing_modules_controller.dart';

/// Controller managing Module entities for a given Course with offline persistence.
class ModulesController extends ChangeNotifier {
  final String courseId;
  final FirestoreService _firestoreService;
  StreamSubscription<List<Module>>? _modulesSubscription;
  Timer? _loadingFallbackTimer;

  List<Module> _modules = [];
  final Set<String> _deletedModuleIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  ModulesController({
    required this.courseId,
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>() {
    _init();
  }

  List<Module> get modules => List.unmodifiable(_modules);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _init() async {
    // 1. Immediately hydrate from local storage
    try {
      final cached = await LocalModuleStorage.loadModules(courseId);
      if (cached.isNotEmpty) {
        _modules = cached;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Local modules hydration error: $e');
    }

    // 2. Start Firestore stream
    _initStream();
  }

  void _initStream() {
    _modulesSubscription?.cancel();
    _loadingFallbackTimer?.cancel();
    _errorMessage = null;

    if (_modules.isEmpty) {
      _isLoading = true;
    }

    _loadingFallbackTimer = Timer(const Duration(seconds: 2), () {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    });

    try {
      _modulesSubscription = _firestoreService.streamModules(courseId: courseId).listen(
        (remoteModules) {
          _loadingFallbackTimer?.cancel();
          _isLoading = false;
          _errorMessage = null;
          _mergeModules(remoteModules);
        },
        onError: (error) {
          _loadingFallbackTimer?.cancel();
          debugPrint('Error streaming modules: $error');
          _isLoading = false;
          if (_modules.isEmpty) {
            _errorMessage = error.toString();
          }
          notifyListeners();
        },
      );
    } catch (e) {
      _loadingFallbackTimer?.cancel();
      _isLoading = false;
      if (_modules.isEmpty) {
        _errorMessage = e.toString();
      }
      notifyListeners();
    }
  }

  void _mergeModules(List<Module> remoteModules) {
    final Map<String, Module> merged = {};

    for (final module in remoteModules) {
      if (!_deletedModuleIds.contains(module.id)) {
        merged[module.id] = module;
      }
    }

    for (final local in _modules) {
      if (!_deletedModuleIds.contains(local.id)) {
        if (!merged.containsKey(local.id)) {
          merged[local.id] = local;
        }
      }
    }

    final result = merged.values.toList();
    result.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    _modules = result;
    LocalModuleStorage.saveModulesForCourse(courseId, _modules);
    notifyListeners();
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

    _deletedModuleIds.remove(newId);
    _modules.removeWhere((s) => s.id == newId);
    _modules.add(newModule);
    _modules.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    _isLoading = false;
    _errorMessage = null;
    await LocalModuleStorage.saveModulesForCourse(courseId, _modules);
    notifyListeners();

    if (getIt.isRegistered<OngoingModulesController>()) {
      getIt<OngoingModulesController>().refresh();
    }

    try {
      await _firestoreService.addModule(newModule).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Firestore addModule timed out, stored locally.');
        },
      );
    } catch (e) {
      debugPrint('Firestore addModule error: $e');
    }
  }

  Future<void> updateModule(Module module) async {
    final index = _modules.indexWhere((s) => s.id == module.id);
    if (index == -1) return;
    final updated = module.copyWith(updatedAt: DateTime.now());
    _deletedModuleIds.remove(updated.id);
    _modules[index] = updated;
    _modules.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    _isLoading = false;
    _errorMessage = null;
    await LocalModuleStorage.saveModulesForCourse(courseId, _modules);
    notifyListeners();

    if (getIt.isRegistered<OngoingModulesController>()) {
      getIt<OngoingModulesController>().refresh();
    }

    try {
      await _firestoreService.updateModule(updated).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Firestore updateModule timed out, stored locally.');
        },
      );
    } catch (e) {
      debugPrint('Firestore updateModule error: $e');
    }
  }

  Future<void> deleteModule(String moduleId) async {
    _deletedModuleIds.add(moduleId);
    _modules.removeWhere((s) => s.id == moduleId);
    await LocalModuleStorage.saveModulesForCourse(courseId, _modules);
    notifyListeners();

    if (getIt.isRegistered<OngoingModulesController>()) {
      getIt<OngoingModulesController>().refresh();
    }
  }

  @override
  void dispose() {
    _loadingFallbackTimer?.cancel();
    _modulesSubscription?.cancel();
    super.dispose();
  }
}
