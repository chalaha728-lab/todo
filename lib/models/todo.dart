enum TodoPriority { low, medium, high }

extension TodoPriorityX on TodoPriority {
  String get label {
    switch (this) {
      case TodoPriority.low:
        return 'Low';
      case TodoPriority.medium:
        return 'Medium';
      case TodoPriority.high:
        return 'High';
    }
  }

  /// Sort weight: higher priority sorts first.
  int get weight {
    switch (this) {
      case TodoPriority.low:
        return 0;
      case TodoPriority.medium:
        return 1;
      case TodoPriority.high:
        return 2;
    }
  }

  String get jsonValue => name;
}

TodoPriority _priorityFromJson(dynamic value) {
  if (value is String) {
    return TodoPriority.values.firstWhere(
      (p) => p.name == value,
      orElse: () => TodoPriority.medium,
    );
  }
  if (value is int) {
    return TodoPriority.values.firstWhere(
      (p) => p.index == value,
      orElse: () => TodoPriority.medium,
    );
  }
  return TodoPriority.medium;
}

class Todo {
  Todo({
    required this.id,
    required this.title,
    this.notes = '',
    this.isDone = false,
    this.priority = TodoPriority.medium,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  String notes;
  bool isDone;
  TodoPriority priority;
  final DateTime createdAt;

  Todo copyWith({
    String? title,
    String? notes,
    bool? isDone,
    TodoPriority? priority,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'isDone': isDone,
        'priority': priority.jsonValue,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: (json['notes'] as String?) ?? '',
      isDone: (json['isDone'] as bool?) ?? false,
      priority: _priorityFromJson(json['priority']),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
