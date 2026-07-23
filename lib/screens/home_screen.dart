import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/todo.dart';
import '../services/todo_storage.dart';

enum TodoFilter { all, active, completed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = TodoStorage();
  final _uuid = const Uuid();

  List<Todo> _todos = [];
  TodoFilter _filter = TodoFilter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    final todos = await _storage.load();
    if (!mounted) return;
    setState(() {
      _todos = todos;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await _storage.save(_todos);
  }

  List<Todo> get _visibleTodos {
    final filtered = switch (_filter) {
      TodoFilter.active => _todos.where((t) => !t.isDone).toList(),
      TodoFilter.completed => _todos.where((t) => t.isDone).toList(),
      TodoFilter.all => List<Todo>.from(_todos),
    };
    // Sort: incomplete first, then higher priority first,
    // then most-recently-created first.
    filtered.sort((a, b) {
      final doneCmp = a.isDone ? 1 : 0;
      final otherDoneCmp = b.isDone ? 1 : 0;
      if (doneCmp != otherDoneCmp) {
        return doneCmp - otherDoneCmp;
      }
      final prioCmp = b.priority.weight.compareTo(a.priority.weight);
      if (prioCmp != 0) return prioCmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  int get _activeCount => _todos.where((t) => !t.isDone).length;
  int get _completedCount => _todos.where((t) => t.isDone).length;

  double get _progress {
    if (_todos.isEmpty) return 0;
    return _completedCount / _todos.length;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _todayLabel {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Future<void> _showTodoEditor({Todo? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    final isEditing = existing != null;
    var selectedPriority = existing?.priority ?? TodoPriority.medium;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 4,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.tertiary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isEditing
                                ? Icons.edit_rounded
                                : Icons.add_task_rounded,
                            color: colorScheme.onPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            isEditing ? 'Edit task' : 'New task',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Priority',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<TodoPriority>(
                      segments: [
                        ButtonSegment(
                          value: TodoPriority.low,
                          label: const Text('Low'),
                          icon: _PriorityDot(
                            priority: TodoPriority.low,
                            colorScheme: colorScheme,
                          ),
                        ),
                        ButtonSegment(
                          value: TodoPriority.medium,
                          label: const Text('Medium'),
                          icon: _PriorityDot(
                            priority: TodoPriority.medium,
                            colorScheme: colorScheme,
                          ),
                        ),
                        ButtonSegment(
                          value: TodoPriority.high,
                          label: const Text('High'),
                          icon: _PriorityDot(
                            priority: TodoPriority.high,
                            colorScheme: colorScheme,
                          ),
                        ),
                      ],
                      selected: {selectedPriority},
                      onSelectionChanged: (selection) {
                        setSheetState(() {
                          selectedPriority = selection.first;
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        selectedForegroundColor: colorScheme.onPrimary,
                        selectedBackgroundColor: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: titleController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Finish the report',
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: notesController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Optional details...',
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.of(context).pop(true);
                        }
                      },
                      icon: Icon(isEditing ? Icons.save_rounded : Icons.add_rounded),
                      label: Text(isEditing ? 'Save changes' : 'Add task'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true) return;

    final title = titleController.text.trim();
    final notes = notesController.text.trim();

    if (isEditing && existing != null) {
      setState(() {
        existing.title = title;
        existing.notes = notes;
        existing.priority = selectedPriority;
      });
      await _persist();
    } else {
      final newTodo = Todo(
        id: _uuid.v4(),
        title: title,
        notes: notes,
        priority: selectedPriority,
      );
      setState(() => _todos.insert(0, newTodo));
      await _persist();
    }
  }

  Future<void> _toggleDone(Todo todo) async {
    setState(() => todo.isDone = !todo.isDone);
    await _persist();
  }

  Future<void> _deleteTodo(Todo todo) async {
    final index = _todos.indexOf(todo);
    if (index < 0) return;

    final removed = todo;
    setState(() => _todos.removeAt(index));
    await _persist();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${removed.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() {
                _todos.insert(index.clamp(0, _todos.length), removed);
              });
              await _persist();
            },
          ),
        ),
      );
  }

  Future<void> _clearCompleted() async {
    final count = _completedCount;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear completed?'),
        content: Text('This will remove $count completed task${count == 1 ? '' : 's'}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final removed = _todos.where((t) => t.isDone).toList();
    setState(() => _todos.removeWhere((t) => t.isDone));
    await _persist();

    if (!mounted || removed.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Cleared ${removed.length} task${removed.length == 1 ? '' : 's'}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() => _todos.insertAll(0, removed));
              await _persist();
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _todayLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _greeting,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_todos.isNotEmpty) ...[
                      _ProgressCard(
                        progress: _progress,
                        activeCount: _activeCount,
                        total: _todos.length,
                        completed: _completedCount,
                      ),
                      const SizedBox(height: 18),
                    ],
                    _FilterBar(
                      filter: _filter,
                      onChanged: (f) => setState(() => _filter = f),
                      activeCount: _activeCount,
                      completedCount: _completedCount,
                      totalCount: _todos.length,
                      onClearCompleted: _clearCompleted,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _loading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _visibleTodos.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(filter: _filter),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final todo = _visibleTodos[index];
                            return _TodoTile(
                              key: ValueKey(todo.id),
                              todo: todo,
                              onToggle: () => _toggleDone(todo),
                              onTap: () => _showTodoEditor(existing: todo),
                              onDismissed: (_) => _deleteTodo(todo),
                            );
                          },
                          childCount: _visibleTodos.length,
                        ),
                      ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTodoEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add task'),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.activeCount,
    required this.total,
    required this.completed,
  });

  final double progress;
  final int activeCount;
  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final percent = (progress * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$activeCount active',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completed of $total done',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor:
                          colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                Text(
                  '$percent%',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.onChanged,
    required this.activeCount,
    required this.completedCount,
    required this.totalCount,
    required this.onClearCompleted,
  });

  final TodoFilter filter;
  final ValueChanged<TodoFilter> onChanged;
  final int activeCount;
  final int completedCount;
  final int totalCount;
  final VoidCallback onClearCompleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: SegmentedButton<TodoFilter>(
            segments: [
              ButtonSegment(
                value: TodoFilter.all,
                label: Text('All ($totalCount)'),
              ),
              ButtonSegment(
                value: TodoFilter.active,
                label: Text('Active ($activeCount)'),
              ),
              ButtonSegment(
                value: TodoFilter.completed,
                label: Text('Done ($completedCount)'),
              ),
            ],
            selected: {filter},
            onSelectionChanged: (s) => onChanged(s.first),
            style: SegmentedButton.styleFrom(
              selectedForegroundColor: colorScheme.onPrimary,
              selectedBackgroundColor: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: completedCount > 0 ? onClearCompleted : null,
          icon: const Icon(Icons.cleaning_services_rounded),
          tooltip: 'Clear completed',
        ),
      ],
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onTap,
    required this.onDismissed,
  });

  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final DismissDirectionCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Dismissible(
        key: ValueKey(todo.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
        ),
        onDismissed: onDismissed,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  _CheckCircle(isDone: todo.isDone, onTap: onToggle),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todo.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration:
                                todo.isDone ? TextDecoration.lineThrough : null,
                            color: todo.isDone
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface,
                          ),
                        ),
                        if (todo.notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            todo.notes,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              decoration: todo.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _PriorityBadge(priority: todo.priority),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final TodoPriority priority;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = priorityBadgeStyle(priority, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            priority.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Small colored dot used inside the priority segmented button.
class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority, required this.colorScheme});

  final TodoPriority priority;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final (color, _) = priorityBadgeStyle(priority, colorScheme);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

/// Returns a (color, icon) pair for a priority, using Material color schemes
/// that look good in both light and dark themes.
(Color, IconData) priorityBadgeStyle(
  TodoPriority priority,
  ColorScheme colorScheme,
) {
  switch (priority) {
    case TodoPriority.high:
      return (colorScheme.error, Icons.priority_high_rounded);
    case TodoPriority.medium:
      return (colorScheme.tertiary, Icons.drag_handle_rounded);
    case TodoPriority.low:
      return (colorScheme.primary, Icons.south_rounded);
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.isDone,
    required this.onTap,
  });

  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDone ? colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isDone
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.65),
            width: 2.2,
          ),
          boxShadow: isDone
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: isDone
            ? Icon(
                Icons.check_rounded,
                size: 17,
                color: colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final TodoFilter filter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, title, subtitle) = switch (filter) {
      TodoFilter.active => (
          Icons.inbox_outlined,
          'No active tasks',
          'Add a task or enjoy the quiet.',
        ),
      TodoFilter.completed => (
          Icons.check_circle_outline,
          'No completed tasks yet',
          'Check off a task to see it here.',
        ),
      TodoFilter.all => (
          Icons.playlist_add_check_circle_outlined,
          'No tasks yet',
          'Tap Add task to get started.',
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.tertiaryContainer,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 48,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
