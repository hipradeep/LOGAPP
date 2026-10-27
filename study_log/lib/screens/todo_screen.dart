import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/tab_header.dart';
import '../widgets/todo_group_header.dart';
import '../widgets/todo_list_item.dart';
import '../widgets/todo_options_sheet.dart';
import '../models/todo_item.dart';
import '../controllers/todo_controller.dart';
import '../services/service_locator.dart';
import 'todo_detail_edit_screen.dart';
import 'session_timer_screen.dart';

/// TODO Tab screen displaying categorized, collapsible task groups
/// (Due Today, Upcoming, Finished, Archived) with compact item rows.
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with AutomaticKeepAliveClientMixin {
  late final TodoController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = getIt<TodoController>();
  }

  void _openAddTask() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TodoDetailEditScreen(),
      ),
    );
  }

  void _openEditTask(TodoItem todo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TodoDetailEditScreen(todo: todo),
      ),
    );
  }

  void _openPomodoro(TodoItem todo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionTimerScreen(
          title: 'Task: ${todo.title}',
          subtitle: 'Pomodoro Focus Session',
          durationMinutes: 25,
        ),
      ),
    );
  }

  void _showOptions(TodoItem todo) {
    HapticFeedback.mediumImpact();
    TodoOptionsSheet.show(
      context,
      todo: todo,
      onEdit: () => _openEditTask(todo),
      onPomodoro: () => _openPomodoro(todo),
      onToggleArchive: () {
        if (todo.isArchived) {
          _controller.unarchiveTodo(todo.id);
        } else {
          _controller.archiveTodo(todo.id);
        }
      },
      onDelete: () => _controller.deleteTodo(todo.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      floatingActionButton: AppFab(
        onPressed: _openAddTask,
        tooltip: 'Add Task',
        icon: Icons.add_rounded,
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final dueToday = _controller.dueTodayTodos;
            final upcoming = _controller.upcomingTodos;
            final finished = _controller.finishedTodos;
            final archived = _controller.archivedTodos;
            final totalCount = _controller.allTodos.length;

            final subtitle = '${dueToday.length} due today • ${finished.length} finished';

            return Column(
              children: [
                TabHeader(
                  title: '#TODO',
                  subtitle: subtitle,
                ),
                Expanded(
                child: RefreshIndicator(
                  onRefresh: _controller.refresh,
                  color: AppTheme.primaryColor,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      if (totalCount == 0 && !_controller.isLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: AppEmptyState(
                              icon: Icons.task_alt_rounded,
                              title: 'No Tasks Yet',
                              description: 'Tap "+ Add Task" to capture your study todos, deadlines, and checklists.',
                            ),
                          ),
                        )
                      else ...[
                  // 1. Due Today Group (Includes Overdue)
                  if (dueToday.isNotEmpty)
                    _TodoGroupSliver(
                      groupKey: 'due_today',
                      title: 'Due Today',
                      count: dueToday.length,
                      todos: dueToday,
                      badgeColor: AppTheme.pastelCoral(context),
                      badgeTextColor: AppTheme.pastelCoralText(context),
                      controller: _controller,
                      onTapItem: _openEditTask,
                      onLongPressItem: _showOptions,
                    ),

                  // 2. Upcoming Group
                  if (upcoming.isNotEmpty)
                    _TodoGroupSliver(
                      groupKey: 'upcoming',
                      title: 'Upcoming',
                      count: upcoming.length,
                      todos: upcoming,
                      badgeColor: AppTheme.pastelBlue(context),
                      badgeTextColor: AppTheme.pastelBlueText(context),
                      controller: _controller,
                      onTapItem: _openEditTask,
                      onLongPressItem: _showOptions,
                    ),

                  // 3. Finished Group
                  if (finished.isNotEmpty)
                    _TodoGroupSliver(
                      groupKey: 'finished',
                      title: 'Finished',
                      count: finished.length,
                      todos: finished,
                      badgeColor: AppTheme.pastelGreen(context),
                      badgeTextColor: AppTheme.pastelGreenText(context),
                      controller: _controller,
                      onTapItem: _openEditTask,
                      onLongPressItem: _showOptions,
                    ),

                  // 4. Archive Group
                  if (archived.isNotEmpty)
                    _TodoGroupSliver(
                      groupKey: 'archive',
                      title: 'Archive',
                      count: archived.length,
                      todos: archived,
                      badgeColor: AppTheme.surfaceVariant(context),
                      badgeTextColor: AppTheme.textSecondaryColor(context),
                      controller: _controller,
                      onTapItem: _openEditTask,
                      onLongPressItem: _showOptions,
                    ),

                  // Bottom padding for FAB and BNV
                  SliverToBoxAdapter(
                    child: SizedBox(height: bottomSafe + 96),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
            );
          },
        ),
      ),
    );
  }
}

/// Sliver representation of a collapsible Todo Category
class _TodoGroupSliver extends StatelessWidget {
  final String groupKey;
  final String title;
  final int count;
  final List<TodoItem> todos;
  final Color badgeColor;
  final Color badgeTextColor;
  final TodoController controller;
  final ValueChanged<TodoItem> onTapItem;
  final ValueChanged<TodoItem> onLongPressItem;

  const _TodoGroupSliver({
    required this.groupKey,
    required this.title,
    required this.count,
    required this.todos,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.controller,
    required this.onTapItem,
    required this.onLongPressItem,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.collapsedGroupsNotifier,
      builder: (context, _) {
        final isCollapsed = controller.isGroupCollapsed(groupKey);

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: TodoGroupHeader(
                title: title,
                count: count,
                isCollapsed: isCollapsed,
                onTap: () => controller.toggleGroupCollapse(groupKey),
                countBadgeColor: badgeColor,
                countTextColor: badgeTextColor,
              ),
            ),
            if (!isCollapsed)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = todos[index];
                      return TodoListItem(
                        key: ValueKey(item.id),
                        todo: item,
                        margin: const EdgeInsets.only(bottom: 5),
                        onTap: () => onTapItem(item),
                        onCheckboxTap: () => controller.toggleTodoStatus(item.id),
                        onLongPress: () => onLongPressItem(item),
                      );
                    },
                    childCount: todos.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: VGapSm(),
            ),
          ],
        );
      },
    );
  }
}
