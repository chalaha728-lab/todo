import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:codesage_app/main.dart';
import 'package:codesage_app/models/todo.dart';
import 'package:codesage_app/services/todo_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Todo model', () {
    test('defaults to medium priority', () {
      final todo = Todo(id: 'a', title: 'Task');
      expect(todo.priority, TodoPriority.medium);
    });

    test('toJson/fromJson round-trips priority', () {
      final todo = Todo(
        id: 'a',
        title: 'Task',
        priority: TodoPriority.high,
      );
      final restored = Todo.fromJson(todo.toJson());
      expect(restored.priority, TodoPriority.high);
    });

    test('fromJson falls back to medium for unknown priority', () {
      final restored = Todo.fromJson({
        'id': 'a',
        'title': 'Task',
        'notes': '',
        'isDone': false,
        'priority': 'nope',
        'createdAt': DateTime(2024, 1, 1).toIso8601String(),
      });
      expect(restored.priority, TodoPriority.medium);
    });

    test('fromJson is backward compatible without priority', () {
      final restored = Todo.fromJson({
        'id': 'a',
        'title': 'Task',
        'notes': '',
        'isDone': false,
        'createdAt': DateTime(2024, 1, 1).toIso8601String(),
      });
      expect(restored.priority, TodoPriority.medium);
    });

    test('priority weight orders high before medium before low', () {
      expect(TodoPriority.high.weight, greaterThan(TodoPriority.medium.weight));
      expect(TodoPriority.medium.weight, greaterThan(TodoPriority.low.weight));
    });

    test('copyWith updates priority', () {
      final todo = Todo(id: 'a', title: 'Task');
      final updated = todo.copyWith(priority: TodoPriority.high);
      expect(updated.priority, TodoPriority.high);
      expect(updated.title, 'Task');
    });
  });

  group('TodoStorage', () {
    test('persists priority across save/load', () async {
      final storage = TodoStorage();
      final todos = [
        Todo(id: '1', title: 'Low task', priority: TodoPriority.low),
        Todo(id: '2', title: 'High task', priority: TodoPriority.high),
      ];
      await storage.save(todos);
      final loaded = await storage.load();
      expect(loaded.length, 2);
      expect(loaded.first.id, '1');
      expect(loaded.first.priority, TodoPriority.low);
      expect(loaded.last.priority, TodoPriority.high);
    });

    test('loads legacy entries without priority as medium', () async {
      // Simulate a legacy JSON blob that predates the priority field.
      const legacyJson =
          '[{"id":"x","title":"Old","notes":"","isDone":false,"createdAt":"2024-01-01T00:00:00.000"}]';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('todos', legacyJson);

      final loaded = await TodoStorage().load();
      expect(loaded.length, 1);
      expect(loaded.first.priority, TodoPriority.medium);
    });
  });

  testWidgets('App shows todo home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    expect(find.text('Add task'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('Can add a new task with a priority', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add task'));
    await tester.pumpAndSettle();

    // Priority picker is visible by default.
    expect(find.text('Priority'), findsOneWidget);

    // Select "High" priority.
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Buy groceries');
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(find.text('Buy groceries'), findsOneWidget);
    // The High priority badge should now be visible on the created task.
    expect(find.text('High'), findsOneWidget);
    // Progress card shows "1 active" and "1 of 1 done".
    expect(find.text('1 active'), findsOneWidget);
    expect(find.text('1 of 1 done'), findsOneWidget);
  });
}
