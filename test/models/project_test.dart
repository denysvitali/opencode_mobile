import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/project.dart';

void main() {
  group('Project', () {
    group('fromJson', () {
      test('parses basic project with id', () {
        final json = {
          'id': 'my-project',
        };
        final project = Project.fromJson(json);
        expect(project.id, 'my-project');
      });

      test('parses worktree', () {
        final json = {
          'id': 'my-project',
          'worktree': '/home/user/projects/my-project',
        };
        final project = Project.fromJson(json);
        expect(project.worktree, '/home/user/projects/my-project');
      });

      test('parses vcs', () {
        final json = {
          'id': 'my-project',
          'vcs': 'git',
        };
        final project = Project.fromJson(json);
        expect(project.vcs, 'git');
      });

      test('parses time.created as DateTime', () {
        final epochMs = 1704067200000;
        final json = {
          'id': 'my-project',
          'time': {
            'created': epochMs,
          },
        };
        final project = Project.fromJson(json);
        expect(project.createdAt?.millisecondsSinceEpoch, epochMs);
      });

      test('parses time.created as int', () {
        final json = {
          'id': 'my-project',
          'time': {'created': 1704067200000},
        };
        final project = Project.fromJson(json);
        expect(project.createdAt, isNotNull);
        expect(project.createdAt!.millisecondsSinceEpoch, 1704067200000);
      });

      test('handles null time object', () {
        final json = {
          'id': 'my-project',
        };
        final project = Project.fromJson(json);
        expect(project.createdAt, isNull);
      });

      test('parses nested icon object', () {
        final json = {
          'id': 'my-project',
          'icon': {
            'url': 'https://example.com/icon.png',
            'override': 'custom-icon',
            'color': '#FF5733',
          },
        };
        final project = Project.fromJson(json);
        expect(project.icon, isNotNull);
        expect(project.icon!.url, 'https://example.com/icon.png');
        expect(project.icon!.override, 'custom-icon');
        expect(project.icon!.color, '#FF5733');
      });

      test('parses icon with partial fields', () {
        final json = {
          'id': 'my-project',
          'icon': {
            'url': 'https://example.com/icon.png',
          },
        };
        final project = Project.fromJson(json);
        expect(project.icon!.url, 'https://example.com/icon.png');
        expect(project.icon!.override, isNull);
        expect(project.icon!.color, isNull);
      });

      test('handles null icon', () {
        final json = {
          'id': 'my-project',
        };
        final project = Project.fromJson(json);
        expect(project.icon, isNull);
      });

      test('parses nested commands object', () {
        final json = {
          'id': 'my-project',
          'commands': {
            'start': 'npm run dev',
          },
        };
        final project = Project.fromJson(json);
        expect(project.commands, isNotNull);
        expect(project.commands!.start, 'npm run dev');
      });

      test('handles null commands', () {
        final json = {
          'id': 'my-project',
        };
        final project = Project.fromJson(json);
        expect(project.commands, isNull);
      });

      test('handles missing id', () {
        final json = <String, dynamic>{};
        final project = Project.fromJson(json);
        expect(project.id, '');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final createdAt = DateTime.fromMillisecondsSinceEpoch(1704067200000);
        final project = Project(
          id: 'my-project',
          worktree: '/home/user/projects/my-project',
          vcs: 'git',
          createdAt: createdAt,
          icon: ProjectIcon(url: 'https://example.com/icon.png'),
          commands: ProjectCommands(start: 'npm run dev'),
        );
        final json = project.toJson();

        expect(json['id'], 'my-project');
        expect(json['worktree'], '/home/user/projects/my-project');
        expect(json['vcs'], 'git');
        expect(json['time'], 1704067200000);
        expect(json['icon'], isNotNull);
        expect(json['commands'], isNotNull);
      });

      test('omits null fields', () {
        final project = Project(id: 'my-project');
        final json = project.toJson();

        expect(json['id'], 'my-project');
        expect(json.containsKey('worktree'), false);
        expect(json.containsKey('vcs'), false);
        expect(json.containsKey('time'), false);
        expect(json.containsKey('icon'), false);
        expect(json.containsKey('commands'), false);
      });

      test('serializes icon correctly', () {
        final project = Project(
          id: 'my-project',
          icon: ProjectIcon(url: 'https://example.com/icon.png'),
        );
        final json = project.toJson();

        expect(json['icon']['url'], 'https://example.com/icon.png');
      });

      test('serializes commands correctly', () {
        final project = Project(
          id: 'my-project',
          commands: ProjectCommands(start: 'npm run dev'),
        );
        final json = project.toJson();

        expect(json['commands']['start'], 'npm run dev');
      });

      test('produces valid JSON', () {
        final project = Project(
          id: 'my-project',
          worktree: '/path/to/project',
        );
        final jsonString = jsonEncode(project.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });

    group('displayName', () {
      test('returns id when worktree is null', () {
        final project = Project(id: 'my-project');
        expect(project.displayName, 'my-project');
      });

      test('returns id when worktree is empty', () {
        final project = Project(id: 'my-project', worktree: '');
        expect(project.displayName, 'my-project');
      });

      test('extracts last path segment from worktree', () {
        final project = Project(
          id: 'my-project',
          worktree: '/home/user/projects/my-project',
        );
        expect(project.displayName, 'my-project');
      });

      test('handles trailing slash', () {
        final project = Project(
          id: 'my-project',
          worktree: '/home/user/projects/',
        );
        expect(project.displayName, 'my-project');
      });

      test('handles single segment path', () {
        final project = Project(
          id: 'my-project',
          worktree: '/my-project',
        );
        expect(project.displayName, 'my-project');
      });

      test('handles Windows-style path (splits by forward slash only)', () {
        final project = Project(
          id: 'my-project',
          worktree: 'C:/Users/user/projects/my-project',
        );
        expect(project.displayName, 'my-project');
      });
    });
  });

  group('ProjectIcon', () {
    test('creates with default values', () {
      final icon = ProjectIcon();
      expect(icon.url, isNull);
      expect(icon.override, isNull);
      expect(icon.color, isNull);
    });

    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'url': 'https://example.com/icon.png',
          'override': 'custom',
          'color': '#FF0000',
        };
        final icon = ProjectIcon.fromJson(json);
        expect(icon.url, 'https://example.com/icon.png');
        expect(icon.override, 'custom');
        expect(icon.color, '#FF0000');
      });

      test('handles missing fields', () {
        final json = <String, dynamic>{};
        final icon = ProjectIcon.fromJson(json);
        expect(icon.url, isNull);
        expect(icon.override, isNull);
        expect(icon.color, isNull);
      });
    });

    group('toJson', () {
      test('serializes all non-null fields', () {
        final icon = ProjectIcon(
          url: 'https://example.com/icon.png',
          override: 'custom',
          color: '#FF0000',
        );
        final json = icon.toJson();
        expect(json['url'], 'https://example.com/icon.png');
        expect(json['override'], 'custom');
        expect(json['color'], '#FF0000');
      });

      test('omits null fields', () {
        final icon = ProjectIcon(url: 'https://example.com/icon.png');
        final json = icon.toJson();
        expect(json['url'], 'https://example.com/icon.png');
        expect(json.containsKey('override'), false);
        expect(json.containsKey('color'), false);
      });
    });
  });

  group('ProjectCommands', () {
    test('creates with default values', () {
      final commands = ProjectCommands();
      expect(commands.start, isNull);
    });

    group('fromJson', () {
      test('parses start command', () {
        final json = {'start': 'npm run dev'};
        final commands = ProjectCommands.fromJson(json);
        expect(commands.start, 'npm run dev');
      });

      test('handles missing start', () {
        final json = <String, dynamic>{};
        final commands = ProjectCommands.fromJson(json);
        expect(commands.start, isNull);
      });
    });

    group('toJson', () {
      test('serializes start command', () {
        final commands = ProjectCommands(start: 'npm run dev');
        final json = commands.toJson();
        expect(json['start'], 'npm run dev');
      });

      test('omits null start', () {
        final commands = ProjectCommands();
        final json = commands.toJson();
        expect(json.containsKey('start'), false);
      });
    });
  });

  group('ProjectUpdateInput', () {
    group('toJson', () {
      test('serializes all fields', () {
        final input = ProjectUpdateInput(
          name: 'New Name',
          icon: ProjectIcon(url: 'https://example.com/icon.png'),
          commands: ProjectCommands(start: 'npm run dev'),
        );
        final json = input.toJson();

        expect(json['name'], 'New Name');
        expect(json['icon'], isNotNull);
        expect(json['commands'], isNotNull);
      });

      test('omits null fields', () {
        final input = ProjectUpdateInput();
        final json = input.toJson();

        expect(json.containsKey('name'), false);
        expect(json.containsKey('icon'), false);
        expect(json.containsKey('commands'), false);
      });

      test('serializes name only', () {
        final input = ProjectUpdateInput(name: 'New Name');
        final json = input.toJson();

        expect(json['name'], 'New Name');
        expect(json.containsKey('icon'), false);
        expect(json.containsKey('commands'), false);
      });

      test('serializes icon only', () {
        final input = ProjectUpdateInput(icon: ProjectIcon(url: 'icon.png'));
        final json = input.toJson();

        expect(json.containsKey('name'), false);
        expect(json['icon'], isNotNull);
        expect(json.containsKey('commands'), false);
      });

      test('serializes commands only', () {
        final input = ProjectUpdateInput(commands: ProjectCommands(start: 'npm start'));
        final json = input.toJson();

        expect(json.containsKey('name'), false);
        expect(json.containsKey('icon'), false);
        expect(json['commands'], isNotNull);
      });

      test('produces valid JSON', () {
        final input = ProjectUpdateInput(
          name: 'My Project',
          icon: ProjectIcon(color: '#FF0000'),
        );
        final jsonString = jsonEncode(input.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });
}
