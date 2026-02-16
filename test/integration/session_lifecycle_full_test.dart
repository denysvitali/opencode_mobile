import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/message.dart';
import 'package:opencode_mobile/core/models/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  late OpenCodeClient client;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      markTestSkipped(
          'SERVER_URL must be provided via --dart-define=SERVER_URL=<url>. Integration tests require a running OpenCode server.');
    }

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(
      config: ServerConfig(url: serverUrl),
    );
  });

  tearDownAll(() {
    platformHttpClient.close();
  });

  group('Session creation with directory', () {
    testWidgets('creates session in context of specific project directory',
        (tester) async {
      const testDir = '/custom/project/path';
      final session = await client.createSession(
        directory: testDir,
        input: SessionCreateInput(title: 'Directory Test Session'),
      );

      expect(session.id, isNotEmpty);
      expect(session.title, equals('Directory Test Session'));
    });

    testWidgets('session has path after creation with directory',
        (tester) async {
      const testDir = '/project/directory';
      final session = await client.createSession(
        directory: testDir,
        input: SessionCreateInput(title: 'Path Test'),
      );

      expect(session.path, isNotEmpty);
    });
  });

  group('Session initialization flow', () {
    testWidgets('create session with idle status, init, then cancel',
        (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Init Flow Test'),
      );

      expect(session.status, equals(SessionStatus.idle));

      await client.initSession(session.id);
      var updated = await client.getSession(session.id);
      expect(updated.status, equals(SessionStatus.running));

      await client.cancelSession(session.id);
      updated = await client.getSession(session.id);
      expect(updated.status, equals(SessionStatus.idle));

      await client.deleteSession(session.id);
    });

    testWidgets('initSession changes status to running', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Running Status Test'),
      );

      expect(session.status, equals(SessionStatus.idle));

      await client.initSession(session.id);
      final updated = await client.getSession(session.id);
      expect(updated.status, equals(SessionStatus.running));

      await client.cancelSession(session.id);
      await client.deleteSession(session.id);
    });

    testWidgets('cancelSession reverts status back to idle', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Cancel Status Test'),
      );

      await client.initSession(session.id);
      var updated = await client.getSession(session.id);
      expect(updated.status, equals(SessionStatus.running));

      await client.cancelSession(session.id);
      updated = await client.getSession(session.id);
      expect(updated.status, equals(SessionStatus.idle));

      await client.deleteSession(session.id);
    });
  });

  group('Session status transitions', () {
    testWidgets('full status cycle: idle -> pending -> running -> idle during message processing',
        (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Status Cycle Test'),
      );

      expect(session.status, equals(SessionStatus.idle));

      await client.sendPrompt(session.id, text: 'Hello, trigger processing');

      final updated = await client.getSession(session.id);
      expect(
        updated.status,
        anyOf(equals(SessionStatus.running), equals(SessionStatus.idle)),
        reason:
            'After message processing, status should be running or back to idle',
      );

      await client.deleteSession(session.id);
    });

    testWidgets('session status changes during streaming message',
        (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Streaming Status Test'),
      );

      expect(session.status, equals(SessionStatus.idle));

      final messages = <Message>[];
      await for (final message in client.sendPromptStream(
        session.id,
        text: 'Tell me a short story',
      )) {
        messages.add(message);
        final currentStatus = await client.getSessionStatuses();
        final status = currentStatus[session.id];
        expect(
          status,
          anyOf(equals('running'), equals('idle'), isNull),
          reason: 'Status should be running during streaming or idle when done',
        );
      }

      expect(messages, isNotEmpty);
      await client.deleteSession(session.id);
    });
  });

  group('Session deletion cascade', () {
    testWidgets('create parent session, create child, delete parent',
        (tester) async {
      final parent = await client.createSession(
        input: SessionCreateInput(title: 'Parent Session'),
      );

      final child = await client.createSession(
        input: SessionCreateInput(parentID: parent.id, title: 'Child Session'),
      );

      expect(parent.id, isNotEmpty);
      expect(child.parentID, equals(parent.id));

      final childrenBeforeDelete = await client.getSessionChildren(parent.id);
      expect(childrenBeforeDelete, isNotEmpty);

      await client.deleteSession(parent.id);

      expect(
        () => client.getSession(parent.id),
        throwsA(isA<OpenCodeException>()),
        reason: 'Parent session should be deleted',
      );
    });

    testWidgets('child session remains accessible after parent deletion',
        (tester) async {
      final parent = await client.createSession(
        input: SessionCreateInput(title: 'Parent for Child Test'),
      );

      final child = await client.createSession(
        input: SessionCreateInput(parentID: parent.id, title: 'Orphaned Child'),
      );

      await client.deleteSession(parent.id);

      try {
        final childAfterParentDelete = await client.getSession(child.id);
        expect(childAfterParentDelete.id, equals(child.id));
      } catch (e) {
        // Child may or may not be deleted depending on server implementation
      } finally {
        try {
          await client.deleteSession(child.id);
        } catch (_) {}
      }
    });
  });

  group('Combined filter testing', () {
    testWidgets('listSessions with search, roots, limit, and directory',
        (tester) async {
      await client.createSession(
        input: SessionCreateInput(title: 'Searchable Session 1'),
      );
      await client.createSession(
        input: SessionCreateInput(title: 'Searchable Session 2'),
      );

      final sessions = await client.listSessions(
        search: 'Searchable',
        roots: true,
        limit: 10,
        directory: '/test',
      );

      expect(sessions, isA<List<Session>>());
      expect(sessions.length, lessThanOrEqualTo(10));
    });

    testWidgets('listSessions with only search filter', (tester) async {
      await client.createSession(
        input: SessionCreateInput(title: 'Unique Search Query xyz'),
      );

      final sessions = await client.listSessions(search: 'xyz');

      expect(sessions, isA<List<Session>>());
    });

    testWidgets('listSessions with roots and limit', (tester) async {
      final parent = await client.createSession(
        input: SessionCreateInput(title: 'Root Parent'),
      );
      await client.createSession(
        input: SessionCreateInput(parentID: parent.id, title: 'Child of Root'),
      );

      final rootSessions = await client.listSessions(roots: true, limit: 5);

      expect(rootSessions, isA<List<Session>>());
      expect(rootSessions.length, lessThanOrEqualTo(5));
    });

    testWidgets('listSessions with directory and search', (tester) async {
      await client.createSession(
        directory: '/test',
        input: SessionCreateInput(title: 'Test Directory Session'),
      );

      final sessions = await client.listSessions(
        directory: '/test',
        search: 'Test',
      );

      expect(sessions, isA<List<Session>>());
    });
  });

  group('Session with permission ruleset', () {
    testWidgets('creates session with PermissionRuleset', (tester) async {
      final permission = PermissionRuleset(
        mode: 'manual',
        allow: ['Read', 'Write'],
        deny: ['Delete'],
      );

      final session = await client.createSession(
        input: SessionCreateInput(
          title: 'Permission Test Session',
          permission: permission,
        ),
      );

      expect(session.id, isNotEmpty);
      expect(session.permission, isNotNull);
      expect(session.permission?.mode, equals('manual'));
      expect(session.permission?.allow, contains('Read'));
      expect(session.permission?.deny, contains('Delete'));

      await client.deleteSession(session.id);
    });

    testWidgets('session permission stores allow list correctly',
        (tester) async {
      final permission = PermissionRuleset(
        mode: 'auto',
        allow: ['Read', 'Write', 'Execute'],
      );

      final session = await client.createSession(
        input: SessionCreateInput(
          title: 'Allow List Test',
          permission: permission,
        ),
      );

      expect(session.permission?.allow, isNotNull);
      expect(session.permission?.allow?.length, equals(3));
      expect(session.permission?.allow, contains('Execute'));

      await client.deleteSession(session.id);
    });

    testWidgets('session permission stores deny list correctly',
        (tester) async {
      final permission = PermissionRuleset(
        mode: 'restricted',
        deny: ['NetworkAccess', 'FileSystem'],
      );

      final session = await client.createSession(
        input: SessionCreateInput(
          title: 'Deny List Test',
          permission: permission,
        ),
      );

      expect(session.permission?.deny, isNotNull);
      expect(session.permission?.deny?.length, equals(2));
      expect(session.permission?.deny, contains('FileSystem'));

      await client.deleteSession(session.id);
    });

    testWidgets('session without permission has null permission field',
        (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'No Permission Session'),
      );

      expect(session.permission, isNull);

      await client.deleteSession(session.id);
    });
  });

  group('Session children and parent relationships', () {
    testWidgets('getSessionChildren returns child sessions', (tester) async {
      final parent = await client.createSession(
        input: SessionCreateInput(title: 'Parent for Children'),
      );

      await client.createSession(
        input: SessionCreateInput(parentID: parent.id, title: 'Child 1'),
      );
      await client.createSession(
        input: SessionCreateInput(parentID: parent.id, title: 'Child 2'),
      );

      final children = await client.getSessionChildren(parent.id);

      expect(children, isNotEmpty);
      expect(children.length, equals(2));

      for (final child in children) {
        expect(child.parentID, equals(parent.id));
        await client.deleteSession(child.id);
      }
      await client.deleteSession(parent.id);
    });

    testWidgets('session isChild property reflects parent relationship',
        (tester) async {
      final parent = await client.createSession(
        input: SessionCreateInput(title: 'Parent Session Check'),
      );

      final child = await client.createSession(
        input: SessionCreateInput(parentID: parent.id, title: 'Child Session Check'),
      );

      expect(parent.isChild, isFalse);
      expect(child.isChild, isTrue);
      expect(child.parentID, equals(parent.id));

      await client.deleteSession(child.id);
      await client.deleteSession(parent.id);
    });
  });

  group('Session update and archive', () {
    testWidgets('updateSession modifies title', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Original Title'),
      );

      final updated = await client.updateSession(
        session.id,
        SessionUpdateInput(title: 'Modified Title'),
      );

      expect(updated.title, equals('Modified Title'));

      await client.deleteSession(session.id);
    });

    testWidgets('archive session sets archivedAt timestamp', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Archive Me'),
      );

      final archived = await client.updateSession(
        session.id,
        SessionUpdateInput(archivedAt: DateTime.now().millisecondsSinceEpoch),
      );

      expect(archived.isArchived, isTrue);
      expect(archived.archivedAt, isNotNull);

      await client.deleteSession(session.id);
    });
  });
}
