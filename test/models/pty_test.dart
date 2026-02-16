import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/pty.dart';

void main() {
  group('PtySize', () {
    group('fromJson', () {
      test('parses rows and cols', () {
        final json = {'rows': 30, 'cols': 120};
        final size = PtySize.fromJson(json);
        expect(size.rows, 30);
        expect(size.cols, 120);
      });

      test('uses defaults when missing', () {
        final json = <String, dynamic>{};
        final size = PtySize.fromJson(json);
        expect(size.rows, 24);
        expect(size.cols, 80);
      });

      test('handles partial json with rows only', () {
        final json = {'rows': 40};
        final size = PtySize.fromJson(json);
        expect(size.rows, 40);
        expect(size.cols, 80);
      });

      test('handles partial json with cols only', () {
        final json = {'cols': 100};
        final size = PtySize.fromJson(json);
        expect(size.rows, 24);
        expect(size.cols, 100);
      });
    });

    group('toJson', () {
      test('serializes rows and cols', () {
        final size = PtySize(rows: 30, cols: 120);
        final json = size.toJson();
        expect(json['rows'], 30);
        expect(json['cols'], 120);
      });

      test('produces valid JSON', () {
        final size = PtySize(rows: 24, cols: 80);
        final jsonString = jsonEncode(size.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('PtyStatus', () {
    test('has running status', () {
      expect(PtyStatus.running.name, 'running');
    });

    test('has exited status', () {
      expect(PtyStatus.exited.name, 'exited');
    });
  });

  group('Pty', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'id': 'pty-1',
          'command': 'bash',
          'args': ['-l'],
          'cwd': '/home/user',
          'title': 'Terminal',
          'status': 'running',
          'exitCode': 0,
          'size': {'rows': 24, 'cols': 80},
          'env': {'TERM': 'xterm-256color'},
          'time': 1704067200000,
        };
        final pty = Pty.fromJson(json);
        expect(pty.id, 'pty-1');
        expect(pty.command, 'bash');
        expect(pty.cwd, '/home/user');
        expect(pty.title, 'Terminal');
        expect(pty.status, PtyStatus.running);
        expect(pty.exitCode, 0);
      });

      test('parses size as nested PtySize', () {
        final json = {
          'id': 'pty-1',
          'command': 'bash',
          'size': {'rows': 30, 'cols': 100},
        };
        final pty = Pty.fromJson(json);
        expect(pty.size, isNotNull);
        expect(pty.size!.rows, 30);
        expect(pty.size!.cols, 100);
      });

      test('parses args as List<String>', () {
        final json = {
          'id': 'pty-1',
          'command': 'npm',
          'args': ['run', 'dev', '--watch'],
        };
        final pty = Pty.fromJson(json);
        expect(pty.args, ['run', 'dev', '--watch']);
        expect(pty.args, isA<List<String>>());
      });

      test('parses env as Map<String, String>', () {
        final json = {
          'id': 'pty-1',
          'command': 'bash',
          'env': {'PATH': '/usr/bin', 'HOME': '/home/user'},
        };
        final pty = Pty.fromJson(json);
        expect(pty.env, isNotNull);
        expect(pty.env!['PATH'], '/usr/bin');
        expect(pty.env!['HOME'], '/home/user');
        expect(pty.env, isA<Map<String, String>>());
      });

      test('parses time as DateTime', () {
        final epochMs = 1704067200000;
        final json = {
          'id': 'pty-1',
          'command': 'bash',
          'time': epochMs,
        };
        final pty = Pty.fromJson(json);
        expect(pty.createdAt.millisecondsSinceEpoch, epochMs);
      });

      test('handles missing optional fields', () {
        final json = <String, dynamic>{
          'id': 'pty-1',
          'command': 'bash',
        };
        final pty = Pty.fromJson(json);
        expect(pty.id, 'pty-1');
        expect(pty.command, 'bash');
        expect(pty.args, isEmpty);
        expect(pty.cwd, isNull);
        expect(pty.title, isNull);
        expect(pty.status, PtyStatus.running);
        expect(pty.exitCode, isNull);
        expect(pty.size, isNull);
        expect(pty.env, isNull);
        expect(pty.createdAt, isNotNull);
      });

      test('parses exited status', () {
        final json = {
          'id': 'pty-1',
          'command': 'bash',
          'status': 'exited',
          'exitCode': 1,
        };
        final pty = Pty.fromJson(json);
        expect(pty.status, PtyStatus.exited);
        expect(pty.exitCode, 1);
      });

      test('defaults to running when status missing', () {
        final json = {
          'id': 'pty-1',
          'command': 'bash',
        };
        final pty = Pty.fromJson(json);
        expect(pty.status, PtyStatus.running);
      });

      test('handles empty args array', () {
        final json = {
          'id': 'pty-1',
          'command': 'bash',
          'args': <dynamic>[],
        };
        final pty = Pty.fromJson(json);
        expect(pty.args, isEmpty);
      });

      test('handles null args', () {
        final json = {
          'id': 'pty-1',
          'command': 'bash',
          'args': null,
        };
        final pty = Pty.fromJson(json);
        expect(pty.args, isEmpty);
      });

      test('handles null env', () {
        final json = {
          'id': 'pty-1',
          'command': 'bash',
          'env': null,
        };
        final pty = Pty.fromJson(json);
        expect(pty.env, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final createdAt = DateTime.fromMillisecondsSinceEpoch(1704067200000);
        final pty = Pty(
          id: 'pty-1',
          command: 'bash',
          args: ['-l'],
          cwd: '/home/user',
          title: 'Terminal',
          status: PtyStatus.running,
          exitCode: 0,
          size: PtySize(rows: 24, cols: 80),
          env: {'TERM': 'xterm'},
          createdAt: createdAt,
        );
        final json = pty.toJson();
        expect(json['id'], 'pty-1');
        expect(json['command'], 'bash');
        expect(json['args'], ['-l']);
        expect(json['cwd'], '/home/user');
        expect(json['title'], 'Terminal');
        expect(json['status'], 'running');
        expect(json['exitCode'], 0);
        expect(json['size'], {'rows': 24, 'cols': 80});
        expect(json['env'], {'TERM': 'xterm'});
        expect(json['time'], 1704067200000);
      });

      test('includes default args when not provided', () {
        final pty = Pty(
          id: 'pty-1',
          command: 'bash',
        );
        final json = pty.toJson();
        expect(json.containsKey('args'), true);
        expect(json['args'], isEmpty);
      });

      test('produces valid JSON', () {
        final pty = Pty(
          id: 'pty-1',
          command: 'bash',
          args: ['-l'],
          status: PtyStatus.exited,
          exitCode: 0,
        );
        final jsonString = jsonEncode(pty.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });

      test('serializes exited status correctly', () {
        final pty = Pty(
          id: 'pty-1',
          command: 'bash',
          status: PtyStatus.exited,
          exitCode: 1,
        );
        final json = pty.toJson();
        expect(json['status'], 'exited');
        expect(json['exitCode'], 1);
      });
    });
  });

  group('PtyCreateInput', () {
    group('toJson', () {
      test('includes all fields when set', () {
        final input = PtyCreateInput(
          command: 'npm',
          args: ['run', 'dev'],
          cwd: '/project',
          title: 'Dev Server',
          env: {'NODE_ENV': 'development'},
        );
        final json = input.toJson();
        expect(json['command'], 'npm');
        expect(json['args'], ['run', 'dev']);
        expect(json['cwd'], '/project');
        expect(json['title'], 'Dev Server');
        expect(json['env'], {'NODE_ENV': 'development'});
      });

      test('omits null fields', () {
        final input = PtyCreateInput(command: 'bash');
        final json = input.toJson();
        expect(json['command'], 'bash');
        expect(json.containsKey('args'), false);
        expect(json.containsKey('cwd'), false);
        expect(json.containsKey('title'), false);
        expect(json.containsKey('env'), false);
      });

      test('omits args when null', () {
        final input = PtyCreateInput(
          command: 'bash',
          cwd: '/home',
        );
        final json = input.toJson();
        expect(json.containsKey('args'), false);
        expect(json['cwd'], '/home');
      });

      test('produces valid JSON', () {
        final input = PtyCreateInput(
          command: 'npm',
          args: ['test'],
        );
        final jsonString = jsonEncode(input.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('PtyUpdateInput', () {
    group('toJson', () {
      test('includes all fields when set', () {
        final input = PtyUpdateInput(
          title: 'Updated Title',
          size: PtySize(rows: 40, cols: 120),
        );
        final json = input.toJson();
        expect(json['title'], 'Updated Title');
        expect(json['size'], {'rows': 40, 'cols': 120});
      });

      test('omits null fields', () {
        final input = PtyUpdateInput();
        final json = input.toJson();
        expect(json, isEmpty);
      });

      test('omits title when null', () {
        final input = PtyUpdateInput(size: PtySize(rows: 30, cols: 100));
        final json = input.toJson();
        expect(json.containsKey('title'), false);
        expect(json['size'], {'rows': 30, 'cols': 100});
      });

      test('omits size when null', () {
        final input = PtyUpdateInput(title: 'New Title');
        final json = input.toJson();
        expect(json.containsKey('size'), false);
        expect(json['title'], 'New Title');
      });

      test('produces valid JSON', () {
        final input = PtyUpdateInput(
          title: 'Test',
          size: PtySize(rows: 24, cols: 80),
        );
        final jsonString = jsonEncode(input.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });
}
