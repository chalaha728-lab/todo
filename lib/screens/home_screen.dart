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
    switch (_filter) {
      case TodoFilter.active:
        return _todos.where((t) => !t.isDone).toList();
      case TodoFilter.completed:
        return _todos.where((t) => t.isDone).toList();
      case TodoFilter.all:
        return List<Todo>.from(_todos);
    }
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

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit task' : 'New task',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            isEditing
                                ? 'Update the details below'
                                : 'What would you like to do?',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Buy groceries',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: notesController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Add a little detail…',
                    prefixIcon: Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) return;
                    Navigator.of(context).pop(true);
                  },
                  icon: Icon(
                    isEditing ? Icons.check_rounded : Icons.add_rounded,
                  ),
                  label: Text(isEditing ? 'Save changes' : 'Add task'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    final title = titleController.text.trim();
    final notes = notesController.text.trim();
    titleController.dispose();
    notesController.dispose();

    if (result != true || !mounted) return;

    setState(() {
      if (isEditing) {
        final index = _todos.indexWhere((t) => t.id == existing.id);
        if (index != -1) {
          _todos[index] = existing.copyWith(title: title, notes: notes);
        }
      } else {
        _todos.insert(
          0,
          Todo(
            id: _uuid.v4(),
            title: title,
            notes: notes,
          ),
        );
      }
    });
    await _persist();
  }

  Future<void> _toggleDone(Todo todo) async {
    setState(() {
      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index != -1) {
        _todos[index] = todo.copyWith(isDone: !todo.isDone);
      }
    });
    await _persist();
  }

  Future<void> _deleteTodo(Todo todo) async {
    final index = _todos.indexWhere((t) => t.id == todo.id);
    if (index == -1) return;

    setState(() => _todos.removeAt(index));
    await _persist();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${todo.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() => _todos.insert(index.clamp(0, _todos.length), todo));
            await _persist();
          },
        ),
      ),
    );
  }

  Future<void> _clearCompleted() async {
    final removed = _todos.where((t) => t.isDone).toList();
    if (removed.isEmpty) return;

    setState(() => _todos.removeWhere((t) => t.isDone));
    await _persist();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cleared ${removed.length} completed task(s)'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() => _todos.addAll(removed));
            await _persist();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visible = _visibleTodos;

    return Scaffold(
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading tasks…',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeroHeader(colorScheme)),
                  if (_todos.isNotEmpty)
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  if (_todos.isNotEmpty)
                    SliverToBoxAdapter(child: _buildFilterBar(colorScheme)),
                  if (_completedCount > 0 && _filter != TodoFilter.active)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _clearCompleted,
                            icon: const Icon(Icons.cleaning_services_outlined,
                                size: 18),
                            label: const Text('Clear completed'),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.error,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(filter: _filter),
                    )
                  else
                    ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 4,
                              bottom: 10,
                              top: 4,
                            ),
                            child: Text(
                              _filterLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        sliver: SliverList.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final todo = visible[index];
                            return _TodoCard(
                              todo: todo,
                              onToggle: () => _toggleDone(todo),
                              onEdit: () => _showTodoEditor(existing: todo),
                              onDelete: () => _deleteTodo(todo),
                            );
                          },
                        ),
                      ),
                    ],
                ],
              ),
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showTodoEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add task'),
            ),
    );
  }

  String get _filterLabel {
    switch (_filter) {
      case TodoFilter.all:
        return 'ALL TASKS · ${_todos.length}';
      case TodoFilter.active:
        return 'ACTIVE · $_activeCount';
      case TodoFilter.completed:
        return 'COMPLETED · $_completedCount';
    }
  }

  Widget _buildHeroHeader(ColorScheme colorScheme) {
    final percent = (_progress * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.55)!,
            colorScheme.tertiary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _todayLabel,
                      style: TextStyle(
                        color: colorScheme.onPrimary.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _greeting,
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _todos.isEmpty
                          ? 'Ready when you are'
                          : _activeCount == 0
                              ? 'All caught up — nice work!'
                              : '$_activeCount task${_activeCount == 1 ? '' : 's'} left today',
                      style: TextStyle(
                        color: colorScheme.onPrimary.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressRing(
                progress: _progress,
                label: _todos.isEmpty ? '—' : '$percent%',
                color: colorScheme.onPrimary,
              ),
            ],
          ),
          if (_todos.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    icon: Icons.pending_actions_rounded,
                    label: 'Active',
                    value: '$_activeCount',
                    onPrimary: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatPill(
                    icon: Icons.task_alt_rounded,
                    label: 'Done',
                    value: '$_completedCount',
                    onPrimary: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatPill(
                    icon: Icons.list_alt_rounded,
                    label: 'Total',
                    value: '${_todos.length}',
                    onPrimary: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              selected: _filter == TodoFilter.all,
              onTap: () => setState(() => _filter = TodoFilter.all),
            ),
            _FilterChip(
              label: 'Active',
              selected: _filter == TodoFilter.active,
              onTap: () => setState(() => _filter = TodoFilter.active),
            ),
            _FilterChip(
              label: 'Done',
              selected: _filter == TodoFilter.completed,
              onTap: () => setState(() => _filter = TodoFilter.completed),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.label,
    required this.color,
  });

  final double progress;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 6,
              backgroundColor: color.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPrimary,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onPrimary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: onPrimary.withValues(alpha: 0.95)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: onPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: onPrimary.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Material(
        color: isDark ? const Color(0xFF152033) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: todo.isDone
                    ? colorScheme.primary.withValues(alpha: 0.25)
                    : colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: todo.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.35,
                                decoration: todo.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
