enum TodoStatus { pending, in_progress, completed, cancelled }

enum TodoPriority { low, medium, high }

class Todo {
  final String id;
  final String content;
  final TodoStatus status;
  final TodoPriority priority;
  final DateTime createdAt;

  Todo({
    String? id,
    required this.content,
    this.status = TodoStatus.pending,
    this.priority = TodoPriority.medium,
    DateTime? createdAt,
  })  : id = id ?? '',
        createdAt = createdAt ?? DateTime.now();

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      status: _parseStatus(json['status'] as String?),
      priority: _parsePriority(json['priority'] as String?),
      createdAt: json['time'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['time'] as num).toInt())
          : null,
    );
  }

  static TodoStatus _parseStatus(String? status) {
    return switch (status) {
      'pending' => TodoStatus.pending,
      'in_progress' => TodoStatus.in_progress,
      'completed' => TodoStatus.completed,
      'cancelled' => TodoStatus.cancelled,
      _ => TodoStatus.pending,
    };
  }

  static TodoPriority _parsePriority(String? priority) {
    return switch (priority) {
      'low' => TodoPriority.low,
      'medium' => TodoPriority.medium,
      'high' => TodoPriority.high,
      _ => TodoPriority.medium,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'status': status.name,
      'priority': priority.name,
      'time': createdAt.millisecondsSinceEpoch,
    };
  }
}
