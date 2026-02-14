import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/api/sse_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  late OpenCodeClient client;
  late SSEClient sseClient;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      fail('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>');
    }

    print('=== Session Management Test ===');
    print('Server URL: $serverUrl');

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(
      config: ServerConfig(url: serverUrl),
    );

    sseClient = SSEClient();
  });

  tearDownAll(() {
    sseClient.disconnect();
    platformHttpClient.close();
  });

  group('Session CRUD Operations', () {
    testWidgets('create session with title', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Test Session for Create'),
      );

      expect(session.id, isNotEmpty, reason: 'Session ID should be set');
      expect(session.title, equals('Test Session for Create'));

      // Clean up
      await client.deleteSession(session.id);
    });

    testWidgets('update session title', (tester) async {
      // Create a session
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Original Title'),
      );

      try {
        // Update the session
        final updated = await client.updateSession(
          session.id,
          SessionUpdateInput(title: 'Updated Title'),
        );

        expect(updated.title, equals('Updated Title'));

        // Verify by fetching again
        final fetched = await client.getSession(session.id);
        expect(fetched.title, equals('Updated Title'));
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('archive session', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session to Archive'),
      );

      try {
        expect(session.archivedAt, isNull);

        final archived = await client.updateSession(
          session.id,
          SessionUpdateInput(archivedAt: DateTime.now().millisecondsSinceEpoch),
        );

        expect(archived.archivedAt, isNotNull);
        expect(archived.isArchived, isTrue);
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('delete session cleans up properly', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session to Delete'),
      );

      final sessionId = session.id;

      // Delete it
      final deleted = await client.deleteSession(sessionId);
      expect(deleted, isTrue);

      // Verify it's gone
      try {
        await client.getSession(sessionId);
        fail('Session should have been deleted');
      } on OpenCodeException catch (_) {
        // Expected
      }
    });
  });

  group('Session Status Operations', () {
    testWidgets('get session statuses returns map', (tester) async {
      final statuses = await client.getSessionStatuses();

      expect(statuses, isA<Map<String, String>>());

      // If there are sessions, verify the status values
      for (final entry in statuses.entries) {
        final statusValues = ['idle', 'pending', 'running', 'compacting'];
        expect(statusValues, contains(entry.value.toLowerCase()),
            reason: 'Status should be a valid value: ${entry.value}');
      }
    });

    testWidgets('session status reflects lifecycle', (tester) async {
      // Connect SSE to receive updates
      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Status Test Session'),
      );

      try {
        // Initially should be idle or pending
        final statuses = await client.getSessionStatuses();
        if (statuses.containsKey(session.id)) {
          expect(['idle', 'pending'], contains(statuses[session.id]!));
        }
      } finally {
        await client.deleteSession(session.id);
        sseClient.disconnect();
      }
    });
  });

  group('Session Children and Hierarchy', () {
    testWidgets('get session children for parent session', (tester) async {
      // Create a parent session
      final parent = await client.createSession(
        input: SessionCreateInput(title: 'Parent Session'),
      );

      try {
        // Create child sessions
        final child1 = await client.createSession(
          input: SessionCreateInput(
            title: 'Child Session 1',
            parentID: parent.id,
          ),
        );
        final child2 = await client.createSession(
          input: SessionCreateInput(
            title: 'Child Session 2',
            parentID: parent.id,
          ),
        );

        try {
          // Get children
          final children = await client.getSessionChildren(parent.id);

          expect(children.length, greaterThanOrEqualTo(2));

          final childIds = children.map((c) => c.id).toList();
          expect(childIds, contains(child1.id));
          expect(childIds, contains(child2.id));

          // Verify children have parentID set
          for (final child in children) {
            if (child.id == child1.id || child.id == child2.id) {
              expect(child.parentID, equals(parent.id));
            }
          }
        } finally {
          await client.deleteSession(child1.id);
          await client.deleteSession(child2.id);
        }
      } finally {
        await client.deleteSession(parent.id);
      }
    });

    testWidgets('empty children list for leaf session', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Leaf Session'),
      );

      try {
        final children = await client.getSessionChildren(session.id);
        expect(children, isEmpty);
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });

  group('Session Cancellation', () {
    testWidgets('cancel idle session handles gracefully', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session to Cancel'),
      );

      try {
        // Session is idle, cancel should still work
        final result = await client.cancelSession(session.id);
        expect(result, isTrue);
      } finally {
        // Clean up - session might already be gone
        try {
          await client.deleteSession(session.id);
        } on OpenCodeException catch (_) {
          // Already deleted
        }
      }
    });

    testWidgets('abortSession is alias for cancelSession', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session for Abort'),
      );

      try {
        final result = await client.abortSession(session.id);
        expect(result, isTrue);
      } finally {
        try {
          await client.deleteSession(session.id);
        } on OpenCodeException catch (_) {
          // Already deleted
        }
      }
    });
  });

  group('Session Session-Related Operations', () {
    testWidgets('get session todos returns list', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session with Todos'),
      );

      try {
        final todos = await client.getSessionTodos(session.id);
        expect(todos, isA<List>());
        // Todos may be empty or populated, just verify no crash
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('init session returns true', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session to Init'),
      );

      try {
        final result = await client.initSession(session.id);
        expect(result, isTrue);
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('get session diff returns diff object', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session for Diff'),
      );

      try {
        final diff = await client.getSessionDiff(session.id);
        expect(diff, isNotNull);
        // Diff may be empty if no changes yet
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('revert to message works', (tester) async {
      // Create session and send a message
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session for Revert'),
      );

      try {
        final messages = await client.getMessages(session.id);

        if (messages.isNotEmpty) {
          final firstMessageId = messages.first.id;

          // Revert to first message
          final reverted = await client.revertToMessage(session.id, firstMessageId);
          expect(reverted.id, equals(session.id));
        }
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });

  group('Session List Operations', () {
    testWidgets('list sessions with search filter', (tester) async {
      // Create test sessions
      final session1 = await client.createSession(
        input: SessionCreateInput(title: 'Alpha Session Search'),
      );
      final session2 = await client.createSession(
        input: SessionCreateInput(title: 'Beta Session Search'),
      );

      try {
        // Search for Alpha
        final alphaSessions = await client.listSessions(search: 'Alpha');
        final alphaIds = alphaSessions.map((s) => s.id).toList();
        expect(alphaIds, contains(session1.id));

        // Search for Beta
        final betaSessions = await client.listSessions(search: 'Beta');
        final betaIds = betaSessions.map((s) => s.id).toList();
        expect(betaIds, contains(session2.id));

        // Search for non-existent
        final empty = await client.listSessions(search: 'XYZ123NONEXISTENT');
        expect(empty, isEmpty);
      } finally {
        await client.deleteSession(session1.id);
        await client.deleteSession(session2.id);
      }
    });

    testWidgets('list sessions with limit', (tester) async {
      // Create multiple sessions
      final sessions = <Session>[];
      for (int i = 0; i < 5; i++) {
        sessions.add(await client.createSession(
          input: SessionCreateInput(title: 'Limit Test Session $i'),
        ));
      }

      try {
        // Get limited list
        final limited = await client.listSessions(limit: 2);
        expect(limited.length, lessThanOrEqualTo(2));
      } finally {
        for (final session in sessions) {
          await client.deleteSession(session.id);
        }
      }
    });

    testWidgets('list sessions with roots filter', (tester) async {
      // Create parent and child
      final parent = await client.createSession(
        input: SessionCreateInput(title: 'Root Session'),
      );
      final child = await client.createSession(
        input: SessionCreateInput(
          title: 'Child Session',
          parentID: parent.id,
        ),
      );

      try {
        // Get roots only
        final roots = await client.listSessions(roots: true);
        final rootIds = roots.map((s) => s.id).toList();
        expect(rootIds, contains(parent.id));

        // Verify child is not in roots (or has parentID)
        final childInRoots = roots.firstWhere(
          (s) => s.id == child.id,
          orElse: () => Session(id: 'not-found'),
        );
        if (childInRoots.id != 'not-found') {
          // If child appears, it shouldn't have parentID
          expect(childInRoots.parentID, isNull);
        }
      } finally {
        await client.deleteSession(child.id);
        await client.deleteSession(parent.id);
      }
    });
  });
}
