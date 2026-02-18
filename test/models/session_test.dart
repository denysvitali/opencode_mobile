import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/session.dart';

void main() {
  group('Session', () {
    test('creates with default values', () {
      final session = Session();
      expect(session.id, isNotEmpty);
      expect(session.status, SessionStatus.idle);
      expect(session.path, '');
      expect(session.createdAt, isNotNull);
    });

    group('fromJson', () {
      test('parses basic session with id, title, status', () {
        final json = {
          'id': 'test-id',
          'title': 'Test Session',
          'status': 'running',
          'path': {'cwd': '/test/path'},
          'time': {
            'created': 1000000,
          },
        };
        final session = Session.fromJson(json);
        expect(session.id, 'test-id');
        expect(session.title, 'Test Session');
        expect(session.status, SessionStatus.running);
        expect(session.path, '/test/path');
      });

      test('parses time.created as milliseconds since epoch', () {
        final epochMs = 1704067200000;
        final json = {
          'id': 'test-id',
          'time': {'created': epochMs},
        };
        final session = Session.fromJson(json);
        expect(session.createdAt.millisecondsSinceEpoch, epochMs);
      });

      test('parses time.completed as milliseconds since epoch', () {
        final createdMs = 1704067200000;
        final completedMs = 1704070800000;
        final json = {
          'id': 'test-id',
          'time': {
            'created': createdMs,
            'completed': completedMs,
          },
        };
        final session = Session.fromJson(json);
        expect(session.completedAt?.millisecondsSinceEpoch, completedMs);
      });

      test('parses time.archived as milliseconds since epoch', () {
        final createdMs = 1704067200000;
        final archivedMs = 1704074400000;
        final json = {
          'id': 'test-id',
          'time': {
            'created': createdMs,
            'archived': archivedMs,
          },
        };
        final session = Session.fromJson(json);
        expect(session.archivedAt?.millisecondsSinceEpoch, archivedMs);
      });

      test('handles path.cwd format', () {
        final json = {
          'id': 'test-id',
          'path': {'cwd': '/home/user/project'},
        };
        final session = Session.fromJson(json);
        expect(session.path, '/home/user/project');
      });

      test('handles empty path.cwd', () {
        final json = {
          'id': 'test-id',
          'path': {'cwd': ''},
        };
        final session = Session.fromJson(json);
        expect(session.path, '');
      });

      test('handles path as string format', () {
        final json = {
          'id': 'test-id',
          'path': '/simple/path',
        };
        final session = Session.fromJson(json);
        expect(session.path, '/simple/path');
      });

      test('handles worktree field', () {
        final json = {
          'id': 'test-id',
          'worktree': '/worktree/path',
        };
        final session = Session.fromJson(json);
        expect(session.path, '/worktree/path');
      });

      test('handles directory field', () {
        final json = {
          'id': 'test-id',
          'directory': '/directory/path',
        };
        final session = Session.fromJson(json);
        expect(session.path, '/directory/path');
      });

      test('path.cwd takes precedence over worktree', () {
        final json = {
          'id': 'test-id',
          'path': {'cwd': '/from/cwd'},
          'worktree': '/from/worktree',
        };
        final session = Session.fromJson(json);
        expect(session.path, '/from/cwd');
      });

      test('worktree takes precedence over directory', () {
        final json = {
          'id': 'test-id',
          'worktree': '/from/worktree',
          'directory': '/from/directory',
        };
        final session = Session.fromJson(json);
        expect(session.path, '/from/worktree');
      });

      test('handles path.path nested field', () {
        final json = {
          'id': 'test-id',
          'path': {'path': '/nested/path'},
        };
        final session = Session.fromJson(json);
        expect(session.path, '/nested/path');
      });

      test('handles parentID', () {
        final json = {
          'id': 'child-session',
          'parentID': 'parent-session-id',
        };
        final session = Session.fromJson(json);
        expect(session.parentID, 'parent-session-id');
      });

      test('handles permission ruleset', () {
        final json = {
          'id': 'test-id',
          'permission': {
            'mode': 'manual',
            'allow': ['read', 'write'],
            'deny': ['delete'],
          },
        };
        final session = Session.fromJson(json);
        expect(session.permission, isNotNull);
        expect(session.permission!.mode, 'manual');
        expect(session.permission!.allow, ['read', 'write']);
        expect(session.permission!.deny, ['delete']);
      });

      test('handles permission ruleset with only mode', () {
        final json = {
          'id': 'test-id',
          'permission': {'mode': 'auto'},
        };
        final session = Session.fromJson(json);
        expect(session.permission, isNotNull);
        expect(session.permission!.mode, 'auto');
        expect(session.permission!.allow, isNull);
        expect(session.permission!.deny, isNull);
      });

      test('handles description field', () {
        final json = {
          'id': 'test-id',
          'description': 'Session description',
        };
        final session = Session.fromJson(json);
        expect(session.description, 'Session description');
      });

      test('handles projectID field', () {
        final json = {
          'id': 'test-id',
          'projectID': 'project-123',
        };
        final session = Session.fromJson(json);
        expect(session.projectID, 'project-123');
      });

      test('handles cost field', () {
        final json = {
          'id': 'test-id',
          'cost': 12.50,
        };
        final session = Session.fromJson(json);
        expect(session.cost, 12.50);
      });

      test('handles cost as int', () {
        final json = {
          'id': 'test-id',
          'cost': 10,
        };
        final session = Session.fromJson(json);
        expect(session.cost, 10.0);
      });

      test('handles summary field', () {
        final json = {
          'id': 'test-id',
          'summary': 'Session summary',
        };
        final session = Session.fromJson(json);
        expect(session.summary, 'Session summary');
      });

      test('handles summary as non-string', () {
        final json = {
          'id': 'test-id',
          'summary': 123,
        };
        final session = Session.fromJson(json);
        expect(session.summary, '123');
      });

      test('handles missing optional fields gracefully', () {
        final json = <String, dynamic>{'id': 'test-id'};
        final session = Session.fromJson(json);
        expect(session.id, 'test-id');
        expect(session.title, isNull);
        expect(session.description, isNull);
        expect(session.status, SessionStatus.idle);
        expect(session.parentID, isNull);
        expect(session.path, '');
        expect(session.projectID, isNull);
        expect(session.permission, isNull);
        expect(session.cost, isNull);
        expect(session.summary, isNull);
        expect(session.completedAt, isNull);
        expect(session.archivedAt, isNull);
      });

      test('handles missing time object', () {
        final json = {
          'id': 'test-id',
        };
        final session = Session.fromJson(json);
        expect(session.createdAt, isNotNull);
        expect(session.completedAt, isNull);
        expect(session.archivedAt, isNull);
      });

      test('handles sessionID key', () {
        final json = {
          'sessionID': 'session-id-key',
        };
        final session = Session.fromJson(json);
        expect(session.id, 'session-id-key');
      });

      test('handles sessionId key', () {
        final json = {
          'sessionId': 'session-id-camel',
        };
        final session = Session.fromJson(json);
        expect(session.id, 'session-id-camel');
      });

      test('id takes precedence over sessionID and sessionId', () {
        final json = {
          'id': 'id-first',
          'sessionID': 'session-id-second',
          'sessionId': 'session-id-third',
        };
        final session = Session.fromJson(json);
        expect(session.id, 'id-first');
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final createdAt = DateTime.fromMillisecondsSinceEpoch(1704067200000);
        final completedAt = DateTime.fromMillisecondsSinceEpoch(1704070800000);
        final session = Session(
          id: 'test-id',
          parentID: 'parent-1',
          title: 'Test Title',
          description: 'Test Description',
          status: SessionStatus.running,
          createdAt: createdAt,
          completedAt: completedAt,
          summary: 'Summary',
          cost: 5.50,
          path: '/test/path',
          projectID: 'project-1',
          permission: PermissionRuleset(mode: 'manual'),
        );
        final json = session.toJson();

        expect(json['id'], 'test-id');
        expect(json['parentID'], 'parent-1');
        expect(json['title'], 'Test Title');
        expect(json['description'], 'Test Description');
        expect(json['status'], 'running');
        expect(json['time']['created'], 1704067200000);
        expect(json['time']['completed'], 1704070800000);
        expect(json['summary'], 'Summary');
        expect(json['cost'], 5.50);
        expect(json['path']['cwd'], '/test/path');
        expect(json['projectID'], 'project-1');
        expect(json['permission'], {'mode': 'manual'});
      });

      test('handles optional fields correctly', () {
        final session = Session(
          id: 'test-id',
          title: 'Test',
          status: SessionStatus.idle,
          path: '/test',
        );
        final json = session.toJson();

        expect(json['parentID'], isNull);
        expect(json.containsKey('parentID'), false);
        expect(json.containsKey('completedAt'), false);
        expect(json.containsKey('archivedAt'), false);
        expect(json['description'], isNull);
        expect(json['projectID'], isNull);
        expect(json['permission'], isNull);
      });

      test('produces valid JSON', () {
        final session = Session(
          id: 'test-id',
          title: 'Test Session',
          status: SessionStatus.running,
          path: '/test/path',
        );
        final jsonString = jsonEncode(session.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });

      test('serializes archivedAt when present', () {
        final createdAt = DateTime.fromMillisecondsSinceEpoch(1704067200000);
        final archivedAt = DateTime.fromMillisecondsSinceEpoch(1704074400000);
        final session = Session(
          id: 'test-id',
          createdAt: createdAt,
          archivedAt: archivedAt,
        );
        final json = session.toJson();

        expect(json['time']['archived'], 1704074400000);
      });

      test('serializes cost as double', () {
        final session = Session(
          id: 'test-id',
          cost: 10.0,
        );
        final json = session.toJson();
        expect(json['cost'], 10.0);
      });
    });

    group('copyWith', () {
      test('updates specific fields', () {
        final session = Session(
          id: 'original-id',
          title: 'Original Title',
          status: SessionStatus.idle,
        );
        final updated = session.copyWith(
          title: 'Updated Title',
          status: SessionStatus.running,
        );

        expect(updated.title, 'Updated Title');
        expect(updated.status, SessionStatus.running);
      });

      test('preserves unchanged fields', () {
        final session = Session(
          id: 'test-id',
          title: 'Original Title',
          description: 'Original Description',
          status: SessionStatus.idle,
          path: '/original/path',
          projectID: 'project-1',
        );
        final updated = session.copyWith(title: 'New Title');

        expect(updated.id, 'test-id');
        expect(updated.description, 'Original Description');
        expect(updated.status, SessionStatus.idle);
        expect(updated.path, '/original/path');
        expect(updated.projectID, 'project-1');
      });

      test('handles optional fields', () {
        final session = Session(
          id: 'test-id',
          parentID: 'parent-1',
          permission: PermissionRuleset(mode: 'auto'),
        );

        final updated = session.copyWith(title: 'New Title');
        expect(updated.parentID, 'parent-1');
        expect(updated.permission?.mode, 'auto');

        final cleared = session.copyWith(parentID: null, permission: null);
        expect(cleared.parentID, isNull);
        expect(cleared.permission, isNull);
      });

      test('updates parentID', () {
        final session = Session(id: 'test-id', parentID: 'parent-1');
        final updated = session.copyWith(parentID: 'new-parent');
        expect(updated.parentID, 'new-parent');
      });

      test('updates description', () {
        final session = Session(id: 'test-id', description: 'Old desc');
        final updated = session.copyWith(description: 'New desc');
        expect(updated.description, 'New desc');
      });

      test('updates completedAt', () {
        final session = Session(id: 'test-id');
        final completedAt = DateTime.now();
        final updated = session.copyWith(completedAt: completedAt);
        expect(updated.completedAt, completedAt);
      });

      test('updates archivedAt', () {
        final session = Session(id: 'test-id');
        final archivedAt = DateTime.now();
        final updated = session.copyWith(archivedAt: archivedAt);
        expect(updated.archivedAt, archivedAt);
      });

      test('updates summary', () {
        final session = Session(id: 'test-id', summary: 'Old summary');
        final updated = session.copyWith(summary: 'New summary');
        expect(updated.summary, 'New summary');
      });

      test('updates cost', () {
        final session = Session(id: 'test-id', cost: 5.0);
        final updated = session.copyWith(cost: 10.0);
        expect(updated.cost, 10.0);
      });

      test('updates path', () {
        final session = Session(id: 'test-id', path: '/old/path');
        final updated = session.copyWith(path: '/new/path');
        expect(updated.path, '/new/path');
      });

      test('updates projectID', () {
        final session = Session(id: 'test-id', projectID: 'old-project');
        final updated = session.copyWith(projectID: 'new-project');
        expect(updated.projectID, 'new-project');
      });

      test('updates permission', () {
        final session = Session(
          id: 'test-id',
          permission: PermissionRuleset(mode: 'auto'),
        );
        final updated = session.copyWith(
          permission: PermissionRuleset(mode: 'manual'),
        );
        expect(updated.permission?.mode, 'manual');
      });

      test('updates createdAt', () {
        final session = Session(id: 'test-id');
        final newCreatedAt = DateTime(2024, 1, 1);
        final updated = session.copyWith(createdAt: newCreatedAt);
        expect(updated.createdAt, newCreatedAt);
      });
    });

    group('displayName', () {
      test('returns title when not empty', () {
        expect(Session(title: 'My Session').displayName, 'My Session');
      });

      test('returns default when title is null', () {
        expect(Session().displayName, 'New Session');
      });

      test('returns default when title is empty', () {
        expect(Session(title: '').displayName, 'New Session');
      });
    });

    group('isArchived', () {
      test('returns false when archivedAt is null', () {
        expect(Session().isArchived, false);
      });

      test('returns true when archivedAt is set', () {
        expect(Session(archivedAt: DateTime.now()).isArchived, true);
      });
    });

    group('isChild', () {
      test('returns false when parentID is null', () {
        expect(Session().isChild, false);
      });

      test('returns true when parentID is set', () {
        expect(Session(parentID: 'parent').isChild, true);
      });
    });
  });

  group('SessionStatus', () {
    test('parses idle status', () {
      expect(Session.fromJson({'status': 'idle'}).status, SessionStatus.idle);
    });

    test('parses pending status', () {
      expect(Session.fromJson({'status': 'pending'}).status, SessionStatus.pending);
    });

    test('parses running status', () {
      expect(Session.fromJson({'status': 'running'}).status, SessionStatus.running);
    });

    test('parses compacting status', () {
      expect(Session.fromJson({'status': 'compacting'}).status, SessionStatus.compacting);
    });

    test('unknown status defaults to idle', () {
      expect(Session.fromJson({'status': 'unknown'}).status, SessionStatus.idle);
      expect(Session.fromJson({'status': 'error'}).status, SessionStatus.idle);
      expect(Session.fromJson({'status': ''}).status, SessionStatus.idle);
    });

    test('missing status defaults to idle', () {
      expect(Session.fromJson({}).status, SessionStatus.idle);
    });
  });

  group('PermissionRuleset', () {
    test('creates with default mode', () {
      final ruleset = PermissionRuleset();
      expect(ruleset.mode, 'auto');
    });

    test('fromJson parses correctly', () {
      final json = {
        'mode': 'manual',
        'allow': ['read'],
        'deny': ['write'],
      };
      final ruleset = PermissionRuleset.fromJson(json);
      expect(ruleset.mode, 'manual');
      expect(ruleset.allow, ['read']);
      expect(ruleset.deny, ['write']);
    });

    test('fromJson handles missing optional fields', () {
      final json = {'mode': 'auto'};
      final ruleset = PermissionRuleset.fromJson(json);
      expect(ruleset.mode, 'auto');
      expect(ruleset.allow, isNull);
      expect(ruleset.deny, isNull);
    });

    test('fromJson handles empty arrays', () {
      final json = {'mode': 'manual', 'allow': [], 'deny': []};
      final ruleset = PermissionRuleset.fromJson(json);
      expect(ruleset.allow, []);
      expect(ruleset.deny, []);
    });

    test('fromJson handles mixed type arrays', () {
      final json = {'mode': 'manual', 'allow': [1, 'read', true]};
      final ruleset = PermissionRuleset.fromJson(json);
      expect(ruleset.allow, ['1', 'read', 'true']);
    });

    test('toJson produces correct output', () {
      final ruleset = PermissionRuleset(
        mode: 'manual',
        allow: ['read', 'write'],
        deny: ['delete'],
      );
      final json = ruleset.toJson();
      expect(json['mode'], 'manual');
      expect(json['allow'], ['read', 'write']);
      expect(json['deny'], ['delete']);
    });

    test('toJson omits null values', () {
      final ruleset = PermissionRuleset(allow: ['read']);
      final json = ruleset.toJson();
      expect(json.containsKey('deny'), false);
      expect(json['allow'], ['read']);
      expect(json['mode'], 'auto');
    });

    test('toJson produces valid JSON', () {
      final ruleset = PermissionRuleset(
        mode: 'manual',
        allow: ['read'],
        deny: ['write'],
      );
      final jsonString = jsonEncode(ruleset.toJson());
      expect(() => jsonDecode(jsonString), returnsNormally);
    });
  });

  group('SessionCreateInput', () {
    test('toJson produces correct output with all fields', () {
      final input = SessionCreateInput(
        parentID: 'parent-1',
        title: 'New Session',
        permission: PermissionRuleset(mode: 'manual'),
      );
      final json = input.toJson();
      expect(json['parentID'], 'parent-1');
      expect(json['title'], 'New Session');
      expect(json['permission'], {'mode': 'manual'});
    });

    test('toJson produces correct output with only title', () {
      final input = SessionCreateInput(title: 'New Session');
      final json = input.toJson();
      expect(json['title'], 'New Session');
      expect(json.containsKey('parentID'), false);
      expect(json.containsKey('permission'), false);
    });

    test('toJson produces correct output with only parentID', () {
      final input = SessionCreateInput(parentID: 'parent-1');
      final json = input.toJson();
      expect(json['parentID'], 'parent-1');
      expect(json.containsKey('title'), false);
      expect(json.containsKey('permission'), false);
    });

    test('toJson produces correct output with only permission', () {
      final input = SessionCreateInput(
        permission: PermissionRuleset(mode: 'manual'),
      );
      final json = input.toJson();
      expect(json['permission'], {'mode': 'manual'});
      expect(json.containsKey('title'), false);
      expect(json.containsKey('parentID'), false);
    });

    test('toJson omits null values', () {
      final input = SessionCreateInput();
      final json = input.toJson();
      expect(json.containsKey('parentID'), false);
      expect(json.containsKey('title'), false);
      expect(json.containsKey('permission'), false);
    });

    test('toJson produces valid JSON', () {
      final input = SessionCreateInput(
        title: 'New Session',
        parentID: 'parent-1',
      );
      final jsonString = jsonEncode(input.toJson());
      expect(() => jsonDecode(jsonString), returnsNormally);
    });
  });

  group('SessionUpdateInput', () {
    test('toJson produces correct output with all fields', () {
      final input = SessionUpdateInput(
        title: 'Updated Title',
        archivedAt: 1704074400000,
      );
      final json = input.toJson();
      expect(json['title'], 'Updated Title');
      expect(json['time']['archived'], 1704074400000);
    });

    test('toJson produces correct output with only title', () {
      final input = SessionUpdateInput(title: 'Updated Title');
      final json = input.toJson();
      expect(json['title'], 'Updated Title');
      expect(json.containsKey('time'), false);
    });

    test('toJson produces correct output with only archivedAt', () {
      final input = SessionUpdateInput(archivedAt: 1704074400000);
      final json = input.toJson();
      expect(json.containsKey('title'), false);
      expect(json['time']['archived'], 1704074400000);
    });

    test('toJson omits null values', () {
      final input = SessionUpdateInput();
      final json = input.toJson();
      expect(json.containsKey('title'), false);
      expect(json.containsKey('time'), false);
    });

    test('toJson produces valid JSON', () {
      final input = SessionUpdateInput(
        title: 'Updated',
        archivedAt: 1000000,
      );
      final jsonString = jsonEncode(input.toJson());
      expect(() => jsonDecode(jsonString), returnsNormally);
    });
  });
}
