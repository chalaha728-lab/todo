import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:codesage_app/main.dart';
import 'package:codesage_app/models/todo.dart';

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

  testWidgets('App shows todo home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pumpAndSettle();

    expect(find.text('My Todos'), findsOneWidget);
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
    await tester.tap(find.widgetWithText(SegmentButton, 'High'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Buy groceries');
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(find.text('Buy groceries'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('1 active task'), findsOneWidget);
  });
}
