import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_services/core_services.dart';
import '../models/note_entity.dart';
import '../controllers/note_controller.dart';
import 'note_write_screen.dart';
import '../widgets/grid_toggle_button.dart';
import '../widgets/note_options_sheet.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final NoteController _controller;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _controller = NoteController();
    _loadGridState();
  }

  Future<void> _loadGridState() async {
    final isGrid = await CacheService().getNotesGridView();
    if (mounted) {
      setState(() {
        _isGridView = isGrid;
      });
    }
  }

  Future<void> _toggleGridView() async {
    final newState = !_isGridView;
    setState(() {
      _isGridView = newState;
    });
    await CacheService().saveNotesGridView(newState);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppProvider<NoteController>(
      notifier: _controller,
      child: Stack(
        children: [
          Positioned.fill(
            child: FullScreenPage(
              showScaffold: false,
              isScrollable: false,
              title: 'Notes',
              padding: EdgeInsets.zero,
              actions: [
                GridToggleButton(
                  isGridView: _isGridView,
                  onTap: _toggleGridView,
                ),
              ],
              backgroundWidgets: [
                GlowBlob(
                  top: -40,
                  left: -40,
                  size: 220,
                  color: AppTheme.primaryColor,
                  opacity: 0.08,
                ),
                GlowBlob(
                  bottom: -50,
                  right: -50,
                  size: 260,
                  color: AppTheme.secondaryColor,
                  opacity: 0.05,
                ),
              ],
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => _buildBody(context),
                  ),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final hasNotes = _controller.notes.isNotEmpty;
              if (hasNotes && !_controller.isLoading && _controller.errorMessage == null) {
                return AppPremiumFab(
                  right: 24,
                  onPressed: _onFabPressed,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  void _onFabPressed() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NoteWriteScreen(),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_controller.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Text(
            'Failed to load data:\n${_controller.errorMessage}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
      );
    }

    if (_controller.notes.isEmpty) {
      return AppEmptyState(
        icon: Icons.menu_book_rounded,
        title: 'No Notes Recorded',
        description: 'Capture thoughts, log journals, or document your progress.',
        actionLabel: 'Write a Note',
        onActionPressed: _onFabPressed,
      );
    }

    final pinnedNotes = _controller.pinnedNotes;
    final groupedJournals = _controller.groupedJournals;

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          _controller.loadMore();
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.only(left: 24, right: 24, top: 0, bottom: 100),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          // ── PINNED SECTION ──────────────────────────────────────────
          if (pinnedNotes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.push_pin_rounded, size: 13, color: AppTheme.primaryColor),
                  const HGapSm(),
                  Text(
                    'PINNED',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            _buildListOrGrid(context, pinnedNotes, _controller),
          ],
          // ── DATE-GROUPED UNPINNED SECTIONS ───────────────────────────
          ...groupedJournals.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryAccentColor(context),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                _buildListOrGrid(context, entry.value, _controller),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildListOrGrid(BuildContext context, List<NoteEntity> entries, NoteController controller) {
    if (entries.isEmpty) return const SizedBox.shrink();

    if (!_isGridView) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(entries.length, (i) {
          return _NoteCard(
            entry: entries[i],
            controller: controller,
            index: i,
          );
        }),
      );
    }

    final gridItems = <Widget>[];
    List<NoteEntity> currentNormalRowEntries = [];

    void flushNormalRow() {
      if (currentNormalRowEntries.isEmpty) return;

      if (currentNormalRowEntries.length == 1) {
        gridItems.add(
          _NoteCard(
            entry: currentNormalRowEntries.first,
            controller: controller,
            index: entries.indexOf(currentNormalRowEntries.first),
          ),
        );
      } else {
        final leftColumn = <Widget>[];
        final rightColumn = <Widget>[];
        for (int i = 0; i < currentNormalRowEntries.length; i++) {
          final entry = currentNormalRowEntries[i];
          final idx = entries.indexOf(entry);
          final card = _NoteCard(
            entry: entry,
            controller: controller,
            index: idx,
          );
          if (i % 2 == 0) {
            leftColumn.add(card);
          } else {
            rightColumn.add(card);
          }
        }
        gridItems.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: leftColumn)),
              const HGapMd(),
              Expanded(child: Column(children: rightColumn)),
            ],
          ),
        );
      }
      currentNormalRowEntries = [];
    }

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final wordCount = RegExp(r'\S+').allMatches(entry.content).length;
      final isFullWidth = wordCount > 25;

      if (isFullWidth) {
        flushNormalRow();
        gridItems.add(
          _NoteCard(
            entry: entry,
            controller: controller,
            index: i,
          ),
        );
      } else {
        currentNormalRowEntries.add(entry);
      }
    }

    flushNormalRow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(gridItems.length, (index) {
        final item = gridItems[index];
        if (item is Row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: item,
          );
        }
        return item;
      }),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteEntity entry;
  final NoteController controller;
  final int index;

  _NoteCard({
    required this.entry,
    required this.controller,
    required this.index,
  }) : super(key: ValueKey(entry.id));

  static final DateFormat _cardDateFormat = DateFormat('MMM d, yyyy');

  String _getDisplayContent(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final matches = RegExp(r'\S+').allMatches(text);
    if (matches.length > 40) {
      final match = matches.elementAt(39);
      return '${text.substring(0, match.end).trimRight()}...';
    }
    return text;
  }

  static const List<Color> _noteColors = [
    Color(0xFFD0E8FF), // Light Blue
    Color(0xFFFFF4CC), // Light Yellow
    Color(0xFFD9F4D9), // Light Green
    Color(0xFFFFD6E0), // Light Pink
    Color(0xFFEADBFF), // Light Purple
  ];

  static const Map<String, String> _moodLabels = {
    '': 'Note',
    '😊': 'Happy',
    '🚀': 'Productive',
    '🌌': 'Peaceful',
    '😔': 'Sad',
    '🔥': 'Energized',
    '💤': 'Tired',
    '🎉': 'Excited',
    '🧠': 'Focused',
    '🌳': 'Grateful',
    '❤️': 'Loved',
  };

  @override
  Widget build(BuildContext context) {
    final bgColor = _noteColors[index % _noteColors.length];

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.backgroundColor.withValues(alpha: 0.05)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            onTap: () => _handleTap(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      // Pin badge
                      if (entry.isPinned) ...[
                        const HGapSm(),
                        const Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: Color(0xFF555555),
                        ),
                      ],
                    ],
                  ),
                  const VGapXs(),
                  Text(
                    _getDisplayContent(entry.content),
                    style: AppTheme.bodySmall.copyWith(
                      color: const Color(0xFF4A4A4A),
                      height: 1.4,
                    ),
                  ),
                  const VGapMd(),
                  Text(
                    _cardDateFormat.format(entry.timestamp),
                    style: AppTheme.bodyMicro.copyWith(
                      color: const Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const VGapSm(),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // Mood tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.mood.isNotEmpty ? entry.mood : '📝'} ${_moodLabels[entry.mood] ?? 'Note'}',
                          style: AppTheme.bodyMicro.copyWith(
                            color: const Color(0xFF4A4A4A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Other tags
                      ...entry.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: AppTheme.bodyMicro.copyWith(
                            color: const Color(0xFF4A4A4A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NoteOptionsSheet(
        entry: entry,
        onDelete: () => _handleDelete(context),
        onPinToggle: () => _handlePinToggle(context),
      ),
    );
  }

  void _handlePinToggle(BuildContext context) async {
    try {
      await controller.togglePin(entry.id, !entry.isPinned);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update pin: $e')),
        );
      }
    }
  }

  void _handleDelete(BuildContext context) async {
    try {
      await controller.deleteEntry(entry.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete note: $e')),
        );
      }
    }
  }

  void _handleTap(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteWriteScreen(existingEntry: entry),
      ),
    );
  }
}
