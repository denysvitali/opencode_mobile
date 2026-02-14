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

    test('fromJson parses basic session', () {
      final json = {
        'id': 'test-id',
        'title': 'Test Session',
        'status': 'running',
        'path': {'cwd': '/test/path'},
        'time': {
          'created': 1000000,
          'completed': 2000000,
        },
      };
      final session = Session.fromJson(json);
      expect(session.id, 'test-id');
      expect(session.title, 'Test Session');
      expect(session.status, SessionStatus.running);
      expect(session.path, '/test/path');
    });

    test('fromJson parses all status types', () {
      expect(Session.fromJson({'status': 'idle'}).status, SessionStatus.idle);
      expect(Session.fromJson({'status': 'pending'}).status, SessionStatus.pending);
      expect(Session.fromJson({'status': 'running'}).status, SessionStatus.running);
      expect(Session.fromJson({'status': 'compacting'}).status, SessionStatus.compacting);
      expect(Session.fromJson({'status': 'unknown'}).status, SessionStatus.idle);
      expect(Session.fromJson({}).status, SessionStatus.idle);
    });

    test('fromJson parses permission ruleset', () {
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

    test('toJson produces correct output', () {
      final session = Session(
        id: 'test-id',
        title: 'Test',
        status: SessionStatus.running,
        path: '/test',
      );
      final json = session.toJson();
      expect(json['id'], 'test-id');
      expect(json['title'], 'Test');
      expect(json['status'], 'running');
    });

    test('copyWith creates new instance with updated values', () {
      final session = Session(id: 'original', title: 'Original');
      final updated = session.copyWith(title: 'Updated', status: SessionStatus.running);
      expect(updated.id, 'original');
      expect(updated.title, 'Updated');
      expect(updated.status, SessionStatus.running);
    });

    test('displayName returns title or default', () {
      expect(Session(title: 'My Session').displayName, 'My Session');
      expect(Session().displayName, 'New Session');
      expect(Session(title: '').displayName, 'New Session');
    });

    test('isArchived returns correct value', () {
      expect(Session().isArchived, false);
      expect(Session(archivedAt: DateTime.now()).isArchived, true);
    });

    test('isChild returns correct value', () {
      expect(Session().isChild, false);
      expect(Session(parentID: 'parent').isChild, true);
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

    test('toJson omits null values', () {
      final ruleset = PermissionRuleset(allow: ['read']);
      final json = ruleset.toJson();
      expect(json.containsKey('deny'), false);
      expect(json['allow'], ['read']);
    });
  });

  group('SessionCreateInput', () {
    test('toJson produces correct output', () {
      final input = SessionCreateInput(
        parentID: 'parent-1',
        title: 'New Session',
      );
      final json = input.toJson();
      expect(json['parentID'], 'parent-1');
      expect(json['title'], 'New Session');
    });

    test('toJson omits null values', () {
      final input = SessionCreateInput();
      final json = input.toJson();
      expect(json.containsKey('parentID'), false);
      expect(json.containsKey('title'), false);
    });
  });

  group('SessionUpdateInput', () {
    test('toJson produces correct output', () {
      final input = SessionUpdateInput(
        title: 'Updated Title',
        archivedAt: 1000000,
      );
      final json = input.toJson();
      expect(json['title'], 'Updated Title');
      expect(json['time']['archived'], 1000000);
    });
  });
}
