import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
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

    print('=== Multi-Directory Test ===');
    print('Server URL: $serverUrl');

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(
      config: ServerConfig(url: serverUrl),
    );
  });

  tearDownAll(() {
    platformHttpClient.close();
  });

  group('Multi-Directory Session Creation', () {
    testWidgets('creates session in directory A', (tester) async {
      const directoryA = '/project-a';

      final session = await client.createSession(
        directory: directoryA,
        input: SessionCreateInput(title: 'Session in Project A'),
      );

      expect(session.id, isNotEmpty);
      expect(session.title, equals('Session in Project A'));

      await client.deleteSession(session.id);
    });

    testWidgets('creates session in directory B', (tester) async {
      const directoryB = '/project-b';

      final session = await client.createSession(
        directory: directoryB,
        input: SessionCreateInput(title: 'Session in Project B'),
      );

      expect(session.id, isNotEmpty);
      expect(session.title, equals('Session in Project B'));

      await client.deleteSession(session.id);
    });

    testWidgets('creates session without directory', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session without directory'),
      );

      expect(session.id, isNotEmpty);
      expect(session.title, equals('Session without directory'));

      await client.deleteSession(session.id);
    });
  });

  group('Directory Parameter Propagation', () {
    testWidgets('listSessions accepts directory parameter', (tester) async {
      const directory = '/test-directory';

      final sessions = await client.listSessions(directory: directory);

      expect(sessions, isA<List<Session>>());
    });

    testWidgets('getSession accepts directory parameter', (tester) async {
      final created = await client.createSession(
        input: SessionCreateInput(title: 'Get Session Test'),
      );

      try {
        final session = await client.getSession(created.id, directory: '/test');

        expect(session.id, equals(created.id));
      } finally {
        await client.deleteSession(created.id);
      }
    });

    testWidgets('updateSession accepts directory parameter', (tester) async {
      final created = await client.createSession(
        input: SessionCreateInput(title: 'Original Title'),
      );

      try {
        final updated = await client.updateSession(
          created.id,
          SessionUpdateInput(title: 'Updated via directory'),
          directory: '/test',
        );

        expect(updated.title, equals('Updated via directory'));
      } finally {
        await client.deleteSession(created.id);
      }
    });

    testWidgets('deleteSession accepts directory parameter', (tester) async {
      final created = await client.createSession(
        input: SessionCreateInput(title: 'Delete with directory'),
      );

      final result = await client.deleteSession(created.id, directory: '/test');

      expect(result, isTrue);
    });

    testWidgets('getSessionStatuses accepts directory parameter', (tester) async {
      await client.createSession(input: SessionCreateInput(title: 'Status Test'));

      final statuses = await client.getSessionStatuses(directory: '/test');

      expect(statuses, isA<Map<String, String>>());
    });

    testWidgets('initSession accepts directory parameter', (tester) async {
      final created = await client.createSession(
        input: SessionCreateInput(title: 'Init Test'),
      );

      try {
        final result = await client.initSession(created.id, directory: '/test');

        expect(result, isTrue);
      } finally {
        await client.deleteSession(created.id);
      }
    });
  });

  group('Directory Isolation', () {
    testWidgets('sessions created in different directories are independent',
        (tester) async {
      const directoryA = '/dir-a';
      const directoryB = '/dir-b';

      final sessionA = await client.createSession(
        directory: directoryA,
        input: SessionCreateInput(title: 'Session A'),
      );

      final sessionB = await client.createSession(
        directory: directoryB,
        input: SessionCreateInput(title: 'Session B'),
      );

      try {
        expect(sessionA.id, isNot(equals(sessionB.id)));

        final fetchedA = await client.getSession(sessionA.id);
        final fetchedB = await client.getSession(sessionB.id);

        expect(fetchedA.title, equals('Session A'));
        expect(fetchedB.title, equals('Session B'));
      } finally {
        await client.deleteSession(sessionA.id);
        await client.deleteSession(sessionB.id);
      }
    });

    testWidgets('listSessions with directory filter returns filtered results',
        (tester) async {
      const directory = '/filter-test';

      final session1 = await client.createSession(
        directory: directory,
        input: SessionCreateInput(title: 'Filter Test 1'),
      );

      final session2 = await client.createSession(
        directory: directory,
        input: SessionCreateInput(title: 'Filter Test 2'),
      );

      try {
        final sessions = await client.listSessions(directory: directory);

        expect(sessions, isA<List<Session>>());
        expect(sessions.length, greaterThanOrEqualTo(2));

        final titles = sessions.map((s) => s.title).toList();
        expect(titles, contains('Filter Test 1'));
        expect(titles, contains('Filter Test 2'));
      } finally {
        await client.deleteSession(session1.id);
        await client.deleteSession(session2.id);
      }
    });
  });

  group('Message Operations with Directory', () {
    testWidgets('getMessages accepts directory parameter', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Message Test'),
      );

      try {
        final messages = await client.getMessages(session.id, directory: '/test');

        expect(messages, isA<List>());
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('sendPrompt accepts directory parameter', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Send Prompt Test'),
      );

      try {
        final message = await client.sendPrompt(
          session.id,
          text: 'Hello with directory',
          directory: '/test',
        );

        expect(message.id, isNotEmpty);
        expect(message.role, equals('user'));
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });

  group('Config Operations with Directory', () {
    testWidgets('getConfig accepts directory parameter', (tester) async {
      final config = await client.getConfig(directory: '/test');

      expect(config, isNotNull);
    });

    testWidgets('getConfigProviders accepts directory parameter',
        (tester) async {
      final providers = await client.getConfigProviders(directory: '/test');

      expect(providers, isNotNull);
    });
  });

  group('Project Operations with Directory', () {
    testWidgets('listProjects accepts directory parameter', (tester) async {
      final projects = await client.listProjects(directory: '/test');

      expect(projects, isA<List>());
    });

    testWidgets('getCurrentProject accepts directory parameter', (tester) async {
      final project = await client.getCurrentProject(directory: '/test');

      expect(project, isNotNull);
    });
  });

  group('Session Children with Directory', () {
    testWidgets('getSessionChildren accepts directory parameter', (tester) async {
      final parent = await client.createSession(
        input: SessionCreateInput(title: 'Parent Session'),
      );

      try {
        final children = await client.getSessionChildren(
          parent.id,
          directory: '/test',
        );

        expect(children, isA<List>());
      } finally {
        await client.deleteSession(parent.id);
      }
    });
  });

  group('Session Todos with Directory', () {
    testWidgets('getSessionTodos accepts directory parameter', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Todo Test'),
      );

      try {
        final todos = await client.getSessionTodos(session.id, directory: '/test');

        expect(todos, isA<List>());
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });

  group('Session Diff with Directory', () {
    testWidgets('getSessionDiff accepts directory parameter', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Diff Test'),
      );

      try {
        final diff = await client.getSessionDiff(session.id, directory: '/test');

        expect(diff, isNotNull);
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });
}
