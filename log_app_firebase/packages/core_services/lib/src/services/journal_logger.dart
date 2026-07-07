/// Abstract interface for logging journal entries.
/// Implemented by NoteService in notes_module.
/// Allows pomodoro_module to decouple from notes_module.
abstract class JournalLogger {
  Future<void> createEntry({
    required String title,
    required String body,
    String? category,
    Map<String, dynamic>? metadata,
  });
}
