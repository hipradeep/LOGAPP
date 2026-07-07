import 'app_module.dart';

class ModuleRegistry {
  static final List<AppModule> _modules = [];

  static List<AppModule> get modules => List.unmodifiable(_modules);

  static Future<void> register(AppModule module) async {
    await module.initialize();
    _modules.add(module);
  }

  static Future<void> shutdown() async {
    for (var module in _modules) {
      await module.shutdown();
    }
    _modules.clear();
  }
}
