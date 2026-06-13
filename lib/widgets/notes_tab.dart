import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/note_entity.dart';
import '../controllers/note_controller.dart';
import '../screens/note_write_screen.dart';
import '../services/cache_service.dart';
import 'app_spacers.dart';
import 'base_management_tab.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  late final NoteController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _controller = NoteController();
    _scrollController.addListener(_onScroll);
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

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return BaseManagementTab<NoteController>(
      controller: _controller,
      isLoading: (ctrl) => ctrl.isLoading,
      errorMessage: (ctrl) => ctrl.errorMessage,
      isEmpty: (ctrl) => ctrl.notes.isEmpty,
      emptyIcon: Icons.menu_book,
      emptyMessage: 'No notes Yet',
      onRefresh: () async => await _controller.refresh(),
      onFabPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NoteWriteScreen(),
          ),
        );
        if (result != null && result is Map<String, dynamic>) {
          try {
            await _controller.createEntry(
              result['title'],
              result['content'],
              result['mood'],
              List<String>.from(result['tags']),
            );
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save note: $e')),
              );
            }
          }
        }
      },
      builder: (context, controller) {
        final groupedJournals = controller.groupedJournals;

    return Column(
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
              Row(
                children: [
                  Icon(Icons.arrow_downward, size: 16, color: AppTheme.textSecondary),
                  const HGapSm(),
                  Text(
                    'Last modified',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () async {
                  final newState = !_isGridView;
                  setState(() {
                    _isGridView = newState;
                  });
                  await CacheService().saveNotesGridView(newState);
                },
                icon: Icon(
                  _isGridView ? Icons.view_agenda_outlined : Icons.grid_view_outlined,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 100), // padding for FAB
            physics: const BouncingScrollPhysics(),
            itemCount: groupedJournals.length + (controller.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == groupedJournals.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                );
              }

              final label = groupedJournals.keys.elementAt(index);
              final entries = groupedJournals[label]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      label.toUpperCase(),
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _buildListOrGrid(context, entries, controller),
                ],
              );
            },
          ),
        ),
      ],
    );
  },
);
}

  static const List<Color> _noteColors = [
    Color(0xFFD0E8FF), // Light Blue
    Color(0xFFFFF4CC), // Light Yellow
    Color(0xFFD9F4D9), // Light Green
    Color(0xFFFFD6E0), // Light Pink
    Color(0xFFEADBFF), // Light Purple
  ];

  Widget _buildListOrGrid(BuildContext context, List<NoteEntity> entries, NoteController controller) {
    if (entries.isEmpty) return const SizedBox.shrink();

    if (!_isGridView) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(entries.length, (i) {
          return _buildJournalCard(context, entries[i], controller, i);
        }),
      );
    }

    if (entries.length == 1) {
      return _buildJournalCard(context, entries.first, controller, 0);
    }

    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];

    for (int i = 0; i < entries.length; i++) {
      final card = _buildJournalCard(context, entries[i], controller, i);
      if (i % 2 == 0) {
        leftColumn.add(card);
      } else {
        rightColumn.add(card);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: leftColumn)),
        const HGapMd(),
        Expanded(child: Column(children: rightColumn)),
      ],
    );
  }

  Widget _buildJournalCard(BuildContext context, NoteEntity entry, NoteController controller, int index) {
    final bgColor = _noteColors[index % _noteColors.length];

    return Container(
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
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NoteWriteScreen(existingEntry: entry),
              ),
            );
            if (result != null && result is Map<String, dynamic>) {
              try {
                await controller.updateEntry(
                  entry.id,
                  result['title'],
                  result['content'],
                  result['mood'],
                  List<String>.from(result['tags']),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update note: $e')),
                  );
                }
              }
            }
          },
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

                  ],
                ),
                const VGapXs(),
                Text(
                  entry.content,
                  style: AppTheme.bodySmall.copyWith(
                    color: const Color(0xFF4A4A4A),
                    height: 1.4,
                  ),
                ),
                const VGapMd(),
                Text(
                  DateFormat('MMM d, yyyy').format(entry.timestamp),
                  style: AppTheme.bodyMicro.copyWith(
                    color: const Color(0xFF7A7A7A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Tags
                if (entry.tags.isNotEmpty) ...[
                  const VGapSm(),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: entry.tags.map((tag) {
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
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
