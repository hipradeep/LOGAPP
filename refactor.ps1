Move-Item lib/models/journal_entry.dart lib/models/note_entity.dart
Move-Item lib/services/journal_service.dart lib/services/note_service.dart
Move-Item lib/controllers/journal_controller.dart lib/controllers/note_controller.dart
Move-Item lib/widgets/journal_tab.dart lib/widgets/notes_tab.dart
Move-Item lib/screens/journal_write_screen.dart lib/screens/note_write_screen.dart
Move-Item lib/widgets/journal_options_sheet.dart lib/widgets/note_options_sheet.dart
Move-Item lib/screens/logs_screen.dart lib/screens/notes_screen.dart

Get-ChildItem -Path lib -Recurse -Filter *.dart | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace 'JournalEntry', 'NoteEntity'
    $content = $content -replace 'journal_entry\.dart', 'note_entity.dart'
    $content = $content -replace 'JournalService', 'NoteService'
    $content = $content -replace 'journal_service\.dart', 'note_service.dart'
    $content = $content -replace 'JournalController', 'NoteController'
    $content = $content -replace 'journal_controller\.dart', 'note_controller.dart'
    $content = $content -replace 'JournalTab', 'NotesTab'
    $content = $content -replace 'journal_tab\.dart', 'notes_tab.dart'
    $content = $content -replace 'JournalWriteScreen', 'NoteWriteScreen'
    $content = $content -replace 'journal_write_screen\.dart', 'note_write_screen.dart'
    $content = $content -replace 'JournalOptionsSheet', 'NoteOptionsSheet'
    $content = $content -replace 'journal_options_sheet\.dart', 'note_options_sheet.dart'
    
    $content = $content -replace 'LogsScreen', 'NotesScreen'
    $content = $content -replace 'logs_screen\.dart', 'notes_screen.dart'
    $content = $content -replace '_logsStream', '_notesStream'
    $content = $content -replace '_logService', '_noteService'

    $content = $content -replace '_journalService', '_noteService'
    $content = $content -replace '_journals', '_notes'
    $content = $content -replace '\bjournals\b', 'notes'
    $content = $content -replace '\bjournal\b', 'note'
    $content = $content -replace 'journalSub', 'noteSub'
    $content = $content -replace 'getLogsStream', 'getNotesStream'
    $content = $content -replace "collection\('logs'\)", "collection('notes')"

    Set-Content -Path $_.FullName -Value $content -NoNewline
}
