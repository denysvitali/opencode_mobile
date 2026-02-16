import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/permission.dart';

void main() {
  group('Permission', () {
    test('creates with default createdAt', () {
      final permission = Permission(
        id: 'perm-1',
        sessionId: 'session-1',
        type: 'tool',
      );
      expect(permission.id, 'perm-1');
      expect(permission.sessionId, 'session-1');
      expect(permission.type, 'tool');
      expect(permission.createdAt, isNotNull);
    });

    group('fromJson', () {
      test('parses id, sessionId, type, message, data', () {
        final json = {
          'id': 'perm-1',
          'sessionID': 'session-1',
          'type': 'tool',
          'message': 'Allow tool execution?',
          'data': {'tool': 'Bash', 'command': 'ls'},
        };
        final permission = Permission.fromJson(json);
        expect(permission.id, 'perm-1');
        expect(permission.sessionId, 'session-1');
        expect(permission.type, 'tool');
        expect(permission.message, 'Allow tool execution?');
        expect(permission.data, isNotNull);
        expect(permission.data!['tool'], 'Bash');
        expect(permission.data!['command'], 'ls');
      });

      test('parses sessionID (different casing)', () {
        final json = {
          'id': 'perm-1',
          'sessionID': 'session-1',
          'type': 'tool',
        };
        final permission = Permission.fromJson(json);
        expect(permission.sessionId, 'session-1');
      });

      test('parses time as DateTime', () {
        final epochMs = 1704067200000;
        final json = {
          'id': 'perm-1',
          'sessionID': 'session-1',
          'type': 'tool',
          'time': epochMs,
        };
        final permission = Permission.fromJson(json);
        expect(permission.createdAt.millisecondsSinceEpoch, epochMs);
      });

      test('parses time as int', () {
        final json = {
          'id': 'perm-1',
          'sessionID': 'session-1',
          'type': 'tool',
          'time': 1704067200000,
        };
        final permission = Permission.fromJson(json);
        expect(permission.createdAt.millisecondsSinceEpoch, 1704067200000);
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'perm-1',
          'sessionID': 'session-1',
          'type': 'tool',
        };
        final permission = Permission.fromJson(json);
        expect(permission.id, 'perm-1');
        expect(permission.sessionId, 'session-1');
        expect(permission.type, 'tool');
        expect(permission.message, isNull);
        expect(permission.data, isNull);
      });

      test('handles missing time', () {
        final json = {
          'id': 'perm-1',
          'sessionID': 'session-1',
          'type': 'tool',
        };
        final permission = Permission.fromJson(json);
        expect(permission.createdAt, isNotNull);
      });

      test('handles missing id', () {
        final json = {
          'sessionID': 'session-1',
          'type': 'tool',
        };
        final permission = Permission.fromJson(json);
        expect(permission.id, '');
      });

      test('handles missing sessionID', () {
        final json = {
          'id': 'perm-1',
          'type': 'tool',
        };
        final permission = Permission.fromJson(json);
        expect(permission.sessionId, '');
      });

      test('handles missing type', () {
        final json = {
          'id': 'perm-1',
          'sessionID': 'session-1',
        };
        final permission = Permission.fromJson(json);
        expect(permission.type, '');
      });

      test('handles empty data object', () {
        final json = {
          'id': 'perm-1',
          'sessionID': 'session-1',
          'type': 'tool',
          'data': <String, dynamic>{},
        };
        final permission = Permission.fromJson(json);
        expect(permission.data, isNotNull);
        expect(permission.data, isEmpty);
      });

      test('handles data as null', () {
        final json = {
          'id': 'perm-1',
          'sessionID': 'session-1',
          'type': 'tool',
          'data': null,
        };
        final permission = Permission.fromJson(json);
        expect(permission.data, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final createdAt = DateTime.fromMillisecondsSinceEpoch(1704067200000);
        final permission = Permission(
          id: 'perm-1',
          sessionId: 'session-1',
          type: 'tool',
          message: 'Allow tool?',
          data: {'tool': 'Bash'},
          createdAt: createdAt,
        );
        final json = permission.toJson();

        expect(json['id'], 'perm-1');
        expect(json['sessionID'], 'session-1');
        expect(json['type'], 'tool');
        expect(json['message'], 'Allow tool?');
        expect(json['data'], isNotNull);
        expect(json['time'], 1704067200000);
      });

      test('uses sessionID key in output', () {
        final permission = Permission(
          id: 'perm-1',
          sessionId: 'session-1',
          type: 'tool',
        );
        final json = permission.toJson();

        expect(json.containsKey('sessionID'), true);
        expect(json['sessionID'], 'session-1');
      });

      test('omits null message', () {
        final permission = Permission(
          id: 'perm-1',
          sessionId: 'session-1',
          type: 'tool',
        );
        final json = permission.toJson();

        expect(json.containsKey('message'), false);
      });

      test('omits null data', () {
        final permission = Permission(
          id: 'perm-1',
          sessionId: 'session-1',
          type: 'tool',
        );
        final json = permission.toJson();

        expect(json.containsKey('data'), false);
      });

      test('includes message when present', () {
        final permission = Permission(
          id: 'perm-1',
          sessionId: 'session-1',
          type: 'tool',
          message: 'Test message',
        );
        final json = permission.toJson();

        expect(json['message'], 'Test message');
      });

      test('includes data when present', () {
        final permission = Permission(
          id: 'perm-1',
          sessionId: 'session-1',
          type: 'tool',
          data: {'key': 'value'},
        );
        final json = permission.toJson();

        expect(json['data'], isNotNull);
        expect(json['data']['key'], 'value');
      });

      test('serializes createdAt as milliseconds', () {
        final createdAt = DateTime.fromMillisecondsSinceEpoch(1704067200000);
        final permission = Permission(
          id: 'perm-1',
          sessionId: 'session-1',
          type: 'tool',
          createdAt: createdAt,
        );
        final json = permission.toJson();

        expect(json['time'], 1704067200000);
      });

      test('produces valid JSON', () {
        final permission = Permission(
          id: 'perm-1',
          sessionId: 'session-1',
          type: 'tool',
          message: 'Allow?',
          data: {'tool': 'Read'},
        );
        final jsonString = jsonEncode(permission.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });

    group('createdAt default', () {
      test('generates default createdAt when not provided', () {
        final before = DateTime.now();
        final permission = Permission(
          id: 'perm-1',
          sessionId: 'session-1',
          type: 'tool',
        );
        final after = DateTime.now();

        expect(permission.createdAt.isAfter(before) || 
               permission.createdAt.isAtSameMomentAs(before), true);
        expect(permission.createdAt.isBefore(after) || 
               permission.createdAt.isAtSameMomentAs(after), true);
      });

      test('uses provided createdAt when specified', () {
        final customDate = DateTime(2024, 1, 1);
        final permission = Permission(
          id: 'perm-1',
          sessionId: 'session-1',
          type: 'tool',
          createdAt: customDate,
        );
        expect(permission.createdAt, customDate);
      });

      test('generates current time when time is missing in JSON', () {
        final json = {
          'id': 'perm-1',
          'sessionID': 'session-1',
          'type': 'tool',
        };
        final before = DateTime.now();
        final permission = Permission.fromJson(json);
        final after = DateTime.now();

        expect(permission.createdAt.isAfter(before) ||
               permission.createdAt.isAtSameMomentAs(before), true);
        expect(permission.createdAt.isBefore(after) ||
               permission.createdAt.isAtSameMomentAs(after), true);
      });
    });
  });
}
