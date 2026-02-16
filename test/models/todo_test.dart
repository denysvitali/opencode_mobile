import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/todo.dart';

void main() {
  group('Todo', () {
    group('constructor', () {
      test('generates default id and createdAt', () {
        final todo = Todo(content: 'Test todo');
        expect(todo.id, '');
        expect(todo.createdAt, isNotNull);
      });

      test('accepts custom id and createdAt', () {
        final createdAt = DateTime(2024, 1, 1);
        final todo = Todo(
          id: 'custom-id',
          content: 'Test todo',
          createdAt: createdAt,
        );
        expect(todo.id, 'custom-id');
        expect(todo.createdAt, createdAt);
      });

      test('has default status pending', () {
        final todo = Todo(content: 'Test');
        expect(todo.status, TodoStatus.pending);
      });

      test('has default priority medium', () {
        final todo = Todo(content: 'Test');
        expect(todo.priority, TodoPriority.medium);
      });
    });

    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'id': 'todo-1',
          'content': 'Complete task',
          'status': 'completed',
          'priority': 'high',
          'time': 1704067200000,
        };
        final todo = Todo.fromJson(json);
        expect(todo.id, 'todo-1');
        expect(todo.content, 'Complete task');
        expect(todo.status, TodoStatus.completed);
        expect(todo.priority, TodoPriority.high);
      });

      test('parses time as DateTime', () {
        final epochMs = 1704067200000;
        final json = {
          'id': 'todo-1',
          'content': 'Test',
          'time': epochMs,
        };
        final todo = Todo.fromJson(json);
        expect(todo.createdAt.millisecondsSinceEpoch, epochMs);
      });

      test('handles missing optional fields', () {
        final json = <String, dynamic>{
          'id': 'todo-1',
        };
        final todo = Todo.fromJson(json);
        expect(todo.id, 'todo-1');
        expect(todo.content, '');
        expect(todo.status, TodoStatus.pending);
        expect(todo.priority, TodoPriority.medium);
        expect(todo.createdAt, isNotNull);
      });

      test('defaults unknown status to pending', () {
        expect(
          Todo.fromJson({'status': 'unknown'}).status,
          TodoStatus.pending,
        );
        expect(
          Todo.fromJson({'status': ''}).status,
          TodoStatus.pending,
        );
        expect(
          Todo.fromJson({'status': 'invalid'}).status,
          TodoStatus.pending,
        );
      });

      test('defaults unknown priority to medium', () {
        expect(
          Todo.fromJson({'priority': 'unknown'}).priority,
          TodoPriority.medium,
        );
        expect(
          Todo.fromJson({'priority': ''}).priority,
          TodoPriority.medium,
        );
        expect(
          Todo.fromJson({'priority': 'invalid'}).priority,
          TodoPriority.medium,
        );
      });

      test('handles time as int', () {
        final json = {
          'content': 'Test',
          'time': 1704067200000,
        };
        final todo = Todo.fromJson(json);
        expect(todo.createdAt.millisecondsSinceEpoch, 1704067200000);
      });

      test('handles time as double', () {
        final json = {
          'content': 'Test',
          'time': 1704067200000.0,
        };
        final todo = Todo.fromJson(json);
        expect(todo.createdAt.millisecondsSinceEpoch, 1704067200000);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final createdAt = DateTime.fromMillisecondsSinceEpoch(1704067200000);
        final todo = Todo(
          id: 'todo-1',
          content: 'Complete task',
          status: TodoStatus.completed,
          priority: TodoPriority.high,
          createdAt: createdAt,
        );
        final json = todo.toJson();
        expect(json['id'], 'todo-1');
        expect(json['content'], 'Complete task');
        expect(json['status'], 'completed');
        expect(json['priority'], 'high');
        expect(json['time'], 1704067200000);
      });

      test('produces valid JSON', () {
        final todo = Todo(
          id: 'todo-1',
          content: 'Test',
          status: TodoStatus.pending,
          priority: TodoPriority.medium,
        );
        final jsonString = jsonEncode(todo.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('TodoStatus', () {
    test('parses pending status', () {
      final todo = Todo.fromJson({'status': 'pending'});
      expect(todo.status, TodoStatus.pending);
    });

    test('parses in_progress status', () {
      final todo = Todo.fromJson({'status': 'in_progress'});
      expect(todo.status, TodoStatus.in_progress);
    });

    test('parses completed status', () {
      final todo = Todo.fromJson({'status': 'completed'});
      expect(todo.status, TodoStatus.completed);
    });

    test('parses cancelled status', () {
      final todo = Todo.fromJson({'status': 'cancelled'});
      expect(todo.status, TodoStatus.cancelled);
    });
  });

  group('TodoPriority', () {
    test('parses low priority', () {
      final todo = Todo.fromJson({'priority': 'low'});
      expect(todo.priority, TodoPriority.low);
    });

    test('parses medium priority', () {
      final todo = Todo.fromJson({'priority': 'medium'});
      expect(todo.priority, TodoPriority.medium);
    });

    test('parses high priority', () {
      final todo = Todo.fromJson({'priority': 'high'});
      expect(todo.priority, TodoPriority.high);
    });
  });
}
