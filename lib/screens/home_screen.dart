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
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? 'Edit task' : 'New task',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'What needs to be done?',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context, true);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context, true);
                    }
                  },
                  icon: Icon(isEditing ? Icons.save_outlined : Icons.add),
                  label: Text(isEditing ? 'Save' : 'Add task'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != true) {
      titleController.dispose();
      notesController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final notes = notesController.text.trim();
    titleController.dispose();
    notesController.dispose();

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
    setState(() {
      _todos.removeWhere((t) => t.id == todo.id);
    });
    await _persist();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${todo.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() => _todos.add(todo));
            _todos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            await _persist();
          },
        ),
      ),
    );
  }

  Future<void> _clearCompleted() async {
    final removed = _todos.where((t) => t.isDone).toList();
    if (removed.isEmpty) return;

    setState(() {
      _todos.removeWhere((t) => t.isDone);
    });
    await _persist();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cleared ${removed.length} completed task${removed.length == 1 ? '' : 's'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visible = _visibleTodos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Todos'),
        actions: [
          if (_completedCount > 0)
            IconButton(
              tooltip: 'Clear completed',
              onPressed: _clearCompleted,
              icon: const Icon(Icons.cleaning_services_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Card(
                    elevation: 0,
                    color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            child: Text('$_activeCount'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _activeCount == 0
                                      ? 'All caught up!'
                                      : '$_activeCount active task${_activeCount == 1 ? '' : 's'}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  '$_completedCount completed · ${_todos.length} total',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SegmentedButton<TodoFilter>(
                    segments: const [
                      ButtonSegment(
                        value: TodoFilter.all,
                        label: Text('All'),
                        icon: Icon(Icons.list_alt),
                      ),
                      ButtonSegment(
                        value: TodoFilter.active,
                        label: Text('Active'),
                        icon: Icon(Icons.radio_button_unchecked),
                      ),
                      ButtonSegment(
                        value: TodoFilter.completed,
                        label: Text('Done'),
                        icon: Icon(Icons.check_circle_outline),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (selection) {
                      setState(() => _filter = selection.first);
                    },
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? _EmptyState(filter: _filter)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final todo = visible[index];
                            return _TodoTile(
                              todo: todo,
                              onToggle: () => _toggleDone(todo),
                              onEdit: () => _showTodoEditor(existing: todo),
                              onDelete: () => _deleteTodo(todo),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTodoEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
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
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Checkbox(
            value: todo.isDone,
            onChanged: (_) => onToggle(),
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              decoration: todo.isDone ? TextDecoration.lineThrough : null,
              color: todo.isDone
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.55)
                  : null,
            ),
          ),
          subtitle: todo.notes.isEmpty
              ? null
              : Text(
                  todo.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    decoration:
                        todo.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
          trailing: IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          onTap: onToggle,
          onLongPress: onEdit,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final TodoFilter filter;

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
