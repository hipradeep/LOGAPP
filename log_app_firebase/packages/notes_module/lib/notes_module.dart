
import 'package:flutter/material.dart';
import 'package:core_services/core_services.dart';
import 'package:get_it/get_it.dart';
import 'src/controllers/note_controller.dart';
import 'src/services/note_service.dart';
import 'src/screens/notes_screen.dart';

export 'src/models/note_entity.dart';
export 'src/services/note_service.dart';
export 'src/controllers/note_controller.dart';
export 'src/screens/notes_screen.dart';
export 'src/screens/note_write_screen.dart';
export 'src/widgets/note_options_sheet.dart';

class NotesModule implements AppModule {
  @override
  String get id => 'notes';

  @override
  String get name => 'Journal & Notes';

  @override
  String get description => 'Daily logs and notes tracking';

  @override
  bool get isPremium => false;

  @override
  Future<void> initialize() async {
    GetIt.instance.registerLazySingleton(() => NoteService());
    GetIt.instance.registerLazySingleton(() => NoteController());
    // Register NoteService as the JournalLogger so other modules (e.g. pomodoro) can log entries
    GetIt.instance.registerLazySingleton<JournalLogger>(() => GetIt.instance<NoteService>());
  }

  @override
  Future<void> shutdown() async {
    GetIt.instance.unregister<NoteController>();
    GetIt.instance.unregister<NoteService>();
  }

  @override
  Widget buildDashboardWidget(BuildContext context) {
    return const SizedBox.shrink();
  }

  @override
  List<NavigationItem> getNavigationItems(BuildContext context) {
    return [
      NavigationItem(
        icon: Icons.book,
        label: 'Notes',
        route: '/notes',
        builder: (context) => const NotesScreen(),
      ),
    ];
  }
}
